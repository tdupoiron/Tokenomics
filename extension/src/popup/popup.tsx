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
  getChatGPTSnapshot,
  getClaudeSnapshot,
  getMidjourneySnapshot,
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
 * Providers with a live reader. As phases land, this grows — Phase 1 was
 * just Claude; Phase 1.5 adds ChatGPT (lives in the `codex` tab since it
 * represents the OpenAI account); Phase 4.5 adds Midjourney.
 */
const VISIBLE_PROVIDERS: readonly ProviderId[] = ['claude', 'codex', 'midjourney'];

type SnapshotMap = Partial<Record<ProviderId, ProviderUsageSnapshot>>;

function applyTheme() {
  const isDark = window.matchMedia('(prefers-color-scheme: dark)').matches;
  document.documentElement.dataset.theme = isDark ? 'dark' : 'light';
}

function App() {
  const [selected, setSelected] = useState<ProviderId>(DEFAULT_TAB);
  const [pinned, setPinned] = useState<ProviderId | null>(null);
  const [snapshots, setSnapshots] = useState<SnapshotMap>({});
  const [isRefreshing, setIsRefreshing] = useState(false);

  // Initial load from storage.
  useEffect(() => {
    void getSelectedTab().then((stored) => {
      if (stored) setSelected(stored);
    });
    void getPinnedProvider().then(setPinned);
    void Promise.all([getClaudeSnapshot(), getChatGPTSnapshot(), getMidjourneySnapshot()]).then(
      ([claude, chatgpt, midjourney]) => {
        setSnapshots({
          ...(claude ? { claude } : {}),
          ...(chatgpt ? { codex: chatgpt } : {}),
          ...(midjourney ? { midjourney } : {}),
        });
      },
    );
  }, []);

  // Live updates from the service worker.
  useEffect(() => {
    const handler = (
      changes: Record<string, browser.Storage.StorageChange>,
      area: string,
    ) => {
      if (area !== 'local') return;
      if ('claudeSnapshot' in changes) {
        const next = changes['claudeSnapshot']?.newValue as ProviderUsageSnapshot | undefined;
        setSnapshots((prev) => ({ ...prev, claude: next ?? undefined }));
      }
      if ('chatgptSnapshot' in changes) {
        const next = changes['chatgptSnapshot']?.newValue as ProviderUsageSnapshot | undefined;
        setSnapshots((prev) => ({ ...prev, codex: next ?? undefined }));
      }
      if ('midjourneySnapshot' in changes) {
        const next = changes['midjourneySnapshot']?.newValue as ProviderUsageSnapshot | undefined;
        setSnapshots((prev) => ({ ...prev, midjourney: next ?? undefined }));
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
    void browser.runtime.openOptionsPage();
  };

  const currentSnapshot = snapshots[selected];
  const planLabel = currentSnapshot?.planLabel || undefined;
  const estimated = currentSnapshot?.estimated === true;
  const lastSynced = currentSnapshot ? new Date(currentSnapshot.capturedAt) : null;

  return (
    <div class="popup">
      <Header planLabel={planLabel} estimated={estimated} />
      <ProviderTabBar selected={selected} onSelect={handleSelectTab} />

      <main class="popup__body">
        {currentSnapshot ? renderUsageBars(currentSnapshot) : <EmptyState provider={selected} />}
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
