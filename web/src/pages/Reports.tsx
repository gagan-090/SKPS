import { useMemo, useState } from 'react';

import MonthPicker from '../components/MonthPicker';
import { Banner, Button, EmptyState, Loading } from '../components/ui';
import { useSettings } from '../context/SettingsContext';
import { useToast } from '../context/ToastContext';
import { attendanceRepo } from '../data/attendance';
import { employeeRepo } from '../data/employees';
import { buildReport, type ReportScope } from '../features/report';
import { useAsync } from '../hooks/useAsync';
import { buildCsv, csvFileName, downloadFile } from '../lib/csv';
import { AppDate } from '../lib/date';
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
  const [scope, setScope] = useState<ReportScope>('active');
  const [building, setBuilding] = useState(false);

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

  const scoped = useMemo(() => {
    const all = data?.employees ?? [];
    if (scope === 'all') return all;
    if (scope === 'active') return all.filter((e) => e.isActive);
    return all.filter((e) => e.id === scope);
  }, [data, scope]);

  const report = useMemo(
    () => buildReport(year, month, scoped, data?.records ?? []),
    [year, month, scoped, data],
  );

  const singleName =
    scope !== 'all' && scope !== 'active' ? scoped[0]?.name : undefined;

  function exportCsv() {
    try {
      downloadFile(
        csvFileName(report, singleName),
        buildCsv(report),
        'text/csv;charset=utf-8',
      );
      notify('CSV downloaded');
    } catch (err) {
      notifyError(err);
    }
  }

  // jsPDF is ~700 kB, so it is loaded on demand rather than on every page view.
  async function exportPdf() {
    setBuilding(true);
    try {
      const { buildPdf, pdfFileName } = await import('../lib/pdf');
      buildPdf(report, businessName).save(pdfFileName(report, singleName));
      notify('PDF downloaded');
    } catch (err) {
      notifyError(err);
    } finally {
      setBuilding(false);
    }
  }

  async function printPdf() {
    // The tab has to be opened synchronously inside the click handler: once we
    // await the dynamic import the user-gesture context is gone and popup
    // blockers reject window.open outright.
    const tab = window.open('', '_blank');
    setBuilding(true);
    try {
      const { buildPdf } = await import('../lib/pdf');
      const doc = buildPdf(report, businessName);
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
          <select
            className="select"
            style={{ width: 'auto' }}
            value={scope}
            onChange={(e) => setScope(e.target.value)}
          >
            <option value="active">Active employees</option>
            <option value="all">All employees</option>
            {(data?.employees ?? []).map((employee) => (
              <option key={employee.id} value={employee.id}>
                {employee.name}
              </option>
            ))}
          </select>
        </div>

        {loading && !data ? (
          <Loading rows={6} />
        ) : !hasRows ? (
          <div className="card">
            <EmptyState
              icon="📄"
              title="Nothing to report"
              body="No employees match this scope for the selected month."
            />
          </div>
        ) : (
          <section className="card">
            <div className="card__head">
              <h2>{report.label}</h2>
              <span className="muted small">
                {report.rows.length}{' '}
                {report.rows.length === 1 ? 'employee' : 'employees'}
              </span>
            </div>

            <div className="matrix-wrap">
              <table className="matrix">
                <thead>
                  <tr>
                    <th className="col-name">Employee</th>
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
                  </tr>
                </thead>
                <tbody>
                  {report.rows.map((row) => (
                    <tr key={row.employee.id}>
                      <td className="col-name">
                        <div className="truncate">{row.employee.name}</div>
                        <div className="list__meta">
                          {payableDays(row.totals)} payable
                        </div>
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
                                title={`${STATUS[record.status].label}${record.note ? ` — ${record.note}` : ''}`}
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
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>

            <div className="row row--wrap" style={{ padding: 'var(--sp-4) var(--sp-5)' }}>
              {Object.values(STATUS).map((meta) => (
                <span key={meta.dbValue} className="pill" style={{ color: meta.color }}>
                  <span className="dot" style={{ background: meta.color }} />
                  {meta.shortCode} — {meta.label}
                </span>
              ))}
              <span className="muted small">“–” = before joining</span>
            </div>
          </section>
        )}
      </div>
    </main>
  );
}
