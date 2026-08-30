import { AppDate } from '../lib/date';
import { StatusColor } from '../lib/colors';

/* -------------------------------------------------------------------------
   AttendanceStatus — mirrors the `attendance_status` Postgres enum.
   ------------------------------------------------------------------------- */

export type StatusKey = 'present' | 'absent' | 'half_day' | 'leave';

export interface StatusMeta {
  dbValue: StatusKey;
  label: string;
  /** One-letter code used in the selector, calendar and reports. */
  shortCode: string;
  color: string;
  /** How much of a working day this counts for, used for payroll-ish totals. */
  dayValue: number;
}

export const STATUS: Record<StatusKey, StatusMeta> = {
  present: { dbValue: 'present', label: 'Present', shortCode: 'P', color: StatusColor.present, dayValue: 1 },
  absent: { dbValue: 'absent', label: 'Absent', shortCode: 'A', color: StatusColor.absent, dayValue: 0 },
  half_day: { dbValue: 'half_day', label: 'Half Day', shortCode: 'H', color: StatusColor.half_day, dayValue: 0.5 },
  leave: { dbValue: 'leave', label: 'Leave', shortCode: 'L', color: StatusColor.leave, dayValue: 0 },
};

export const STATUS_KEYS: StatusKey[] = ['present', 'absent', 'half_day', 'leave'];

/** Unknown value from a newer schema: treat as absent rather than crashing. */
export function statusFromDb(value: string | null | undefined): StatusKey {
  return value && value in STATUS ? (value as StatusKey) : 'absent';
}

/* -------------------------------------------------------------------------
   Employee
   ------------------------------------------------------------------------- */

/** How an employee's `salaryAmount` should be read. */
export type SalaryType = 'per_day' | 'monthly';

/**
 * A monthly wage is spread over a nominal 30-day month to get a daily rate.
 * Mirrors `Employee.daysInSalaryMonth` in the Flutter app.
 */
export const DAYS_IN_SALARY_MONTH = 30;

export function salaryTypeFromDb(value: string | null | undefined): SalaryType {
  return value === 'monthly' ? 'monthly' : 'per_day';
}

export interface Employee {
  id: string;
  ownerId?: string | null;
  name: string;
  /** 10 digit Indian mobile without the country code, or null. */
  mobile: string | null;
  address: string | null;
  isActive: boolean;
  joinedOn: Date;
  /** Whether `salaryAmount` is a daily rate or a monthly wage. */
  salaryType: SalaryType;
  /** The configured wage in rupees, or null when no wage is on file. */
  salaryAmount: number | null;
  createdAt: Date | null;
}

export interface EmployeeRow {
  id: string;
  owner_id: string | null;
  name: string | null;
  mobile: string | null;
  address: string | null;
  is_active: boolean | null;
  joined_on: string | null;
  salary_type: string | null;
  salary_amount: number | string | null;
  created_at: string | null;
}

/** Postgres `numeric` can arrive as a number or a string; tolerate both. */
function toNumber(value: number | string | null | undefined): number | null {
  if (value == null) return null;
  const n = typeof value === 'number' ? value : Number(value);
  return Number.isFinite(n) ? n : null;
}

export function employeeFromRow(row: EmployeeRow): Employee {
  return {
    id: row.id,
    ownerId: row.owner_id,
    name: (row.name ?? '').trim(),
    mobile: row.mobile?.trim() || null,
    address: row.address?.trim() || null,
    isActive: row.is_active ?? true,
    joinedOn: AppDate.parseYmd(row.joined_on ?? ''),
    salaryType: salaryTypeFromDb(row.salary_type),
    salaryAmount: toNumber(row.salary_amount),
    createdAt: row.created_at ? new Date(row.created_at) : null,
  };
}

/** Payload for insert/update. `id`, `owner_id`, `created_at` are repo-handled. */
export function employeeToRow(e: Omit<Employee, 'id' | 'createdAt' | 'ownerId'>) {
  return {
    name: e.name.trim(),
    mobile: hasMobile(e.mobile) ? e.mobile!.trim() : null,
    address: e.address?.trim() || null,
    is_active: e.isActive,
    joined_on: AppDate.ymd(e.joinedOn),
    salary_type: e.salaryType,
    salary_amount: e.salaryAmount,
  };
}

/** True when a usable wage has been entered. */
export function hasSalary(e: Employee): boolean {
  return (e.salaryAmount ?? 0) > 0;
}

/** The daily rate in rupees, derived from a monthly wage when needed. */
export function perDaySalary(e: Employee): number {
  const amount = e.salaryAmount ?? 0;
  return e.salaryType === 'monthly' ? amount / DAYS_IN_SALARY_MONTH : amount;
}

/** The monthly wage in rupees, derived from a daily rate when needed. */
export function monthlySalary(e: Employee): number {
  const amount = e.salaryAmount ?? 0;
  return e.salaryType === 'monthly' ? amount : amount * DAYS_IN_SALARY_MONTH;
}

/** What one day of `status` is worth at this employee's rate, before override. */
export function defaultAmountFor(e: Employee, status: StatusKey): number {
  return perDaySalary(e) * STATUS[status].dayValue;
}

export function hasMobile(mobile: string | null | undefined): boolean {
  return (mobile ?? '').trim().length === 10;
}

