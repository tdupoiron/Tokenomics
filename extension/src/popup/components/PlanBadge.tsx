interface Props {
  label: string;
}

export function PlanBadge({ label }: Props) {
  return <span class="plan-badge">{label}</span>;
}
