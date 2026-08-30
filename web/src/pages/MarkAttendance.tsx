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
import { formatINR, round2 } from '../lib/money';
import {
  type AttendanceRecord,
  type Employee,
  type StatusKey,
  STATUS,
  defaultAmountFor,
  hasSalary,
  perDaySalary,
  wasEmployedOn,
} from '../types';

interface Draft {
  status: StatusKey | null;
  note: string;
  /** Raw text of the pay for the day, pre-filled from the rate then editable. */
  amount: string;
  /** True once the owner typed the amount, so it is not re-derived on status change. */
  amountManual: boolean;
}

function parseAmount(text: string): number | null {
  const t = text.trim();
  if (t === '') return null;
  const n = Number(t);
  return Number.isFinite(n) && n >= 0 ? n : null;
}

/** The pay to pre-fill for a status at the employee's rate, or null when zero. */
function defaultPay(employee: Employee, status: StatusKey): number | null {
  if (!hasSalary(employee)) return null;
  const value = defaultAmountFor(employee, status);
  return value > 0 ? round2(value) : null;
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
      const status = existing?.status ?? null;
      const manual = existing?.amount != null;
      const amount = manual
        ? String(existing!.amount)
        : status
          ? (defaultPay(employee, status)?.toString() ?? '')
          : '';
      next.set(employee.id, {
        status,
        note: existing?.note ?? '',
        amount,
        amountManual: manual,
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
      const existing = next.get(employeeId) ?? { status: null, note: '', amount: '', amountManual: false };
      next.set(employeeId, { ...existing, ...patch });
      return next;
    });
  }

  /** Picks a status and auto-fills the pay from the rate, unless set by hand. */
  function pickStatus(employee: Employee, status: StatusKey) {
    setDrafts((current) => {
      const next = new Map(current);
      const d = next.get(employee.id) ?? {
        status: null,
        note: '',
        amount: '',
        amountManual: false,
      };
      const amount = d.amountManual
        ? d.amount
        : (defaultPay(employee, status)?.toString() ?? '');
      next.set(employee.id, { ...d, status, amount });
      return next;
    });
  }

  function markAllPresent() {
    setDrafts((current) => {
      const next = new Map(current);
      for (const employee of eligible) {
        const existing = next.get(employee.id) ?? {
          status: null,
          note: '',
          amount: '',
          amountManual: false,
        };
        const amount = existing.amountManual
          ? existing.amount
          : (defaultPay(employee, 'present')?.toString() ?? '');
        next.set(employee.id, { ...existing, status: 'present', amount });
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
        amount: parseAmount(draft.amount),
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
              const draft = drafts.get(employee.id) ?? { status: null, note: '', amount: '', amountManual: false };
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
                    onChange={(status) => pickStatus(employee, status)}
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

                  {draft.status && (
                    <label
                      className="row"
                      style={{ flexBasis: '100%', gap: 8, marginTop: 4 }}
                    >
                      <span className="field__label" style={{ minWidth: 60 }}>
                        ₹ Amount
                      </span>
                      <input
                        className="input"
                        style={{ maxWidth: 140 }}
                        inputMode="decimal"
                        placeholder={
                          hasSalary(employee)
                            ? String(round2(defaultAmountFor(employee, draft.status)))
                            : 'Optional'
                        }
                        value={draft.amount}
                        onChange={(e) =>
                          update(employee.id, {
                            amount: e.target.value.replace(/[^0-9.]/g, ''),
                            amountManual: true,
                          })
                        }
                      />
                      {hasSalary(employee) && (
                        <span className="field__hint">
                          from {formatINR(perDaySalary(employee))}/day
                        </span>
                      )}
                    </label>
                  )}

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
