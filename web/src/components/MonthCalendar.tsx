import { AppDate } from '../lib/date';
import { STATUS, type StatusKey } from '../types';

/**
 * A month grid where every day is tinted by status, Monday-first — the same
 * calendar the employee detail screen shows in the app.
 */
export default function MonthCalendar({
  year,
  month,
  statusByDay,
  joinedOn,
  onPick,
}: {
  year: number;
  /** 1-based. */
  month: number;
  statusByDay: Map<number, StatusKey>;
  joinedOn: Date;
  onPick: (day: number) => void;
}) {
  const days = AppDate.daysInMonth(year, month);
  const leading = AppDate.mondayIndex(new Date(year, month - 1, 1));
  const today = AppDate.today();

  return (
    <div className="cal">
      {Array.from({ length: 7 }, (_, i) => (
        <div key={`h${i}`} className="cal__head">
          {AppDate.weekdayInitial(i)}
        </div>
      ))}

      {Array.from({ length: leading }, (_, i) => (
        <div key={`b${i}`} className="cal__day cal__day--blank" />
      ))}

      {Array.from({ length: days }, (_, i) => {
        const dayNumber = i + 1;
        const date = new Date(year, month - 1, dayNumber);
        const status = statusByDay.get(dayNumber);
        const meta = status ? STATUS[status] : null;

        const isFuture = AppDate.isFuture(date);
        const beforeJoining =
          AppDate.dateOnly(date).getTime() < AppDate.dateOnly(joinedOn).getTime();
        const disabled = isFuture || beforeJoining;

        return (
          <button
            key={dayNumber}
            type="button"
            disabled={disabled}
            onClick={() => onPick(dayNumber)}
            title={
              beforeJoining
                ? 'Before joining'
                : isFuture
                  ? 'Future date'
                  : `${AppDate.display(date)} — ${meta?.label ?? 'Not marked'}`
            }
            className={`cal__day${AppDate.isSameDay(date, today) ? ' cal__day--today' : ''}`}
            style={
              meta
                ? {
                    background: `color-mix(in srgb, ${meta.color} 18%, var(--surface))`,
                    borderColor: `color-mix(in srgb, ${meta.color} 45%, transparent)`,
                  }
                : undefined
            }
          >
            {dayNumber}
            {meta && (
              <span className="cal__tag" style={{ color: meta.color }}>
                {meta.shortCode}
              </span>
            )}
          </button>
        );
      })}
    </div>
  );
}
