import { PROVIDER_META, type ProviderId } from '../../types';

interface Props {
  provider: ProviderId;
}

const COMING_SOON: ReadonlySet<ProviderId> = new Set(['midjourney']);
const TRYTOKENOMICS_URL = 'https://trytokenomics.com';

const SIGN_IN: Partial<Record<ProviderId, { url: string; site: string }>> = {
  claude: { url: 'https://claude.ai', site: 'claude.ai' },
};

export function EmptyState({ provider }: Props) {
  const signIn = SIGN_IN[provider];
  if (signIn) {
    return (
      <div class="empty-state">
        <p class="empty-state__copy">
          Sign in to {signIn.site} in your browser to start tracking your usage.
        </p>
        <a
          class="empty-state__cta"
          href={signIn.url}
          target="_blank"
          rel="noreferrer noopener"
        >
          Open {signIn.site} →
        </a>
      </div>
    );
  }

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
