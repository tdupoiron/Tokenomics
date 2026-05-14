/**
 * ChatGPT path is a local counter, not a polled endpoint. OpenAI doesn't
 * expose a server-side usage endpoint to the web client (the Codex CLI's
 * /wham/usage is bearer-token-only). Every shipping ChatGPT tracker
 * intercepts /backend-api/conversation calls and counts locally.
 *
 * This module: plan detection (/backend-api/me), the quota table, and
 * snapshot derivation from a counter log.
 */

import type { ProviderUsageSnapshot, WindowUsage } from './snapshot';

export type ChatGPTPlan = 'free' | 'plus' | 'pro' | 'team' | 'unknown';

interface MeResponse {
  // The /me response has historically shaped its plan info under different
  // keys (`account.plan`, `accounts.default.entitlement.plan_type`, etc.).
  // We probe a few plausible paths and accept the first hit.
  account?: { plan?: string; plan_type?: string };
  accounts?: Record<string, { entitlement?: { plan_type?: string } }>;
  plan?: string;
}

/** Hit /backend-api/me from the SW with the user's session cookie. */
export async function detectChatGPTPlan(): Promise<ChatGPTPlan> {
  try {
    const res = await fetch('https://chatgpt.com/backend-api/me', {
      credentials: 'include',
    });
    if (res.status === 401 || res.status === 403) return 'unknown';
    if (!res.ok) return 'unknown';
    const data = (await res.json()) as MeResponse;
    return canonicalPlan(extractPlan(data));
  } catch {
    return 'unknown';
  }
}

function extractPlan(data: MeResponse): string | undefined {
  if (data.plan) return data.plan;
  if (data.account?.plan_type) return data.account.plan_type;
  if (data.account?.plan) return data.account.plan;
  if (data.accounts) {
    for (const acc of Object.values(data.accounts)) {
      const pt = acc.entitlement?.plan_type;
      if (pt) return pt;
    }
  }
  return undefined;
}

function canonicalPlan(raw: string | undefined): ChatGPTPlan {
  if (!raw) return 'unknown';
  const s = raw.toLowerCase();
  if (s === 'free') return 'free';
  if (s === 'plus' || s === 'chatgpt_plus') return 'plus';
  if (s === 'pro' || s === 'chatgpt_pro') return 'pro';
  if (s === 'team' || s === 'chatgpt_team') return 'team';
  return 'unknown';
}

// ── Quota table (May 2026) ──────────────────────────────────
// Values are documented OpenAI defaults. They shift quarterly — a routine
// monthly check is configured outside this file to flag changes.
//
// Modeling choice: one "short window" per plan covers the dominant cap
// (GPT-5 messages). For Plus/Pro we surface a second window for the
// weekly Thinking budget. Free has no secondary window.

interface PlanQuota {
  shortWindowSec: number;
  shortWindowLimit: number;
  shortWindowLabel: string;
  longWindowSec?: number;
  longWindowLimit?: number;
  longWindowLabel?: string;
}

const QUOTA: Record<Exclude<ChatGPTPlan, 'unknown'>, PlanQuota> = {
  free: {
    shortWindowSec: 5 * 3600,
    shortWindowLimit: 10,
    shortWindowLabel: '5-Hour Window',
  },
  plus: {
    shortWindowSec: 3 * 3600,
    shortWindowLimit: 160,
    shortWindowLabel: '3-Hour Window',
    longWindowSec: 7 * 86400,
    longWindowLimit: 3000,
    longWindowLabel: 'Weekly Thinking',
  },
  pro: {
    shortWindowSec: 3 * 3600,
    shortWindowLimit: 800,
    shortWindowLabel: '3-Hour Window',
    longWindowSec: 7 * 86400,
    longWindowLimit: 15000,
    longWindowLabel: 'Weekly Thinking',
  },
  team: {
    shortWindowSec: 3 * 3600,
    shortWindowLimit: 160,
    shortWindowLabel: '3-Hour Window',
    longWindowSec: 7 * 86400,
    longWindowLimit: 3000,
    longWindowLabel: 'Weekly Thinking',
  },
};

/** A timestamped message log entry. Persisted in chrome.storage.local. */
export interface ChatGPTMessageEvent {
  ts: number; // Unix ms when the conversation POST was observed
  model: string | null;
}

