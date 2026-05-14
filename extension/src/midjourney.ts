/**
 * Midjourney usage reader.
 *
 * Polls https://www.midjourney.com/api/user-account with the user's session
 * cookie (credentials: 'include') plus the X-CSRF-Protection header that the
 * MJ web client uses for its own API calls. The cookie auth pattern mirrors
 * claude.ts — no token extraction, no API key, no DOM scraping. The CSRF
 * header is a static '1' (not a per-session token).
 *
 * Endpoint shape verified 2026-05-14 against a real account. See `interface
 * UserAccountResponse` below for the fields we depend on. The Midjourney web
 * client uses this same endpoint to populate the Account Settings page.
 *
 * Billing unit is "credits" — the static plan catalog inside the response
 * lets us derive a stable conversion factor:
 *   - Basic plan: 12,000,000 credits / month → ~200 images → ~3.3 Fast hours
 *   - Standard:   54,000,000 credits / month → 15 Fast hours
 *   - Pro:       108,000,000 credits / month → 30 Fast hours
 *   - Mega:      216,000,000 credits / month → 60 Fast hours
 *
 *   ⇒ 60,000 credits = 1 Fast minute (exact across all paid tiers).
 */

import type { ProviderUsageSnapshot, WindowUsage } from './snapshot';

const API_URL = 'https://www.midjourney.com/api/user-account';

/** 60,000 credits = 1 Fast minute. Stable across all paid tiers. */
const CREDITS_PER_FAST_MINUTE = 60_000;

/** Default billing cycle when the response omits a renewal timestamp. */
const THIRTY_DAY_SEC = 30 * 24 * 3600;
const THIRTY_DAY_MS = THIRTY_DAY_SEC * 1000;

export class AuthError extends Error {
  constructor() {
    super('Not signed in to midjourney.com');
    this.name = 'AuthError';
  }
}

export class RateLimitError extends Error {
  constructor() {
    super('midjourney.com rate limited the request');
    this.name = 'RateLimitError';
  }
}

// ── Response types (verified against a real /api/user-account response) ──

interface UserAccountResponse {
  user?: {
    abilities?: {
      billing?: boolean;
      subscription?: {
        type?: string; // 'none' when not subscribed, 'plan' (assumed) when active
        key?: string;  // 'basic' | 'standard' | 'pro' | 'mega' when type === 'plan'
      };
    };
  };
  plans?: ReadonlyArray<{
    type?: string;
    key?: string;
    copy?: { name?: string };
    credit_period?: string; // 'month' | 'year'
    credit_allocation?: number;
  }>;
  userData?: {
    status?: string;
    created?: number;
    updated?: number;
    period_credits?: number;
    credit_period_usage?: number;
    period_credits_used?: number; // alias seen on trial accounts
    credits_total?: number;
    // Some MJ accounts include a renewal timestamp; field name unconfirmed.
    next_period_at?: number;
    period_ends_at?: number;
    credit_period_ends_at?: number;
  };
}

export async function fetchMidjourneyUsage(): Promise<ProviderUsageSnapshot> {
  const res = await fetch(API_URL, {
    credentials: 'include',
    headers: { 'X-CSRF-Protection': '1' },
  });
  throwOnAuthOrRateLimit(res);
  if (!res.ok) throw new Error(`midjourney user-account fetch failed: ${res.status}`);

  const raw = (await res.json()) as UserAccountResponse;
  return mapToSnapshot(raw);
}

function throwOnAuthOrRateLimit(res: Response): void {
  if (res.status === 401 || res.status === 403) throw new AuthError();
  if (res.status === 429) throw new RateLimitError();
}

