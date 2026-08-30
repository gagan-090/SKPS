import { AppDate } from '../lib/date';
import {
  type AttendanceRecord,
  type Employee,
  type MonthTotals,
  hasSalary,
  resolvedAmount,
  totalsFor,
} from '../types';

/** One employee's month: their records keyed by day-of-month, plus totals. */
export interface ReportRow {
  employee: Employee;
  byDay: Map<number, AttendanceRecord>;
  totals: MonthTotals;
  /** Total pay earned this month: overrides, or amounts from the daily rate. */
  salary: number;
  /** Whether this row has any pay information worth printing. */
  hasSalary: boolean;
  /** Days before joining render as `-`, not as an absence. */
  isBeforeJoining: (year: number, month: number, day: number) => boolean;
}

export interface ReportData {
  year: number;
  /** 1-based. */
  month: number;
  daysInMonth: number;
  rows: ReportRow[];
  label: string;
}

/** Grand total pay across every row. */
export function totalSalary(data: ReportData): number {
  return data.rows.reduce((sum, row) => sum + row.salary, 0);
}

/** True when any row has pay information to show. */
export function reportHasSalary(data: ReportData): boolean {
  return data.rows.some((row) => row.hasSalary);
}

export type ReportScope = 'active' | 'all' | string;

/** Shapes the raw rows into the matrix the report screen and exports render. */
export function buildReport(
  year: number,
  month: number,
  employees: Employee[],
  records: AttendanceRecord[],
): ReportData {
  const byEmployee = new Map<string, AttendanceRecord[]>();
  for (const record of records) {
    const list = byEmployee.get(record.employeeId);
    if (list) list.push(record);
    else byEmployee.set(record.employeeId, [record]);
  }

  const rows: ReportRow[] = employees.map((employee) => {
    const mine = byEmployee.get(employee.id) ?? [];
    const byDay = new Map<number, AttendanceRecord>();
    for (const record of mine) byDay.set(record.day.getDate(), record);

    const salary = mine.reduce((sum, r) => sum + resolvedAmount(r, employee), 0);

    return {
      employee,
      byDay,
      totals: totalsFor(employee.id, mine),
      salary,
      hasSalary: hasSalary(employee) || mine.some((r) => r.amount != null),
      isBeforeJoining: (y, m, d) =>
        new Date(y, m - 1, d).getTime() <
        AppDate.dateOnly(employee.joinedOn).getTime(),
    };
  });

  return {
    year,
    month,
    daysInMonth: AppDate.daysInMonth(year, month),
    rows,
    label: AppDate.monthYear(year, month),
  };
}
