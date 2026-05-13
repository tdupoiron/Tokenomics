import { useEffect, useState } from 'preact/hooks';

interface Props {
  label: string;
  utilization: number;
  pace: number;
  sublabel: string;
}

const BAR_HEIGHT = 6;

function clamp(value: number, min: number, max: number): number {
  return Math.min(Math.max(value, min), max);
}

export function UsageBar({ label, utilization, pace, sublabel }: Props) {
  const target = clamp(utilization / 100, 0, 1);
  const clampedPace = clamp(pace, 0, 1);
  const showPaceMarker = clampedPace > 0.01 && clampedPace < 0.99;

  const [animated, setAnimated] = useState(0);
  useEffect(() => {
    const id = requestAnimationFrame(() => setAnimated(target));
    return () => cancelAnimationFrame(id);
  }, [target]);

  return (
    <div class="usage-bar">
      <div class="usage-bar__header">
        <span class="usage-bar__label">{label}</span>
        <span class="usage-bar__value">{Math.round(utilization)}%</span>
      </div>

      <div class="usage-bar__track">
        <div
          class="usage-bar__fill"
          style={{ width: `${animated * 100}%` }}
        />
        {showPaceMarker ? (
          <div
            class="usage-bar__pace"
            style={{ left: `calc(${clampedPace * 100}% - ${BAR_HEIGHT / 2}px)` }}
          />
        ) : null}
      </div>

      <span class="usage-bar__sublabel">{sublabel}</span>
    </div>
  );
}
