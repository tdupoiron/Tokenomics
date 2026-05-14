import type { ProviderUsageSnapshot, WindowUsage } from './snapshot';
import { getCachedOrgId, setCachedOrgId } from './storage';

const API_BASE = 'https://claude.ai/api';
const FIVE_HOUR_SEC = 5 * 3600;
const SEVEN_DAY_SEC = 7 * 86400;

export class AuthError extends Error {
  constructor() {
    super('Not signed in to claude.ai');
    this.name = 'AuthError';
  }
}

export class RateLimitError extends Error {
  constructor() {
    super('claude.ai rate limited the request');
    this.name = 'RateLimitError';
  }
}

interface OrganizationsResponse {
  uuid: string;
}

interface UsageWindow {
  utilization: number;
  resets_at: string;
}

interface UsageResponse {
  five_hour?: UsageWindow;
  seven_day?: UsageWindow;
  seven_day_opus?: UsageWindow;
}

export async function fetchClaudeUsage(): Promise<ProviderUsageSnapshot> {
  const orgId = await getOrgId();
  const usage = await fetchUsage(orgId);
  return mapToSnapshot(usage);
}

async function getOrgId(): Promise<string> {
  const cached = await getCachedOrgId();
  if (cached) return cached;

  const res = await fetch(`${API_BASE}/organizations`, { credentials: 'include' });
  throwOnAuthOrRateLimit(res);
  if (!res.ok) throw new Error(`organizations fetch failed: ${res.status}`);

  const data = (await res.json()) as OrganizationsResponse[];
  if (!Array.isArray(data) || data.length === 0 || !data[0]?.uuid) {
    throw new Error('No organizations on this account');
  }

  const orgId = data[0].uuid;
  await setCachedOrgId(orgId);
  return orgId;
}

async function fetchUsage(orgId: string): Promise<UsageResponse> {
  const res = await fetch(`${API_BASE}/organizations/${orgId}/usage`, {
    credentials: 'include',
  });
  throwOnAuthOrRateLimit(res);
  if (!res.ok) throw new Error(`usage fetch failed: ${res.status}`);
  return (await res.json()) as UsageResponse;
}

function throwOnAuthOrRateLimit(res: Response): void {
  if (res.status === 401 || res.status === 403) throw new AuthError();
  if (res.status === 429) throw new RateLimitError();
}

function mapToSnapshot(usage: UsageResponse): ProviderUsageSnapshot {
  const shortWindow: WindowUsage = makeWindow('5-Hour Window', usage.five_hour, FIVE_HOUR_SEC) ?? {
    label: '5-Hour Window',
    utilization: 0,
    resetsAt: '',
    windowDurationSec: FIVE_HOUR_SEC,
  };

  const longWindow = makeWindow('7-Day Window', usage.seven_day, SEVEN_DAY_SEC);

  const extras: ProviderUsageSnapshot['extras'] = {};
  const opus = makeWindow('Opus 7-Day', usage.seven_day_opus, SEVEN_DAY_SEC);
  if (opus) extras.opusSevenDay = opus;

  return {
    provider: 'claude',
    shortWindow,
    longWindow,
    extras,
    // TODO: derive plan from /organizations response (settings/capabilities).
    // Defaulting to "Pro" matches the dominant consumer cohort for now.
    planLabel: 'Pro',
    capturedAt: Date.now(),
  };
}

function makeWindow(
  label: string,
  raw: UsageWindow | undefined,
  durationSec: number,
): WindowUsage | null {
  if (!raw || typeof raw.utilization !== 'number') return null;
  return {
    label,
    // claude.ai's /usage endpoint returns utilization already as a percentage
    // (0–100, e.g. `7` for 7%) — the plan doc's `0.36` example was wrong.
    // No multiplier; just guard against negative and absurd values.
    utilization: Math.max(0, raw.utilization),
    resetsAt: raw.resets_at,
    windowDurationSec: durationSec,
  };
}
