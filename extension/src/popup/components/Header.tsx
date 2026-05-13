import { PlanBadge } from './PlanBadge';

interface Props {
  planLabel?: string;
}

export function Header({ planLabel }: Props) {
  return (
    <header class="header">
      <h1 class="header__title">Tokenomics</h1>
      {planLabel ? <PlanBadge label={planLabel} /> : null}
    </header>
  );
}
