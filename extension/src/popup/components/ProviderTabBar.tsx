import { PROVIDER_META, type ProviderId } from '../../types';

interface Props {
  selected: ProviderId;
  /** Ordered list of visible provider IDs to render as tabs. */
  visibleProviderIds: readonly ProviderId[];
  onSelect: (provider: ProviderId) => void;
}

export function ProviderTabBar({ selected, visibleProviderIds, onSelect }: Props) {
  return (
    <div class="tab-bar" role="tablist">
      {visibleProviderIds.map((provider) => {
        const meta = PROVIDER_META[provider];
        const isSelected = provider === selected;
        return (
          <button
            key={provider}
            type="button"
            role="tab"
            aria-selected={isSelected}
            class={`tab${isSelected ? ' tab--selected' : ''}`}
            title={meta.tabLabel}
            onClick={() => onSelect(provider)}
          >
            <span class={`tab__icon tab__icon--${provider}`} aria-hidden="true" />
            {isSelected ? <span class="tab__label">{meta.tabLabel}</span> : null}
          </button>
        );
      })}
    </div>
  );
}
