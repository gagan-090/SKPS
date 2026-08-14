import { useMemo } from 'react';
import { Link } from 'react-router-dom';

import { Banner, Button, EmptyState, Loading } from '../components/ui';
import { attendanceRepo } from '../data/attendance';
import { employeeRepo } from '../data/employees';
import { useAsync } from '../hooks/useAsync';
import { StatusColor } from '../lib/colors';
import { AppDate } from '../lib/date';
import {
  type Employee,
  type AttendanceRecord,
  breakdown,
  isComplete,
  marked,
  notMarked,
  summarise,
  totalsFor,
  payableDays,
  STATUS,
} from '../types';

interface DashboardData {
  employees: Employee[];
  today: AttendanceRecord[];
  month: AttendanceRecord[];
}

export default function Dashboard() {
  const today = useMemo(() => AppDate.today(), []);

  const { data, loading, error, reload } = useAsync<DashboardData>(async () => {
    const [employees, todayRecords, monthRecords] = await Promise.all([
      employeeRepo.fetchAll(),
      attendanceRepo.fetchForDay(today),
      attendanceRepo.fetchForMonth(today.getFullYear(), today.getMonth() + 1),
    ]);
    return { employees, today: todayRecords, month: monthRecords };
  }, [today.getTime()]);

  const active = useMemo(
    () => (data?.employees ?? []).filter((e) => e.isActive),
    [data],
  );

  const summary = useMemo(
    () => summarise(data?.today ?? [], new Set(active.map((e) => e.id))),
    [data, active],
  );

  const monthByEmployee = useMemo(() => {
    const map = new Map<string, AttendanceRecord[]>();
    for (const record of data?.month ?? []) {
      const list = map.get(record.employeeId);
      if (list) list.push(record);
      else map.set(record.employeeId, [record]);
    }
    return map;
  }, [data]);

  return (
    <main className="page">
      <div className="page__head">
        <div>
          <h1>{AppDate.relativeLabel(today)}</h1>
          <div className="page__sub">{AppDate.displayLong(today)}</div>
        </div>
        <div className="row">
          <Button variant="ghost" onClick={reload} disabled={loading}>
            Refresh
          </Button>
          <Link to="/mark" className="btn">
            {marked(summary) > 0 ? 'Edit attendance' : 'Mark attendance'}
          </Link>
        </div>
      </div>

      {error && <Banner kind="error">{error}</Banner>}

      {loading && !data ? (
        <Loading rows={4} />
      ) : (
        <div className="stack">
          <Banner kind={isComplete(summary) ? 'ok' : 'info'}>
            {active.length === 0
              ? 'No active employees yet — add someone on the Employees page.'
              : isComplete(summary)
                ? `All ${summary.totalActive} marked for today · ${breakdown(summary)}`
                : `${breakdown(summary)} · ${notMarked(summary)} still not marked`}
            {summary.lastMarkedAt && (
              <span className="muted small nowrap">
                {' '}
                (last saved {AppDate.time(summary.lastMarkedAt)})
              </span>
            )}
          </Banner>

          <div className="tiles">
            <Tile label="Employees" value={summary.totalActive} color={StatusColor.notMarked} />
            <Tile label="Present" value={summary.present} color={STATUS.present.color} />
            <Tile label="Absent" value={summary.absent} color={STATUS.absent.color} />
            <Tile label="Not Marked" value={notMarked(summary)} color={StatusColor.notMarked} />
          </div>

          <section className="card">
            <div className="card__head">
              <h2>{AppDate.monthYear(today.getFullYear(), today.getMonth() + 1)}</h2>
              <Link to="/reports" className="small">
                Full report →
              </Link>
            </div>

            {active.length === 0 ? (
              <EmptyState
                icon="👥"
                title="No employees yet"
                body="Add your staff to start marking attendance."
                action={
                  <Link to="/employees" className="btn">
                    Add employee
                  </Link>
                }
              />
            ) : (
              <div className="list">
                {active.map((employee) => {
                  const totals = totalsFor(
                    employee.id,
                    monthByEmployee.get(employee.id) ?? [],
                  );
                  return (
                    <Link
                      key={employee.id}
                      to={`/employees/${employee.id}`}
                      className="list__row list__row--link"
                    >
                      <div className="grow">
                        <div className="list__title truncate">{employee.name}</div>
                        <div className="list__meta">
                          {totals.present}P · {totals.absent}A · {totals.halfDay}H ·{' '}
                          {totals.leave}L
                        </div>
                      </div>
                      <div style={{ textAlign: 'right' }}>
                        <div className="tabnums" style={{ fontWeight: 700 }}>
                          {payableDays(totals)}
                        </div>
                        <div className="list__meta">days</div>
                      </div>
                    </Link>
                  );
                })}
              </div>
            )}
          </section>
        </div>
      )}
    </main>
  );
}

function Tile({ label, value, color }: { label: string; value: number; color: string }) {
  return (
    <div className="tile">
      <div className="tile__value tabnums" style={{ color }}>
        {value}
      </div>
      <div className="tile__label">
        <span className="dot" style={{ background: color }} />
        {label}
      </div>
    </div>
  );
}