/** Pure mapper — exported for testing. */
export function mapToSnapshot(
  raw: UserAccountResponse,
  now: number = Date.now(),
): ProviderUsageSnapshot {
  const planKey = raw.user?.abilities?.subscription?.key?.toLowerCase() ?? '';
  const subscribed = raw.user?.abilities?.subscription?.type === 'plan';

  const planLabel = subscribed
    ? planLabelFromCatalog(raw.plans, planKey) ?? toDisplayPlan(planKey)
    : 'No plan';

  const periodCredits = toNumber(raw.userData?.period_credits, 0);
  const usedCredits =
    toNumber(raw.userData?.credit_period_usage, NaN) ||
    toNumber(raw.userData?.period_credits_used, 0);

  // If we don't have a subscription OR have no allocation, expose a zero bar
  // rather than a misleading partial fill. Avoids divide-by-zero on trials.
  const utilization =
    periodCredits > 0
      ? Math.min(100, Math.max(0, Math.round((usedCredits / periodCredits) * 100)))
      : 0;

  const fastMinutesUsed = usedCredits / CREDITS_PER_FAST_MINUTE;
  const fastMinutesTotal = periodCredits / CREDITS_PER_FAST_MINUTE;

  const resetMs = resolveResetMs(raw, now);
  const resetsAt = new Date(resetMs).toISOString();

  const fastWindow: WindowUsage = {
    label: 'Fast Hours',
    utilization,
    resetsAt,
    windowDurationSec: THIRTY_DAY_SEC,
    sublabelOverride: subscribed
      ? formatFastSublabel(fastMinutesUsed, fastMinutesTotal, resetMs, now)
      : 'No active subscription',
  };

  return {
    provider: 'midjourney',
    shortWindow: fastWindow,
    longWindow: null,
    extras: {},
    planLabel,
    capturedAt: now,
    estimated: false,
  };
}

function planLabelFromCatalog(
  plans: UserAccountResponse['plans'],
  key: string,
): string | null {
  if (!plans || !key) return null;
  for (const p of plans) {
    if (typeof p?.key === 'string' && p.key.toLowerCase() === key) {
      const name = p.copy?.name;
      if (typeof name === 'string' && name.length > 0) return name;
    }
  }
  return null;
}

function toDisplayPlan(key: string): string {
  switch (key) {
    case 'basic':    return 'Basic';
    case 'standard': return 'Standard';
    case 'pro':      return 'Pro';
    case 'mega':     return 'Mega';
    default:         return 'Midjourney';
  }
}

function resolveResetMs(raw: UserAccountResponse, now: number): number {
  const candidates = [
    raw.userData?.next_period_at,
    raw.userData?.period_ends_at,
    raw.userData?.credit_period_ends_at,
  ];
  for (const c of candidates) {
    if (typeof c === 'number' && Number.isFinite(c) && c > now) return c;
  }
  // Fall back to `updated` (most recent activity) + 30d. For accounts without
  // an explicit renewal field, this is the best monthly-cycle approximation.
  const anchor = toNumber(raw.userData?.updated, NaN) || toNumber(raw.userData?.created, now);
  return anchor + THIRTY_DAY_MS;
}

function formatFastSublabel(
  usedMin: number,
  totalMin: number,
  resetMs: number,
  now: number,
): string {
  const used = formatHoursMinutes(usedMin);
  if (totalMin <= 0) {
    return `${used} used`;
  }
  const total = formatHoursMinutes(totalMin);
  const reset = formatResetCompact(resetMs, now);
  return reset
    ? `${used} of ${total} · ${reset}`
    : `${used} of ${total}`;
}

function formatHoursMinutes(min: number): string {
  if (!Number.isFinite(min) || min <= 0) return '0m';
  const total = Math.round(min);
  const h = Math.floor(total / 60);
  const m = total % 60;
  if (h <= 0) return `${m}m`;
  if (m <= 0) return `${h}h`;
  return `${h}h ${m}m`;
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

function toNumber(value: unknown, fallback: number): number {
  if (typeof value === 'number' && Number.isFinite(value)) return value;
  if (typeof value === 'string') {
    const parsed = parseFloat(value);
    if (Number.isFinite(parsed)) return parsed;
  }
  return fallback;
}
