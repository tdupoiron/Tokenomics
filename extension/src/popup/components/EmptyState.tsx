import { PROVIDER_META, type ProviderId } from '../../types';

interface Props {
  provider: ProviderId;
}

const COMING_SOON: ReadonlySet<ProviderId> = new Set(['midjourney']);
const TRYTOKENOMICS_URL = 'https://trytokenomics.com';

export function EmptyState({ provider }: Props) {
  if (COMING_SOON.has(provider)) {
    return (
      <div class="empty-state">
        <p class="empty-state__copy">Coming in the next update.</p>
      </div>
    );
  }

  const meta = PROVIDER_META[provider];
  return (
    <div class="empty-state">
      <p class="empty-state__copy">
        Track {meta.displayName} in the Tokenomics menu bar app.
      </p>
      <a
        class="empty-state__cta"
        href={TRYTOKENOMICS_URL}
        target="_blank"
        rel="noreferrer noopener"
      >
        Install Tokenomics →
      </a>
    </div>
  );
}
