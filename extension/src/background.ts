import browser from 'webextension-polyfill';
import {
  deriveSnapshot,
  detectChatGPTPlan,
  pruneEvents,
  type ChatGPTMessageEvent,
} from './chatgpt';
import { AuthError, fetchClaudeUsage, RateLimitError } from './claude';
import type { ExtensionMessage, ExtensionResponse } from './messages';
import type { ProviderUsageSnapshot } from './snapshot';
import {
  getBackoff,
  getChatGPTEvents,
  getChatGPTPlanEffective,
  getChatGPTSnapshot,
  getClaudeSnapshot,
  getPinnedProvider,
  setBackoff,
  setChatGPTEvents,
  setChatGPTPlanAuto,
  setChatGPTPlanOverride,
  setChatGPTSnapshot,
  setClaudeAuth,
  setClaudeSnapshot,
} from './storage';
import type { ProviderId } from './types';

const CLAUDE_ALARM = 'claude-poll';
const PLAN_REDETECT_ALARM = 'chatgpt-plan-redetect';
const POLL_PERIOD_MIN = 5;
const PLAN_REDETECT_PERIOD_MIN = 60 * 24; // re-check plan once a day

// Exponential backoff: 5m → 10m → 20m → 40m → 60m (cap)
const BACKOFF_INITIAL_MS = 5 * 60_000;
const BACKOFF_MAX_MS = 60 * 60_000;

console.log('[tokenomics] service worker booted');

browser.runtime.onInstalled.addListener(async () => {
  await scheduleAlarms();
  void pollClaude('install');
  void redetectChatGPTPlan('install');
});

browser.runtime.onStartup.addListener(async () => {
  await scheduleAlarms();
});

browser.alarms.onAlarm.addListener((alarm) => {
  if (alarm.name === CLAUDE_ALARM) void pollClaude('alarm');
  else if (alarm.name === PLAN_REDETECT_ALARM) void redetectChatGPTPlan('alarm');
});

browser.storage.onChanged.addListener((changes, area) => {
  if (area !== 'local') return;
  if ('pinnedProvider' in changes) void updateBadge();
  if ('chatgptPlanOverride' in changes || 'chatgptPlanAuto' in changes) {
    void recomputeChatGPTSnapshot();
  }
});

browser.runtime.onMessage.addListener(
  async (message: unknown): Promise<ExtensionResponse | undefined> => {
    const msg = message as ExtensionMessage | undefined;
    if (!msg) return undefined;

    if (msg.kind === 'CHATGPT_MESSAGE') {
      await recordChatGPTMessage(msg.model, msg.ts);
      return { kind: 'ACK' };
    }

    if (msg.kind === 'CHATGPT_SET_PLAN') {
      if (msg.plan === 'auto') {
        await setChatGPTPlanOverride(null);
        await redetectChatGPTPlan('manual');
      } else {
        await setChatGPTPlanOverride(msg.plan);
      }
      await recomputeChatGPTSnapshot();
      return { kind: 'ACK' };
    }

    if (msg.kind === 'REFRESH_REQUESTED') {
      const backoff = await getBackoff();
      if (backoff && Date.now() < backoff.until) {
        return { kind: 'REFRESH_BACKOFF', until: backoff.until };
      }
      try {
        await Promise.all([pollClaude('manual'), redetectChatGPTPlan('manual')]);
        await recomputeChatGPTSnapshot();
        return { kind: 'REFRESH_COMPLETE' };
      } catch (err) {
        return { kind: 'REFRESH_FAILED', error: String(err) };
      }
    }

    return undefined;
  },
);

async function scheduleAlarms(): Promise<void> {
  await Promise.all([
    browser.alarms.create(CLAUDE_ALARM, { periodInMinutes: POLL_PERIOD_MIN }),
    browser.alarms.create(PLAN_REDETECT_ALARM, { periodInMinutes: PLAN_REDETECT_PERIOD_MIN }),
  ]);
}

// ── Claude poll ─────────────────────────────────────────────

