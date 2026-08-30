import type { ReportData, ReportRow } from '../features/report';
import { AppDate } from './date';
import { round2 } from './money';
import { STATUS, hasMobile, hasSalary, perDaySalary, totalMarked } from '../types';

/**
 * Builds the monthly attendance CSV — a port of `csv_builder.dart`.
 *
 * Header: `Employee, Mobile, 1, 2, ... N, Present, Absent, Half Day, Leave`.
 */
export function buildCsv(data: ReportData): string {
  const rows: (string | number)[][] = [];

  rows.push([
    'Employee',
    'Mobile',
    ...Array.from({ length: data.daysInMonth }, (_, i) => i + 1),
    'Present',
    'Absent',
    'Half Day',
    'Leave',
    'Days Marked',
    'Per Day Rate',
    'Salary',
  ]);

  for (const row of data.rows) {
    rows.push([
      row.employee.name,
      hasMobile(row.employee.mobile) ? row.employee.mobile! : '',
      ...Array.from({ length: data.daysInMonth }, (_, i) => cell(data, row, i + 1)),
      row.totals.present,
      row.totals.absent,
      row.totals.halfDay,
      row.totals.leave,
      totalMarked(row.totals),
      hasSalary(row.employee) ? round2(perDaySalary(row.employee)) : '',
      row.hasSalary ? round2(row.salary) : '',
    ]);
  }

  // The BOM is the only way Excel on Windows reliably detects UTF-8.
  return '\uFEFF' + rows.map((r) => r.map(escape).join(',')).join('\r\n');
}

function cell(data: ReportData, row: ReportRow, day: number): string {
  const record = row.byDay.get(day);
  if (record) return STATUS[record.status].shortCode;
  // Before joining is not an absence.
  return row.isBeforeJoining(data.year, data.month, day) ? '-' : '';
}

function escape(value: string | number): string {
  const s = String(value);
  return /[",\r\n]/.test(s) ? `"${s.replace(/"/g, '""')}"` : s;
}

/** `Attendance_August_2026.csv` */
export function csvFileName(data: ReportData, employeeName?: string): string {
  const month = AppDate.monthYear(data.year, data.month).replace(/ /g, '_');
  const who = employeeName ? `_${slug(employeeName)}` : '';
  return `Attendance_${month}${who}.csv`;
}

const slug = (value: string): string =>
  value
    .trim()
    .replace(/[^A-Za-z0-9]+/g, '_')
    .replace(/_+/g, '_')
    .replace(/^_|_$/g, '');

/** Hands the file to the browser's download flow. */
export function downloadFile(filename: string, content: BlobPart, type: string): void {
  const url = URL.createObjectURL(new Blob([content], { type }));
  const link = document.createElement('a');
  link.href = url;
  link.download = filename;
  document.body.appendChild(link);
  link.click();
  link.remove();
  // Revoke on the next tick so Safari has finished reading the blob.
  setTimeout(() => URL.revokeObjectURL(url), 1000);
}
