import browser from 'webextension-polyfill';
import { isProviderId, type ProviderId } from './types';

const KEYS = {
  selectedTab: 'selectedTab',
  pinnedProvider: 'pinnedProvider',
} as const;

export async function getSelectedTab(): Promise<ProviderId | null> {
  const result = await browser.storage.local.get(KEYS.selectedTab);
  const raw = result[KEYS.selectedTab];
  return isProviderId(raw) ? raw : null;
}

export async function setSelectedTab(tab: ProviderId): Promise<void> {
  await browser.storage.local.set({ [KEYS.selectedTab]: tab });
}

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
