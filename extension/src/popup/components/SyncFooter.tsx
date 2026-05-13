import { useEffect, useState } from 'preact/hooks';
import type { ProviderId } from '../../types';
import { DisplayModeMenu } from './DisplayModeMenu';
import { IconGear, IconRefresh } from './icons';

interface Props {
  lastSynced: Date | null;
  isLoading: boolean;
  onRefresh: () => void;
  onSettings: () => void;
  visibleProviders: readonly ProviderId[];
  pinnedProvider: ProviderId | null;
  onSetSmart: () => void;
  onTogglePin: (provider: ProviderId) => void;
}

function formatSyncText(lastSynced: Date | null, now: number): string {
  if (!lastSynced) return 'Not yet synced';
  const elapsedSec = Math.max(0, (now - lastSynced.getTime()) / 1000);
  if (elapsedSec < 60) return 'Updated just now';
  const minutes = Math.floor(elapsedSec / 60);
  if (minutes >= 60) {
    const hours = Math.floor(minutes / 60);
    return `Updated ${hours}h ago`;
  }
  return `Updated ${minutes}m ago`;
}

export function SyncFooter({
  lastSynced,
  isLoading,
  onRefresh,
  onSettings,
  visibleProviders,
  pinnedProvider,
  onSetSmart,
  onTogglePin,
}: Props) {
  const [now, setNow] = useState(() => Date.now());
  useEffect(() => {
    const id = setInterval(() => setNow(Date.now()), 60_000);
    return () => clearInterval(id);
  }, []);

  return (
    <footer class="sync-footer">
      <span class="sync-footer__text">{formatSyncText(lastSynced, now)}</span>

      <div class="sync-footer__actions">
        <button
          type="button"
          class="sync-footer__icon-button"
          onClick={onRefresh}
          disabled={isLoading}
          aria-label="Refresh"
          title="Refresh"
        >
          <IconRefresh />
        </button>

        <span class="sync-footer__divider" aria-hidden="true" />

        <DisplayModeMenu
          visibleProviders={visibleProviders}
          pinnedProvider={pinnedProvider}
          onSetSmart={onSetSmart}
          onTogglePin={onTogglePin}
        />

        <span class="sync-footer__divider" aria-hidden="true" />

        <button
          type="button"
          class="sync-footer__icon-button"
          onClick={onSettings}
          aria-label="Settings"
          title="Settings"
        >
          <IconGear />
        </button>
      </div>
    </footer>
  );
}
