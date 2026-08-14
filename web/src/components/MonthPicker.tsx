import { Button } from './ui';
import { AppDate } from '../lib/date';

/** Prev / next month stepper, capped at the current month. */
export default function MonthPicker({
  year,
  month,
  onChange,
}: {
  year: number;
  /** 1-based. */
  month: number;
  onChange: (year: number, month: number) => void;
}) {
  const now = AppDate.today();
  const atCurrent = year === now.getFullYear() && month === now.getMonth() + 1;

  function step(delta: number) {
    const next = new Date(year, month - 1 + delta, 1);
    onChange(next.getFullYear(), next.getMonth() + 1);
  }

  return (
    <div className="row">
      <Button variant="ghost" size="sm" onClick={() => step(-1)} aria-label="Previous month">
        ‹
      </Button>
      <strong className="nowrap" style={{ minWidth: 140, textAlign: 'center' }}>
        {AppDate.monthYear(year, month)}
      </strong>
      <Button
        variant="ghost"
        size="sm"
        onClick={() => step(1)}
        disabled={atCurrent}
        aria-label="Next month"
      >
        ›
      </Button>
    </div>
  );
}
