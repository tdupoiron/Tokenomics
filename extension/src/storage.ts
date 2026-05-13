import browser from 'webextension-polyfill';
import { isProviderId, type ProviderId } from './types';
import type { AuthState, BackoffState, ProviderUsageSnapshot } from './snapshot';

const KEYS = {
  selectedTab: 'selectedTab',
  pinnedProvider: 'pinnedProvider',
  claudeOrgId: 'claudeOrgId',
  claudeSnapshot: 'claudeSnapshot',
  claudeAuth: 'claudeAuth',
  claudeBackoff: 'claudeBackoff',
} as const;

const ORG_ID_TTL_MS = 24 * 60 * 60 * 1000;

interface CachedOrgId {
  value: string;
  expiresAt: number;
}

// ── selectedTab ─────────────────────────────────────────────

export async function getSelectedTab(): Promise<ProviderId | null> {
  const result = await browser.storage.local.get(KEYS.selectedTab);
  const raw = result[KEYS.selectedTab];
  return isProviderId(raw) ? raw : null;
}

export async function setSelectedTab(tab: ProviderId): Promise<void> {
  await browser.storage.local.set({ [KEYS.selectedTab]: tab });
}

// ── pinnedProvider ──────────────────────────────────────────

export async function getPinnedProvider(): Promise<ProviderId | null> {
  const result = await browser.storage.local.get(KEYS.pinnedProvider);
  const raw = result[KEYS.pinnedProvider];
  return isProviderId(raw) ? raw : null;
}

export async function setPinnedProvider(provider: ProviderId | null): Promise<void> {
  if (provider === null) {
    await browser.storage.local.remove(KEYS.pinnedProvider);
  } else {
    await browser.storage.local.set({ [KEYS.pinnedProvider]: provider });
  }
}

// ── Claude org id cache (24h TTL) ───────────────────────────

export async function getCachedOrgId(): Promise<string | null> {
  const result = await browser.storage.local.get(KEYS.claudeOrgId);
  const raw = result[KEYS.claudeOrgId] as CachedOrgId | undefined;
  if (!raw || typeof raw.value !== 'string') return null;
  if (Date.now() > raw.expiresAt) return null;
  return raw.value;
}

export async function setCachedOrgId(value: string): Promise<void> {
  const cached: CachedOrgId = { value, expiresAt: Date.now() + ORG_ID_TTL_MS };
  await browser.storage.local.set({ [KEYS.claudeOrgId]: cached });
}

// ── Claude snapshot ─────────────────────────────────────────

export async function getClaudeSnapshot(): Promise<ProviderUsageSnapshot | null> {
  const result = await browser.storage.local.get(KEYS.claudeSnapshot);
  const raw = result[KEYS.claudeSnapshot];
  if (!raw || typeof raw !== 'object') return null;
  return raw as ProviderUsageSnapshot;
}

export async function setClaudeSnapshot(snapshot: ProviderUsageSnapshot): Promise<void> {
  await browser.storage.local.set({ [KEYS.claudeSnapshot]: snapshot });
}

// ── Claude auth state ───────────────────────────────────────

export async function getClaudeAuth(): Promise<AuthState> {
  const result = await browser.storage.local.get(KEYS.claudeAuth);
  const raw = result[KEYS.claudeAuth];
  if (raw === 'authenticated' || raw === 'unauthenticated') return raw;
  return 'unknown';
}

export async function setClaudeAuth(state: AuthState): Promise<void> {
  await browser.storage.local.set({ [KEYS.claudeAuth]: state });
}

// ── Backoff (rate-limit) state ──────────────────────────────

export async function getBackoff(): Promise<BackoffState | null> {
  const result = await browser.storage.local.get(KEYS.claudeBackoff);
  const raw = result[KEYS.claudeBackoff];
  if (
    !raw ||
    typeof raw !== 'object' ||
    typeof (raw as BackoffState).until !== 'number' ||
    typeof (raw as BackoffState).nextDelayMs !== 'number'
  ) {
    return null;
  }
  return raw as BackoffState;
}

export async function setBackoff(state: BackoffState | null): Promise<void> {
  if (state === null) {
    await browser.storage.local.remove(KEYS.claudeBackoff);
  } else {
    await browser.storage.local.set({ [KEYS.claudeBackoff]: state });
  }
}
