import { useEffect, useMemo, useState } from 'react';
import { Link } from 'react-router-dom';

import {
  Avatar,
  Banner,
  Button,
  EmptyState,
  Loading,
  StatusSelector,
} from '../components/ui';
import { useToast } from '../context/ToastContext';
import { attendanceRepo } from '../data/attendance';
import { employeeRepo } from '../data/employees';
import { useAsync } from '../hooks/useAsync';
import { AppDate } from '../lib/date';
import {
  type AttendanceRecord,
  type Employee,
  type StatusKey,
  STATUS,
  wasEmployedOn,
} from '../types';

interface Draft {
  status: StatusKey | null;
  note: string;
}

/**
 * One row per active employee, and a single batched save at the end — never one
 * request per row.
 */
export default function MarkAttendance() {
  const { notify, notifyError } = useToast();

  const [day, setDay] = useState(() => AppDate.ymd(AppDate.today()));
  const date = useMemo(() => AppDate.parseYmd(day), [day]);

  const [drafts, setDrafts] = useState<Map<string, Draft>>(new Map());
  const [saving, setSaving] = useState(false);
  const [expandedNote, setExpandedNote] = useState<string | null>(null);

  const { data, loading, error, reload } = useAsync<{
    employees: Employee[];
    records: AttendanceRecord[];
  }>(async () => {
    const [employees, records] = await Promise.all([
      employeeRepo.fetchActive(),
      attendanceRepo.fetchForDay(date),
    ]);
    return { employees, records };
  }, [day]);

  // Seed the form from what is already saved for this day.
  useEffect(() => {
    if (!data) return;
    const byEmployee = new Map(data.records.map((r) => [r.employeeId, r]));
    const next = new Map<string, Draft>();
    for (const employee of data.employees) {
      const existing = byEmployee.get(employee.id);
      next.set(employee.id, {
        status: existing?.status ?? null,
        note: existing?.note ?? '',
      });
    }
    setDrafts(next);
  }, [data]);

  const eligible = useMemo(
    () => (data?.employees ?? []).filter((e) => wasEmployedOn(e, date)),
    [data, date],
  );

  const filled = useMemo(
    () => eligible.filter((e) => drafts.get(e.id)?.status != null).length,
    [eligible, drafts],
  );

  function update(employeeId: string, patch: Partial<Draft>) {
    setDrafts((current) => {
      const next = new Map(current);
      const existing = next.get(employeeId) ?? { status: null, note: '' };
      next.set(employeeId, { ...existing, ...patch });
      return next;
    });
  }

  function markAllPresent() {
    setDrafts((current) => {
      const next = new Map(current);
      for (const employee of eligible) {
        const existing = next.get(employee.id) ?? { status: null, note: '' };
        next.set(employee.id, { ...existing, status: 'present' });
      }
      return next;
    });
  }

  async function save() {
    const records: AttendanceRecord[] = [];
    for (const employee of eligible) {
      const draft = drafts.get(employee.id);
      if (!draft?.status) continue;
      records.push({
        employeeId: employee.id,
        day: date,
        status: draft.status,
        note: draft.note.trim() || null,
        markedAt: null,
      });
    }

    if (records.length === 0) {
      notifyError(new Error('Pick a status for at least one person first.'));
      return;
    }

    setSaving(true);
    try {
      await attendanceRepo.upsertMany(records);
      notify(`Saved ${records.length} ${records.length === 1 ? 'entry' : 'entries'}`);
      reload();
    } catch (err) {
      notifyError(err);
    } finally {
      setSaving(false);
    }
  }

  return (
    <main className="page">
      <div className="page__head">
        <div>
          <h1>Mark Attendance</h1>
          <div className="page__sub">{AppDate.displayLong(date)}</div>
        </div>
        <div className="row row--wrap">
          <input
            className="input"
            type="date"
            style={{ width: 'auto' }}
            value={day}
            max={AppDate.ymd(AppDate.today())}
            onChange={(e) => e.target.value && setDay(e.target.value)}
          />
          <Button variant="ghost" onClick={markAllPresent} disabled={eligible.length === 0}>
            Mark all present
          </Button>
          <Button onClick={save} loading={saving} disabled={eligible.length === 0}>
            Save {filled > 0 ? `(${filled})` : ''}
          </Button>
        </div>
      </div>

      {error && <Banner kind="error">{error}</Banner>}

      {loading && !data ? (
        <Loading rows={5} />
      ) : eligible.length === 0 ? (
        <div className="card">
          <EmptyState
            icon="👥"
            title="Nobody to mark"
            body={
              (data?.employees.length ?? 0) === 0
                ? 'Add active employees before marking attendance.'
                : 'Nobody on the roster had joined by this date.'
            }
            action={
              <Link to="/employees" className="btn">
                Go to employees
              </Link>
            }
          />
        </div>
      ) : (
        <div className="stack">
          <Banner kind={filled === eligible.length ? 'ok' : 'info'}>
            {filled} of {eligible.length} marked · unmarked rows are skipped on save
          </Banner>

          <div className="card list">
            {eligible.map((employee) => {
              const draft = drafts.get(employee.id) ?? { status: null, note: '' };
              const noteOpen = expandedNote === employee.id || draft.note.length > 0;

              return (
                <div key={employee.id} className="list__row" style={{ flexWrap: 'wrap' }}>
                  <Avatar name={employee.name} size="sm" />

                  <div className="grow">
                    <div className="list__title truncate">{employee.name}</div>
                    <div className="list__meta">
                      {draft.status ? STATUS[draft.status].label : 'Not marked'}
                    </div>
                  </div>

                  <StatusSelector
                    value={draft.status}
                    onChange={(status) => update(employee.id, { status })}
                    onClear={
                      draft.status ? () => update(employee.id, { status: null }) : undefined
                    }
                  />

                  <Button
                    variant="quiet"
                    size="sm"
                    onClick={() =>
                      setExpandedNote(expandedNote === employee.id ? null : employee.id)
                    }
                  >
                    {draft.note ? 'Note •' : 'Note'}
                  </Button>

                  {noteOpen && (
                    <input
                      className="input"
                      style={{ flexBasis: '100%' }}
                      placeholder="Note for this day (optional)"
                      value={draft.note}
                      onChange={(e) => update(employee.id, { note: e.target.value })}
                    />
                  )}
                </div>
              );
            })}
          </div>

          <div className="row" style={{ justifyContent: 'flex-end' }}>
            <Button onClick={save} loading={saving}>
              Save attendance
            </Button>
          </div>
        </div>
      )}
    </main>
  );
}
