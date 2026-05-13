import { render } from 'preact';
import { useEffect, useState } from 'preact/hooks';
import { PROVIDERS, type ProviderId } from '../types';
import {
  getPinnedProvider,
  getSelectedTab,
  setPinnedProvider,
  setSelectedTab,
} from '../storage';
import { EmptyState } from './components/EmptyState';
import { Header } from './components/Header';
import { ProviderTabBar } from './components/ProviderTabBar';
import { SyncFooter } from './components/SyncFooter';
import { UsageBar } from './components/UsageBar';

const DEFAULT_TAB: ProviderId = PROVIDERS[0];

/**
 * Phase 1 visible providers — only Claude has a live data path in commit 5.
 * Commit 6 will replace this with a storage-derived value when more readers
 * land.
 */
const VISIBLE_PROVIDERS: readonly ProviderId[] = ['claude'];

/**
 * Hardcoded sample so commit 3 can review the UsageBar visual.
 * Commit 6 replaces this with the snapshot from chrome.storage.local.
 */
const SAMPLE_CLAUDE_USAGE = {
  shortWindow: {
    label: '5-Hour Window',
    utilization: 36,
    pace: 0.5,
    sublabel: 'Resets in 2h 30m',
  },
  longWindow: {
    label: '7-Day Window',
    utilization: 72,
    pace: 0.6,
    sublabel: 'Resets in 4d',
  },
  planLabel: 'Pro',
  lastSynced: new Date(),
};

function applyTheme() {
  const isDark = window.matchMedia('(prefers-color-scheme: dark)').matches;
  document.documentElement.dataset.theme = isDark ? 'dark' : 'light';
}

function App() {
  const [selected, setSelected] = useState<ProviderId>(DEFAULT_TAB);
  const [pinned, setPinned] = useState<ProviderId | null>(null);

  useEffect(() => {
    void getSelectedTab().then((stored) => {
      if (stored) setSelected(stored);
    });
    void getPinnedProvider().then(setPinned);
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

  const handleRefresh = () => {
    // Commit 5/6 will message the service worker to re-poll.
    console.log('[tokenomics] refresh requested');
  };

  const handleSettings = () => {
    // Options page lands in a later phase.
    console.log('[tokenomics] settings requested');
  };

  const showSampleUsage = selected === 'claude';

  return (
    <div class="popup">
      <Header planLabel={showSampleUsage ? SAMPLE_CLAUDE_USAGE.planLabel : undefined} />
      <ProviderTabBar selected={selected} onSelect={handleSelectTab} />

      <main class="popup__body">
        {showSampleUsage ? (
          <div class="usage-stack">
            <UsageBar {...SAMPLE_CLAUDE_USAGE.shortWindow} />
            <div class="usage-stack__divider" />
            <UsageBar {...SAMPLE_CLAUDE_USAGE.longWindow} isLong />
          </div>
        ) : (
          <EmptyState provider={selected} />
        )}
      </main>

      <SyncFooter
        lastSynced={showSampleUsage ? SAMPLE_CLAUDE_USAGE.lastSynced : null}
        isLoading={false}
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

applyTheme();
window
  .matchMedia('(prefers-color-scheme: dark)')
  .addEventListener('change', applyTheme);

const root = document.getElementById('app');
if (root) render(<App />, root);