const THINKING_MODELS = new Set([
  'gpt-5-thinking',
  'gpt-5-thinking-pro',
  'gpt-5.2-thinking',
  'o1',
  'o1-pro',
  'o3',
  'o3-pro',
  'o4-mini',
]);

function isThinking(model: string | null): boolean {
  if (!model) return false;
  const s = model.toLowerCase();
  if (THINKING_MODELS.has(s)) return true;
  return s.includes('thinking') || s.startsWith('o1') || s.startsWith('o3');
}

export function deriveSnapshot(
  events: ChatGPTMessageEvent[],
  plan: ChatGPTPlan,
  now: number = Date.now(),
): ProviderUsageSnapshot {
  const effectivePlan: Exclude<ChatGPTPlan, 'unknown'> = plan === 'unknown' ? 'free' : plan;
  const quota = QUOTA[effectivePlan];

  const shortWindowMs = quota.shortWindowSec * 1000;
  const shortCount = events.filter((e) => now - e.ts <= shortWindowMs).length;
  const shortUtil = quota.shortWindowLimit > 0
    ? Math.min(100, Math.round((shortCount / quota.shortWindowLimit) * 100))
    : 0;

  // Reset time approximation: the oldest still-in-window event drops out
  // first. If no events, the window is wide open right now.
  const oldestInWindow = events.find((e) => now - e.ts <= shortWindowMs);
  const shortResetMs = oldestInWindow ? oldestInWindow.ts + shortWindowMs : now + shortWindowMs;

  const shortWindow: WindowUsage = {
    label: quota.shortWindowLabel,
    utilization: shortUtil,
    resetsAt: new Date(shortResetMs).toISOString(),
    windowDurationSec: quota.shortWindowSec,
    sublabelOverride: formatCounterSublabel(shortCount, quota.shortWindowLimit, 'msgs', shortResetMs, now),
  };

  let longWindow: WindowUsage | null = null;
  if (quota.longWindowSec && quota.longWindowLimit && quota.longWindowLabel) {
    const longWindowMs = quota.longWindowSec * 1000;
    const longEvents = events.filter(
      (e) => isThinking(e.model) && now - e.ts <= longWindowMs,
    );
    const longCount = longEvents.length;
    const longUtil = Math.min(100, Math.round((longCount / quota.longWindowLimit) * 100));
    const oldestThinkingInWindow = longEvents[0];
    const longResetMs = oldestThinkingInWindow
      ? oldestThinkingInWindow.ts + longWindowMs
      : now + longWindowMs;

    longWindow = {
      label: quota.longWindowLabel,
      utilization: longUtil,
      resetsAt: new Date(longResetMs).toISOString(),
      windowDurationSec: quota.longWindowSec,
      sublabelOverride: formatCounterSublabel(longCount, quota.longWindowLimit, 'thinking msgs', longResetMs, now),
    };
  }

  return {
    provider: 'codex',
    shortWindow,
    longWindow,
    extras: {},
    planLabel: planDisplay(plan),
    capturedAt: now,
    estimated: true,
  };
}

function formatCounterSublabel(
  count: number,
  limit: number,
  noun: string,
  resetMs: number,
  now: number,
): string {
  const reset = formatResetCompact(resetMs, now);
  return reset ? `${count} of ${limit} ${noun} · ${reset}` : `${count} of ${limit} ${noun}`;
}

function formatResetCompact(resetMs: number, now: number): string {
  const remainingMs = resetMs - now;
  if (remainingMs <= 0) return 'resets now';
  const totalMinutes = Math.floor(remainingMs / 60_000);
  const hours = Math.floor(totalMinutes / 60);
  const minutes = totalMinutes % 60;
  if (hours >= 24) return `resets in ${Math.floor(hours / 24)}d`;
  if (hours > 0) return `resets in ${hours}h ${minutes}m`;
  return `resets in ${minutes}m`;
}

function planDisplay(plan: ChatGPTPlan): string {
  switch (plan) {
    case 'free':
      return 'Free';
    case 'plus':
      return 'Plus';
    case 'pro':
      return 'Pro';
    case 'team':
      return 'Team';
    case 'unknown':
      return '';
  }
}

/** Prune events older than the longest tracked window (weekly = 7d). */
export function pruneEvents(events: ChatGPTMessageEvent[], now: number = Date.now()): ChatGPTMessageEvent[] {
  const cutoff = now - 7 * 86400 * 1000;
  return events.filter((e) => e.ts >= cutoff);
}
