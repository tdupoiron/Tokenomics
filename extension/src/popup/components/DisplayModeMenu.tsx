import { useEffect, useRef, useState } from 'preact/hooks';
import { PROVIDER_META, type ProviderId } from '../../types';
import { IconCheck, IconChevronDown, IconCircleDot, IconPinFill } from './icons';

interface Props {
  visibleProviders: readonly ProviderId[];
  pinnedProvider: ProviderId | null;
  onSetSmart: () => void;
  onTogglePin: (provider: ProviderId) => void;
}

export function DisplayModeMenu({
  visibleProviders,
  pinnedProvider,
  onSetSmart,
  onTogglePin,
}: Props) {
  const [open, setOpen] = useState(false);
  const containerRef = useRef<HTMLDivElement>(null);
  const isSmart = pinnedProvider === null;

  useEffect(() => {
    if (!open) return;
    const handleDocClick = (event: MouseEvent) => {
      if (!containerRef.current?.contains(event.target as Node)) {
        setOpen(false);
      }
    };
    const handleKey = (event: KeyboardEvent) => {
      if (event.key === 'Escape') setOpen(false);
    };
    document.addEventListener('mousedown', handleDocClick);
    document.addEventListener('keydown', handleKey);
    return () => {
      document.removeEventListener('mousedown', handleDocClick);
      document.removeEventListener('keydown', handleKey);
    };
  }, [open]);

  return (
    <div class="display-mode" ref={containerRef}>
      <button
        type="button"
        class="display-mode__trigger"
        aria-haspopup="menu"
        aria-expanded={open}
        title="Toolbar display"
        onClick={() => setOpen((prev) => !prev)}
      >
        {isSmart ? <IconCircleDot size={12} /> : <IconPinFill size={12} />}
        <IconChevronDown size={6} class="display-mode__chevron" />
      </button>

      {open ? (
        <div class="display-mode__panel" role="menu">
          <div class="display-mode__heading">Toolbar Display</div>

          <button
            type="button"
            class="display-mode__item"
            role="menuitemradio"
            aria-checked={isSmart}
            onClick={() => {
              onSetSmart();
              setOpen(false);
            }}
          >
            <span class="display-mode__check">
              {isSmart ? <IconCheck size={10} /> : null}
            </span>
            <span class="display-mode__item-label">Smart (most urgent)</span>
          </button>

          <div class="display-mode__divider" />

          <div class="display-mode__heading display-mode__heading--sub">
            <IconPinFill size={10} />
            <span>Pin Tracker</span>
          </div>

          {visibleProviders.length === 0 ? (
            <div class="display-mode__empty">No connected providers yet</div>
          ) : (
            visibleProviders.map((provider) => {
              const isPinned = pinnedProvider === provider;
              return (
                <button
                  key={provider}
                  type="button"
                  class="display-mode__item"
                  role="menuitemradio"
                  aria-checked={isPinned}
                  onClick={() => {
                    onTogglePin(provider);
                    setOpen(false);
                  }}
                >
                  <span class="display-mode__check">
                    {isPinned ? <IconCheck size={10} /> : null}
                  </span>
                  <span class="display-mode__item-label">
                    {PROVIDER_META[provider].displayName}
                  </span>
                </button>
              );
            })
          )}
        </div>
      ) : null}
    </div>
  );
}
