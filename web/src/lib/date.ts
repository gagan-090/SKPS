/**
 * Date helpers — a direct port of `lib/core/utils/date_utils.dart`.
 *
 * Every `day` value sent to Postgres is a naive `YYYY-MM-DD` string built from
 * the *local* browser date. We never call `toISOString()` for a day column:
 * India is UTC+05:30, so a UTC conversion before 05:30 IST would silently shift
 * the day backwards.
 */

const MONTHS_LONG = [
  'January', 'February', 'March', 'April', 'May', 'June',
  'July', 'August', 'September', 'October', 'November', 'December',
];

const MONTHS_SHORT = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

const WEEKDAYS_LONG = [
  'Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday',
];

const pad = (n: number, width = 2) => String(n).padStart(width, '0');

export const AppDate = {
  /** `YYYY-MM-DD` from the local calendar date. The storage format. */
  ymd(date: Date): string {
    return `${pad(date.getFullYear(), 4)}-${pad(date.getMonth() + 1)}-${pad(date.getDate())}`;
  },

  /** Parses `YYYY-MM-DD` (tolerates a full timestamp) into local midnight. */
  parseYmd(value: string): Date {
    const datePart = value.length >= 10 ? value.slice(0, 10) : value;
    const parts = datePart.split('-');
    if (parts.length !== 3) return AppDate.today();
    return new Date(
      Number(parts[0]) || 1970,
      (Number(parts[1]) || 1) - 1,
      Number(parts[2]) || 1,
    );
  },

  /** Strips any time component, keeping the local calendar date. */
  dateOnly(date: Date): Date {
    return new Date(date.getFullYear(), date.getMonth(), date.getDate());
  },

  today(): Date {
    return AppDate.dateOnly(new Date());
  },

  isSameDay(a: Date, b: Date): boolean {
    return (
      a.getFullYear() === b.getFullYear() &&
      a.getMonth() === b.getMonth() &&
      a.getDate() === b.getDate()
    );
  },

  isFuture(date: Date): boolean {
    return AppDate.dateOnly(date).getTime() > AppDate.today().getTime();
  },

  isToday(date: Date): boolean {
    return AppDate.isSameDay(date, new Date());
  },

  /** `month` is 1-based, matching the Dart original. */
  daysInMonth(year: number, month: number): number {
    return new Date(year, month, 0).getDate();
  },

  /** Inclusive first/last day of the given month (1-based month). */
  monthRange(year: number, month: number): { first: Date; last: Date } {
    return {
      first: new Date(year, month - 1, 1),
      last: new Date(year, month - 1, AppDate.daysInMonth(year, month)),
    };
  },

  // ---- display formatters -------------------------------------------------

  /** `05 Aug 2026` */
  display(date: Date): string {
    return `${pad(date.getDate())} ${MONTHS_SHORT[date.getMonth()]} ${date.getFullYear()}`;
  },

  /** `Wednesday, 05 Aug 2026` */
  displayLong(date: Date): string {
    return `${WEEKDAYS_LONG[date.getDay()]}, ${AppDate.display(date)}`;
  },

  /** `05 Aug` */
  displayShort(date: Date): string {
    return `${pad(date.getDate())} ${MONTHS_SHORT[date.getMonth()]}`;
  },

  /** `August 2026` (1-based month) */
  monthYear(year: number, month: number): string {
    return `${MONTHS_LONG[month - 1]} ${year}`;
  },

  /** `Aug` (1-based month) */
  monthAbbr(month: number): string {
    return MONTHS_SHORT[month - 1];
  },

  /** `9:42 AM` */
  time(date: Date): string {
    const h24 = date.getHours();
    const h = h24 % 12 === 0 ? 12 : h24 % 12;
    return `${h}:${pad(date.getMinutes())} ${h24 < 12 ? 'AM' : 'PM'}`;
  },

  /** Weekday header for the calendar grid, Monday-first. */
  weekdayInitial(index: number): string {
    return ['M', 'T', 'W', 'T', 'F', 'S', 'S'][index] ?? '';
  },

  /** Monday = 0 … Sunday = 6, so the calendar grid starts on Monday. */
  mondayIndex(date: Date): number {
    return (date.getDay() + 6) % 7;
  },

  isWeekend(date: Date): boolean {
    const d = date.getDay();
    return d === 0 || d === 6;
  },

  /** A friendly label for the attendance date selector. */
  relativeLabel(date: Date): string {
    const t = AppDate.today().getTime();
    const d = AppDate.dateOnly(date);
    const diff = Math.round((t - d.getTime()) / 86_400_000);
    if (diff === 0) return 'Today';
    if (diff === 1) return 'Yesterday';
    return AppDate.display(d);
  },
};