async function pollClaude(trigger: 'install' | 'alarm' | 'manual'): Promise<void> {
  const existing = await getBackoff();
  if (existing && Date.now() < existing.until && trigger !== 'manual') {
    console.log(`[tokenomics] skipping claude ${trigger} poll, backoff until`, new Date(existing.until));
    return;
  }

  try {
    const snapshot = await fetchClaudeUsage();
    await setClaudeSnapshot(snapshot);
    await setClaudeAuth('authenticated');
    await setBackoff(null);
    await updateBadge();
    console.log(`[tokenomics] claude poll ok (${trigger})`, snapshot);
  } catch (err) {
    if (err instanceof AuthError) {
      await setClaudeAuth('unauthenticated');
      await updateBadge();
      console.log('[tokenomics] claude not signed in');
    } else if (err instanceof RateLimitError) {
      const next = nextBackoff(existing);
      await setBackoff(next);
      console.warn('[tokenomics] claude rate limited until', new Date(next.until));
      throw err;
    } else {
      console.error('[tokenomics] claude poll failed', err);
      throw err;
    }
  }
}

function nextBackoff(prev: { nextDelayMs: number } | null) {
  const delay = prev?.nextDelayMs ?? BACKOFF_INITIAL_MS;
  return {
    until: Date.now() + delay,
    nextDelayMs: Math.min(delay * 2, BACKOFF_MAX_MS),
  };
}

// ── ChatGPT counter ─────────────────────────────────────────

async function recordChatGPTMessage(model: string | null, ts: number): Promise<void> {
  const existing = await getChatGPTEvents();
  const event: ChatGPTMessageEvent = { ts, model };
  const next = pruneEvents([...existing, event], Date.now());
  await setChatGPTEvents(next);
  console.log(`[tokenomics] chatgpt message observed (model=${model ?? 'unknown'})`);
  await recomputeChatGPTSnapshot();
}

async function recomputeChatGPTSnapshot(): Promise<void> {
  const [events, plan] = await Promise.all([getChatGPTEvents(), getChatGPTPlanEffective()]);
  if (events.length === 0 && plan === 'unknown') {
    // Nothing observed yet and no plan known — leave the empty state alone.
    return;
  }
  const snapshot = deriveSnapshot(events, plan);
  await setChatGPTSnapshot(snapshot);
  await updateBadge();
}

async function redetectChatGPTPlan(trigger: 'install' | 'alarm' | 'manual'): Promise<void> {
  try {
    const plan = await detectChatGPTPlan();
    await setChatGPTPlanAuto(plan);
    console.log(`[tokenomics] chatgpt plan auto-detected as '${plan}' (${trigger})`);
    if (plan !== 'unknown') await recomputeChatGPTSnapshot();
  } catch (err) {
    console.warn('[tokenomics] chatgpt plan detect failed', err);
  }
}

// ── Toolbar badge ───────────────────────────────────────────

async function updateBadge(): Promise<void> {
  const [pinned, claude, chatgpt] = await Promise.all([
    getPinnedProvider(),
    getClaudeSnapshot(),
    getChatGPTSnapshot(),
  ]);
  const live: Partial<Record<ProviderId, ProviderUsageSnapshot>> = {};
  if (claude) live.claude = claude;
  if (chatgpt) live.codex = chatgpt;

  let value: number | null = null;
  if (pinned && live[pinned]) {
    value = Math.round(live[pinned]!.shortWindow.utilization);
  } else if (!pinned) {
    const utils = Object.values(live).map((s) => Math.round(s!.shortWindow.utilization));
    if (utils.length > 0) value = Math.max(...utils);
  }

  if (value === null) {
    await clearBadge();
    return;
  }
  await browser.action.setBadgeText({ text: `${value}%` });
  await browser.action.setBadgeBackgroundColor({ color: '#2F84BF' });
  if ('setBadgeTextColor' in browser.action) {
    await browser.action.setBadgeTextColor({ color: '#FFFFFF' });
  }
}

async function clearBadge(): Promise<void> {
  await browser.action.setBadgeText({ text: '' });
}