/** `+91 98765 43210` */
export function displayMobile(mobile: string | null | undefined): string {
  if (!hasMobile(mobile)) return '';
  const m = mobile!.trim();
  return `+91 ${m.slice(0, 5)} ${m.slice(5)}`;
}

/** Employees are not expected to be marked before they joined. */
export function wasEmployedOn(employee: Employee, day: Date): boolean {
  return AppDate.dateOnly(day).getTime() >= AppDate.dateOnly(employee.joinedOn).getTime();
}

/* -------------------------------------------------------------------------
   AttendanceRecord
   ------------------------------------------------------------------------- */

export interface AttendanceRecord {
  id?: string | null;
  ownerId?: string | null;
  employeeId: string;
  /** Local calendar date. Serialised as `YYYY-MM-DD`, never as a timestamp. */
  day: Date;
  status: StatusKey;
  note: string | null;
  /** Manual pay override in rupees, or null to derive it from the daily rate. */
  amount: number | null;
  markedAt: Date | null;
}

export interface AttendanceRow {
  id: string | null;
  owner_id: string | null;
  employee_id: string;
  day: string | null;
  status: string | null;
  note: string | null;
  amount: number | string | null;
  marked_at: string | null;
}

export function attendanceFromRow(row: AttendanceRow): AttendanceRecord {
  return {
    id: row.id,
    ownerId: row.owner_id,
    employeeId: row.employee_id,
    day: AppDate.parseYmd(row.day ?? ''),
    status: statusFromDb(row.status),
    note: row.note?.trim() || null,
    amount: toNumber(row.amount),
    markedAt: row.marked_at ? new Date(row.marked_at) : null,
  };
}

/** Upsert payload. `owner_id` is added by the repository from the session. */
export function attendanceToRow(r: AttendanceRecord) {
  return {
    employee_id: r.employeeId,
    day: AppDate.ymd(r.day),
    status: r.status,
    note: r.note?.trim() || null,
    amount: r.amount ?? null,
  };
}

/**
 * The pay for one attendance record: its manual override, or the amount derived
 * from the employee's daily rate and this day's status.
 */
export function resolvedAmount(record: AttendanceRecord, employee: Employee): number {
  return record.amount ?? defaultAmountFor(employee, record.status);
}

export const dayKey = (r: AttendanceRecord): string => AppDate.ymd(r.day);

/* -------------------------------------------------------------------------
   Aggregates
   ------------------------------------------------------------------------- */

export interface DaySummary {
  totalActive: number;
  present: number;
  absent: number;
  halfDay: number;
  leave: number;
  lastMarkedAt: Date | null;
}

export const EMPTY_SUMMARY: DaySummary = {
  totalActive: 0, present: 0, absent: 0, halfDay: 0, leave: 0, lastMarkedAt: null,
};

/**
 * Counts `records`, ignoring any that belong to employees not in
 * `activeEmployeeIds` so deactivated staff never inflate today's numbers.
 */
export function summarise(
  records: Iterable<AttendanceRecord>,
  activeEmployeeIds: Set<string>,
): DaySummary {
  let present = 0, absent = 0, halfDay = 0, leave = 0;
  let lastMarkedAt: Date | null = null;

  for (const record of records) {
    if (!activeEmployeeIds.has(record.employeeId)) continue;
    if (record.status === 'present') present++;
    else if (record.status === 'absent') absent++;
    else if (record.status === 'half_day') halfDay++;
    else leave++;

    if (record.markedAt && (!lastMarkedAt || record.markedAt > lastMarkedAt)) {
      lastMarkedAt = record.markedAt;
    }
  }

  return { totalActive: activeEmployeeIds.size, present, absent, halfDay, leave, lastMarkedAt };
}

export const marked = (s: DaySummary): number => s.present + s.absent + s.halfDay + s.leave;

export function notMarked(s: DaySummary): number {
  return Math.min(Math.max(s.totalActive - marked(s), 0), s.totalActive);
}

export const isComplete = (s: DaySummary): boolean =>
  s.totalActive > 0 && notMarked(s) === 0;

/** One-line recap: "10 Present · 2 Absent · 1 Half Day". */
export function breakdown(s: DaySummary): string {
  const parts = [
    ...(s.present ? [`${s.present} Present`] : []),
    ...(s.absent ? [`${s.absent} Absent`] : []),
    ...(s.halfDay ? [`${s.halfDay} Half Day`] : []),
    ...(s.leave ? [`${s.leave} Leave`] : []),
  ];
  return parts.length === 0 ? 'Nothing marked yet' : parts.join(' · ');
}

/** Per-employee totals for a month. */
export interface MonthTotals {
  employeeId: string;
  present: number;
  absent: number;
  halfDay: number;
  leave: number;
}

export function totalsFor(
  employeeId: string,
  records: Iterable<AttendanceRecord>,
): MonthTotals {
  let present = 0, absent = 0, halfDay = 0, leave = 0;
  for (const r of records) {
    if (r.status === 'present') present++;
    else if (r.status === 'absent') absent++;
    else if (r.status === 'half_day') halfDay++;
    else leave++;
  }
  return { employeeId, present, absent, halfDay, leave };
}

export const totalMarked = (t: MonthTotals): number =>
  t.present + t.absent + t.halfDay + t.leave;

/** Present + half days counted as 0.5. */
export const payableDays = (t: MonthTotals): number => t.present + t.halfDay * 0.5;
