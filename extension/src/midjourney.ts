/**
 * Midjourney usage reader.
 *
 * Polls https://www.midjourney.com/api/app/billing/balance with the user's
 * session cookie (credentials: 'include'). The cookie auth pattern mirrors
 * claude.ts — no token extraction, no API key, no DOM scraping.
 *
 * ENDPOINT SHAPE — verification status (2026-05-13):
 * The plan doc §4.4 hypothesised the response shape below. No public API
 * docs exist and no open-source tracker was found in GitHub code search
 * that hits this specific endpoint. The field names below are the plan's
 * best guess based on the web app's observable behaviour. If the parser
 * encounters unknown/missing fields it defaults safely and logs the raw
 * body so a future maintainer can update the mapping. Treat this as
 * "version 1, needs real-user validation."
 *
 * Hypothesised response body:
 * {
 *   fast_time_remaining_min: number,   // Fast time left this cycle (minutes)
 *   fast_time_total_min: number,       // Fast time cap for the plan (minutes)
 *   relax_time_used_min?: number,      // Relax time used (unbounded on paid plans)
 *   gpu_minutes_used?: number,         // GPU minutes consumed
 *   gpu_minutes_included?: number,     // GPU minutes cap (absent → unlimited)
 *   plan?: 'standard' | 'pro' | 'mega', // Plan tier
 *   cycle_resets_at?: string,          // ISO-8601 billing-cycle reset date
 * }
 *
 * If the real response differs, the parser falls through to safe defaults
 * and the console logs the raw body for debugging.
 */

import type { ProviderUsageSnapshot, WindowUsage } from './snapshot';

const API_URL = 'https://www.midjourney.com/api/app/billing/balance';

/** Minutes of Fast time per plan tier. Used when the response omits the cap. */
const FAST_MINUTES_BY_PLAN: Record<string, number> = {
  standard: 15 * 60,   // 15 Fast hours = 900 min
  pro:      30 * 60,   // 30 Fast hours = 1800 min
  mega:     60 * 60,   // 60 Fast hours = 3600 min
};

const FALLBACK_FAST_MINUTES = 15 * 60; // assume Standard when plan unknown

// Billing cycle approximation: 30 days in seconds (used when no reset date)
const THIRTY_DAY_SEC = 30 * 24 * 3600;

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

/** Raw response shape from /api/app/billing/balance (fields may be absent). */
interface BillingBalanceResponse {
  fast_time_remaining_min?: unknown;
  fast_time_total_min?: unknown;
  relax_time_used_min?: unknown;
  gpu_minutes_used?: unknown;
  gpu_minutes_included?: unknown;
  plan?: unknown;
  cycle_resets_at?: unknown;
  // Allow extra unknown fields without TypeScript errors.
  [key: string]: unknown;
}

/** Fetch and parse Midjourney billing balance into a ProviderUsageSnapshot. */
export async function fetchMidjourneyUsage(): Promise<ProviderUsageSnapshot> {
  const res = await fetch(API_URL, { credentials: 'include' });
  throwOnAuthOrRateLimit(res);
  if (!res.ok) throw new Error(`midjourney billing/balance fetch failed: ${res.status}`);

  const raw = (await res.json()) as BillingBalanceResponse;

  // Log the full response body on every successful poll. This is intentional:
  // the field names are hypothesised — having real payloads in the console
  // lets us validate and update the parser without another investigation pass.
  console.log('[tokenomics] midjourney raw billing response:', JSON.stringify(raw));

  return mapToSnapshot(raw);
}

function throwOnAuthOrRateLimit(res: Response): void {
  if (res.status === 401 || res.status === 403) throw new AuthError();
  if (res.status === 429) throw new RateLimitError();
}

function mapToSnapshot(raw: BillingBalanceResponse): ProviderUsageSnapshot {
  const planStr = typeof raw.plan === 'string' ? raw.plan.toLowerCase() : '';
  const planLabel = toDisplayPlan(planStr);

  const fastRemMin = toNumber(raw.fast_time_remaining_min, 0);
  const fastTotalMin =
    toNumber(raw.fast_time_total_min, 0) ||
    FAST_MINUTES_BY_PLAN[planStr] ||
    FALLBACK_FAST_MINUTES;

  // Fast usage % (0–100). Remaining is what's left, so used = total - remaining.
  const fastUsedPct = fastTotalMin > 0
    ? Math.min(100, Math.max(0, ((fastTotalMin - fastRemMin) / fastTotalMin) * 100))
    : 0;

  const cycleResetsAt = typeof raw.cycle_resets_at === 'string' ? raw.cycle_resets_at : '';

  const fastWindow: WindowUsage = {
    label: 'Fast Hours',
    utilization: fastUsedPct,
    resetsAt: cycleResetsAt,
    windowDurationSec: THIRTY_DAY_SEC,
  };

  // GPU minutes window — only present when the plan has a cap.
  let gpuWindow: WindowUsage | null = null;
  const gpuUsed = toNumber(raw.gpu_minutes_used, -1);
  const gpuIncluded = toNumber(raw.gpu_minutes_included, -1);
  if (gpuUsed >= 0 && gpuIncluded > 0) {
    const gpuPct = Math.min(100, Math.max(0, (gpuUsed / gpuIncluded) * 100));
    gpuWindow = {
      label: 'GPU Minutes',
      utilization: gpuPct,
      resetsAt: cycleResetsAt,
      windowDurationSec: THIRTY_DAY_SEC,
    };
  }

  return {
    provider: 'midjourney',
    shortWindow: fastWindow,
    longWindow: gpuWindow,
    extras: {},
    planLabel,
    capturedAt: Date.now(),
    estimated: false,
  };
}

/** Map plan string from the API to a human-readable label. */
function toDisplayPlan(plan: string): string {
  switch (plan) {
    case 'standard': return 'Standard';
    case 'pro':      return 'Pro';
    case 'mega':     return 'Mega';
    default:         return 'Midjourney';
  }
}

/** Safely coerce an unknown value to a number, returning fallback on failure. */
function toNumber(value: unknown, fallback: number): number {
  if (typeof value === 'number' && Number.isFinite(value)) return value;
  if (typeof value === 'string') {
    const parsed = parseFloat(value);
    if (Number.isFinite(parsed)) return parsed;
  }
  return fallback;
}
