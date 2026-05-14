import { PlanBadge } from './PlanBadge';

interface Props {
  planLabel?: string;
  estimated?: boolean;
}

export function Header({ planLabel, estimated }: Props) {
  return (
    <header class="header">
      <h1 class="header__title">Tokenomics</h1>
      <div class="header__meta">
        {estimated ? <span class="header__estimated">estimated</span> : null}
        {planLabel ? <PlanBadge label={planLabel} /> : null}
      </div>
    </header>
  );
}
