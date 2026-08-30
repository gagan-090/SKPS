import { useEffect, useMemo, useRef, useState } from 'react';

import MonthPicker from '../components/MonthPicker';
import { Banner, Button, EmptyState, Loading } from '../components/ui';
import { useSettings } from '../context/SettingsContext';
import { useToast } from '../context/ToastContext';
import { attendanceRepo } from '../data/attendance';
import { employeeRepo } from '../data/employees';
import {
  buildReport,
  reportHasSalary,
  totalSalary,
  type ReportData,
} from '../features/report';
import { useAsync } from '../hooks/useAsync';
import { buildCsv, csvFileName, downloadFile } from '../lib/csv';
import { AppDate } from '../lib/date';
import { formatINR } from '../lib/money';
import {
  type AttendanceRecord,
  type Employee,
  STATUS,
  payableDays,
  totalMarked,
} from '../types';

export default function Reports() {
  const { businessName } = useSettings();
  const { notify, notifyError } = useToast();

  const now = useMemo(() => AppDate.today(), []);
  const [year, setYear] = useState(now.getFullYear());
  const [month, setMonth] = useState(now.getMonth() + 1);
  const [building, setBuilding] = useState(false);

  // Ids ticked for export. null means "everyone in the report".
  const [selectedIds, setSelectedIds] = useState<Set<string> | null>(null);
  // A new month has a fresh roster; start with everyone ticked again.
  useEffect(() => setSelectedIds(null), [year, month]);

  const { data, loading, error } = useAsync<{
    employees: Employee[];
    records: AttendanceRecord[];
  }>(async () => {
    const [employees, records] = await Promise.all([
      employeeRepo.fetchAll(),
      attendanceRepo.fetchForMonth(year, month),
    ]);
    return { employees, records };
  }, [year, month]);

  // Everyone active who had joined by month end, plus anyone (even deactivated)
  // with a record that month — history must not vanish from a past report.
  const included = useMemo(() => {
    const employees = data?.employees ?? [];
    const records = data?.records ?? [];
    const withRecords = new Set(records.map((r) => r.employeeId));
    const { last } = AppDate.monthRange(year, month);
    return employees.filter(
      (e) =>
        withRecords.has(e.id) ||
        (e.isActive && AppDate.dateOnly(e.joinedOn).getTime() <= last.getTime()),
    );
  }, [data, year, month]);

  const report = useMemo(
    () => buildReport(year, month, included, data?.records ?? []),
    [year, month, included, data],
  );

  const allIds = useMemo(() => report.rows.map((r) => r.employee.id), [report]);
  const selection = useMemo(
    () => selectedIds ?? new Set(allIds),
    [selectedIds, allIds],
  );
  const selectedCount = allIds.filter((id) => selection.has(id)).length;
  const allSelected = allIds.length > 0 && selectedCount === allIds.length;

  // The header tickbox shows a dash when only some rows are ticked.
  const headerRef = useRef<HTMLInputElement>(null);
  useEffect(() => {
    if (headerRef.current) {
      headerRef.current.indeterminate = selectedCount > 0 && !allSelected;
    }
  }, [selectedCount, allSelected]);

  function toggle(id: string) {
    const next = new Set(selection);
    if (next.has(id)) next.delete(id);
    else next.add(id);
    setSelectedIds(next);
  }

  function toggleAll() {
    setSelectedIds(allSelected ? new Set<string>() : null);
  }

  /** The report narrowed to the ticked employees. */
  function subset(): ReportData {
    return { ...report, rows: report.rows.filter((r) => selection.has(r.employee.id)) };
  }

  /** A single ticked employee names the export file; a subset stays generic. */
  function exportName(): string | undefined {
    const rows = report.rows.filter((r) => selection.has(r.employee.id));
    return rows.length === 1 ? rows[0].employee.name : undefined;
  }

  function exportCsv() {
    if (selectedCount === 0) {
      notifyError(new Error('Tick at least one employee to export.'));
      return;
    }
    try {
      const chosen = subset();
      downloadFile(
        csvFileName(chosen, exportName()),
        buildCsv(chosen),
        'text/csv;charset=utf-8',
      );
      notify('CSV downloaded');
    } catch (err) {
      notifyError(err);
    }
  }

  // jsPDF is ~700 kB, so it is loaded on demand rather than on every page view.
  async function exportPdf() {
    if (selectedCount === 0) {
      notifyError(new Error('Tick at least one employee to export.'));
      return;
    }
    setBuilding(true);
    try {
      const chosen = subset();
      const { buildPdf, pdfFileName } = await import('../lib/pdf');
      buildPdf(chosen, businessName).save(pdfFileName(chosen, exportName()));
      notify('PDF downloaded');
    } catch (err) {
      notifyError(err);
    } finally {
      setBuilding(false);
    }
  }

  async function printPdf() {
    if (selectedCount === 0) {
      notifyError(new Error('Tick at least one employee to export.'));
      return;
    }
    // The tab has to be opened synchronously inside the click handler: once we
    // await the dynamic import the user-gesture context is gone and popup
    // blockers reject window.open outright.
    const tab = window.open('', '_blank');
    setBuilding(true);
    try {
      const { buildPdf } = await import('../lib/pdf');
      const doc = buildPdf(subset(), businessName);
      doc.autoPrint();
      // Opening the blob in a tab is the only reliable cross-browser print.
      const url = doc.output('bloburl') as unknown as string;
      if (tab) tab.location.href = url;
      else window.open(url, '_blank');
    } catch (err) {
      tab?.close();
      notifyError(err);
    } finally {
      setBuilding(false);
    }
  }

  const days = Array.from({ length: report.daysInMonth }, (_, i) => i + 1);
  const hasRows = report.rows.length > 0;
  const showSalary = reportHasSalary(report);

  const sums = report.rows.reduce(
    (acc, r) => ({
      present: acc.present + r.totals.present,
      absent: acc.absent + r.totals.absent,
      halfDay: acc.halfDay + r.totals.halfDay,
      leave: acc.leave + r.totals.leave,
      days: acc.days + totalMarked(r.totals),
    }),
    { present: 0, absent: 0, halfDay: 0, leave: 0, days: 0 },
  );

  return (
    <main className="page">
      <div className="page__head">
        <div>
          <h1>Reports</h1>
          <div className="page__sub">{businessName}</div>
        </div>
        <div className="row row--wrap no-print">
          <Button variant="ghost" onClick={exportCsv} disabled={!hasRows}>
            CSV
          </Button>
          <Button variant="ghost" onClick={exportPdf} disabled={!hasRows} loading={building}>
            PDF
          </Button>
          <Button onClick={printPdf} disabled={!hasRows || building}>
            Print
          </Button>
        </div>
      </div>

      {error && <Banner kind="error">{error}</Banner>}

      <div className="stack">
        <div className="row row--wrap no-print">
          <MonthPicker
            year={year}
            month={month}
            onChange={(y, m) => {
              setYear(y);
              setMonth(m);
            }}
          />
          {hasRows && (
            <span className="muted small">
              {selectedCount} of {allIds.length} ticked for export
            </span>
          )}
        </div>

        {loading && !data ? (
          <Loading rows={6} />
        ) : !hasRows ? (
          <div className="card">
            <EmptyState
              icon="📄"
              title="Nothing to report"
              body="No employees match this month yet."
            />
          </div>
        ) : (
          <section className="card">
            <div className="card__head">
              <h2>{report.label}</h2>
              <span className="muted small">
                {report.rows.length}{' '}
                {report.rows.length === 1 ? 'employee' : 'employees'}
                {showSalary && ` · total pay ${formatINR(totalSalary(report))}`}
              </span>
            </div>

            <div className="matrix-wrap">
              <table className="matrix">
                <thead>
                  <tr>
                    <th className="col-name">
                      <label className="row" style={{ gap: 6, cursor: 'pointer' }}>
                        <input
                          ref={headerRef}
                          type="checkbox"
                          checked={allSelected}
                          onChange={toggleAll}
                          title="Tick / untick everyone"
                        />
                        Employee
                      </label>
                    </th>
                    {days.map((day) => (
                      <th
                        key={day}
                        className={
                          AppDate.isWeekend(new Date(year, month - 1, day)) ? 'wknd' : ''
                        }
                      >
                        {day}
                      </th>
                    ))}
                    <th>P</th>
                    <th>A</th>
                    <th>H</th>
                    <th>L</th>
                    <th>Days</th>
                    <th>Salary</th>
                  </tr>
                </thead>
                <tbody>
                  {report.rows.map((row) => (
                    <tr key={row.employee.id}>
                      <td className="col-name">
                        <label className="row" style={{ gap: 6, cursor: 'pointer' }}>
                          <input
                            type="checkbox"
                            checked={selection.has(row.employee.id)}
                            onChange={() => toggle(row.employee.id)}
                          />
                          <span className="grow" style={{ minWidth: 0 }}>
                            <span className="truncate" style={{ display: 'block' }}>
                              {row.employee.name}
                            </span>
                            <span className="list__meta">
                              {payableDays(row.totals)} payable
                            </span>
                          </span>
                        </label>
                      </td>

                      {days.map((day) => {
                        const record = row.byDay.get(day);
                        const before = row.isBeforeJoining(year, month, day);
                        const weekend = AppDate.isWeekend(new Date(year, month - 1, day));
                        return (
                          <td key={day} className={weekend ? 'wknd' : ''}>
                            {record ? (
                              <span
                                className="cellcode"
                                style={{ background: STATUS[record.status].color }}
                                title={`${STATUS[record.status].label}${record.note ? ` — ${record.note}` : ''}${record.amount != null ? ` · ${formatINR(record.amount)}` : ''}`}
                              >
                                {STATUS[record.status].shortCode}
                              </span>
                            ) : before ? (
                              <span className="muted">–</span>
                            ) : (
                              ''
                            )}
                          </td>
                        );
                      })}

                      <td className="num" style={{ color: STATUS.present.color }}>
                        {row.totals.present}
                      </td>
                      <td className="num" style={{ color: STATUS.absent.color }}>
                        {row.totals.absent}
                      </td>
                      <td className="num" style={{ color: STATUS.half_day.color }}>
                        {row.totals.halfDay}
                      </td>
                      <td className="num" style={{ color: STATUS.leave.color }}>
                        {row.totals.leave}
                      </td>
                      <td className="num">{totalMarked(row.totals)}</td>
                      <td className="num">
                        {row.hasSalary ? formatINR(row.salary) : '—'}
                      </td>
                    </tr>
                  ))}
                </tbody>
                <tfoot>
                  <tr>
                    <td className="col-name" style={{ fontWeight: 700 }}>
                      Total
                    </td>
                    <td colSpan={report.daysInMonth} />
                    <td className="num">{sums.present}</td>
                    <td className="num">{sums.absent}</td>
                    <td className="num">{sums.halfDay}</td>
                    <td className="num">{sums.leave}</td>
                    <td className="num">{sums.days}</td>
                    <td className="num" style={{ fontWeight: 700 }}>
                      {showSalary ? formatINR(totalSalary(report)) : '—'}
                    </td>
                  </tr>
                </tfoot>
              </table>
            </div>

            <div className="row row--wrap" style={{ padding: 'var(--sp-4) var(--sp-5)' }}>
              {Object.values(STATUS).map((meta) => (
                <span key={meta.dbValue} className="pill" style={{ color: meta.color }}>
                  <span className="dot" style={{ background: meta.color }} />
                  {meta.shortCode} — {meta.label}
                </span>
              ))}
              <span className="muted small">“–” = before joining · tick a name to include it in the export</span>
            </div>
          </section>
        )}
      </div>
    </main>
  );
}
