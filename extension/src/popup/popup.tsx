import { render } from 'preact';
import { useEffect, useState } from 'preact/hooks';
import browser from 'webextension-polyfill';
import type { ExtensionMessage, ExtensionResponse } from '../messages';
import {
  computePace,
  formatTimeUntilReset,
  type ProviderUsageSnapshot,
} from '../snapshot';
import {
  getClaudeSnapshot,
  getPinnedProvider,
  getSelectedTab,
  setPinnedProvider,
  setSelectedTab,
} from '../storage';
import { PROVIDERS, type ProviderId } from '../types';
import { EmptyState } from './components/EmptyState';
import { Header } from './components/Header';
import { ProviderTabBar } from './components/ProviderTabBar';
import { SyncFooter } from './components/SyncFooter';
import { UsageBar } from './components/UsageBar';

const DEFAULT_TAB: ProviderId = PROVIDERS[0];

/**
 * Phase 1 visible providers — only Claude has a live reader. Phase 1.5
 * will lift this to a derived value once additional snapshot keys exist.
 */
const VISIBLE_PROVIDERS: readonly ProviderId[] = ['claude'];

function applyTheme() {
  const isDark = window.matchMedia('(prefers-color-scheme: dark)').matches;
  document.documentElement.dataset.theme = isDark ? 'dark' : 'light';
}

function App() {
  const [selected, setSelected] = useState<ProviderId>(DEFAULT_TAB);
  const [pinned, setPinned] = useState<ProviderId | null>(null);
  const [snapshot, setSnapshot] = useState<ProviderUsageSnapshot | null>(null);
  const [isRefreshing, setIsRefreshing] = useState(false);

  // Initial load from storage.
  useEffect(() => {
    void getSelectedTab().then((stored) => {
      if (stored) setSelected(stored);
    });
    void getPinnedProvider().then(setPinned);
    void getClaudeSnapshot().then(setSnapshot);
  }, []);

  // Live updates from the service worker.
  useEffect(() => {
    const handler = (
      changes: Record<string, browser.Storage.StorageChange>,
      area: string,
    ) => {
      if (area !== 'local') return;
      if ('claudeSnapshot' in changes) {
        const next = changes['claudeSnapshot']?.newValue;
        setSnapshot((next as ProviderUsageSnapshot | undefined) ?? null);
      }
    };
    browser.storage.onChanged.addListener(handler);
    return () => browser.storage.onChanged.removeListener(handler);
  }, []);

  const handleSelectTab = (provider: ProviderId) => {
    setSelected(provider);
    void setSelectedTab(provider);
  };

  const handleSetSmart = () => {
    setPinned(null);
    void setPinnedProvider(null);
  };

  const handleTogglePin = (provider: ProviderId) => {
    const next = pinned === provider ? null : provider;
    setPinned(next);
    void setPinnedProvider(next);
  };

  const handleRefresh = async () => {
    setIsRefreshing(true);
    try {
      const message: ExtensionMessage = { kind: 'REFRESH_REQUESTED' };
      const response = (await browser.runtime.sendMessage(message)) as
        | ExtensionResponse
        | undefined;
      if (response?.kind === 'REFRESH_FAILED') {
        console.warn('[tokenomics] refresh failed:', response.error);
      } else if (response?.kind === 'REFRESH_BACKOFF') {
        console.warn('[tokenomics] refresh skipped, rate limited until', new Date(response.until));
      }
    } catch (err) {
      console.warn('[tokenomics] refresh dispatch failed', err);
    } finally {
      setIsRefreshing(false);
    }
  };

  const handleSettings = () => {
    console.log('[tokenomics] settings requested (options page lands later)');
  };

  const showLiveClaude = selected === 'claude' && snapshot !== null;
  const planLabel = showLiveClaude ? snapshot.planLabel : undefined;
  const lastSynced = showLiveClaude ? new Date(snapshot.capturedAt) : null;

  return (
    <div class="popup">
      <Header planLabel={planLabel} />
      <ProviderTabBar selected={selected} onSelect={handleSelectTab} />

      <main class="popup__body">
        {showLiveClaude ? renderUsageBars(snapshot) : <EmptyState provider={selected} />}
      </main>

      <SyncFooter
        lastSynced={lastSynced}
        isLoading={isRefreshing}
        onRefresh={handleRefresh}
        onSettings={handleSettings}
        visibleProviders={VISIBLE_PROVIDERS}
        pinnedProvider={pinned}
        onSetSmart={handleSetSmart}
        onTogglePin={handleTogglePin}
      />
    </div>
  );
}

function renderUsageBars(snapshot: ProviderUsageSnapshot) {
  const short = snapshot.shortWindow;
  const long = snapshot.longWindow;
  return (
    <div class="usage-stack">
      <UsageBar
        label={short.label}
        utilization={short.utilization}
        pace={computePace(short)}
        sublabel={formatTimeUntilReset(short)}
      />
      {long ? (
        <>
          <div class="usage-stack__divider" />
          <UsageBar
            isLong
            label={long.label}
            utilization={long.utilization}
            pace={computePace(long)}
            sublabel={formatTimeUntilReset(long)}
          />
        </>
      ) : null}
    </div>
  );
}

applyTheme();
window
  .matchMedia('(prefers-color-scheme: dark)')
  .addEventListener('change', applyTheme);

const root = document.getElementById('app');
if (root) render(<App />, root);
