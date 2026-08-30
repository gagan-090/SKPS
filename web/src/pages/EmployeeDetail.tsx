import { useMemo, useState } from 'react';
import { Link, useParams } from 'react-router-dom';

import MonthCalendar from '../components/MonthCalendar';
import MonthPicker from '../components/MonthPicker';
import {
  Avatar,
  Banner,
  Button,
  Field,
  Loading,
  Modal,
  StatusSelector,
} from '../components/ui';
import { useToast } from '../context/ToastContext';
import { attendanceRepo } from '../data/attendance';
import { draftFrom, employeeRepo } from '../data/employees';
import { useAsync } from '../hooks/useAsync';
import { AppDate } from '../lib/date';
import { formatINR } from '../lib/money';
import {
  type AttendanceRecord,
  type Employee,
  type SalaryType,
  type StatusKey,
  DAYS_IN_SALARY_MONTH,
  STATUS,
  defaultAmountFor,
  displayMobile,
  hasMobile,
  hasSalary,
  monthlySalary,
  payableDays,
  perDaySalary,
  resolvedAmount,
  totalsFor,
} from '../types';

export default function EmployeeDetail() {
  const { id = '' } = useParams();
  const { notify, notifyError } = useToast();

  const now = useMemo(() => AppDate.today(), []);
  const [year, setYear] = useState(now.getFullYear());
  const [month, setMonth] = useState(now.getMonth() + 1);

  const [editingDay, setEditingDay] = useState<number | null>(null);
  const [note, setNote] = useState('');
  const [amount, setAmount] = useState('');
  const [busy, setBusy] = useState(false);

  const [editingSalary, setEditingSalary] = useState(false);
  const [salType, setSalType] = useState<SalaryType>('per_day');
  const [salAmount, setSalAmount] = useState('');
  const [savingSalary, setSavingSalary] = useState(false);

  const { data, loading, error, reload } = useAsync<{
    employee: Employee;
    records: AttendanceRecord[];
  }>(async () => {
    const [employee, records] = await Promise.all([
      employeeRepo.fetchById(id),
      attendanceRepo.fetchForMonth(year, month, id),
    ]);
    return { employee, records };
  }, [id, year, month]);

  const byDay = useMemo(() => {
    const map = new Map<number, AttendanceRecord>();
    for (const record of data?.records ?? []) map.set(record.day.getDate(), record);
    return map;
  }, [data]);

  const statusByDay = useMemo(() => {
    const map = new Map<number, StatusKey>();
    for (const [day, record] of byDay) map.set(day, record.status);
    return map;
  }, [byDay]);

  const totals = useMemo(
    () => totalsFor(id, data?.records ?? []),
    [id, data],
  );

  const monthSalary = useMemo(() => {
    if (!data) return 0;
    return (data.records ?? []).reduce(
      (sum, record) => sum + resolvedAmount(record, data.employee),
      0,
    );
  }, [data]);

  function openDay(day: number) {
    const record = byDay.get(day);
    setEditingDay(day);
    setNote(record?.note ?? '');
    setAmount(record?.amount != null ? String(record.amount) : '');
  }

  async function setStatus(status: StatusKey) {
    if (editingDay == null || !data) return;
    const parsed = amount.trim() === '' ? null : Number(amount);
    setBusy(true);
    try {
      await attendanceRepo.upsertOne({
        employeeId: data.employee.id,
        day: new Date(year, month - 1, editingDay),
        status,
        note: note.trim() || null,
        amount: parsed != null && Number.isFinite(parsed) && parsed >= 0 ? parsed : null,
        markedAt: null,
      });
      notify('Saved');
      setEditingDay(null);
      reload();
    } catch (err) {
      notifyError(err);
    } finally {
      setBusy(false);
    }
  }

  async function clearDay() {
    if (editingDay == null || !data) return;
    setBusy(true);
    try {
      await attendanceRepo.deleteFor(
        data.employee.id,
        new Date(year, month - 1, editingDay),
      );
      notify('Cleared');
      setEditingDay(null);
      reload();
    } catch (err) {
      notifyError(err);
    } finally {
      setBusy(false);
    }
  }

  function openSalary() {
    if (!data) return;
    setSalType(data.employee.salaryType);
    setSalAmount(
      data.employee.salaryAmount == null ? '' : String(data.employee.salaryAmount),
    );
    setEditingSalary(true);
  }

  async function persistSalary(nextAmount: number | null, nextType: SalaryType) {
    if (!data) return;
    setSavingSalary(true);
    try {
      await employeeRepo.update(data.employee.id, {
        ...draftFrom(data.employee),
        salaryType: nextType,
        salaryAmount: nextAmount,
      });
      notify(nextAmount == null ? 'Salary removed' : 'Salary saved');
      setEditingSalary(false);
      reload();
    } catch (err) {
      notifyError(err);
    } finally {
      setSavingSalary(false);
    }
  }

  function saveSalary() {
    const n = salAmount.trim() === '' ? null : Number(salAmount);
    const value = n != null && Number.isFinite(n) && n >= 0 ? n : null;
    persistSalary(value, salType);
  }

  const salNum = salAmount.trim() === '' ? null : Number(salAmount);
  const salRateHint =
    salNum && Number.isFinite(salNum) && salNum > 0
      ? salType === 'monthly'
        ? `≈ ${formatINR(salNum / DAYS_IN_SALARY_MONTH)} per day`
        : `≈ ${formatINR(salNum * DAYS_IN_SALARY_MONTH)} per month`
      : 'Leave blank to skip';

  if (loading && !data) {
    return (
      <main className="page">
        <Loading rows={4} />
      </main>
    );
  }

  if (error || !data) {
    return (
      <main className="page">
        <Banner kind="error">{error ?? 'Employee not found.'}</Banner>
        <div style={{ marginTop: 16 }}>
          <Link to="/employees" className="btn btn--ghost">
            ← Back to employees
          </Link>
        </div>
      </main>
    );
  }

  const { employee } = data;
  const existing = editingDay != null ? byDay.get(editingDay) : undefined;

  return (
    <main className="page">
      <div className="page__head">
        <div className="row">
          <Avatar name={employee.name} size="lg" />
          <div>
            <h1>{employee.name}</h1>
            <div className="page__sub">
              {hasMobile(employee.mobile) ? displayMobile(employee.mobile) : 'No mobile'} ·
              joined {AppDate.display(employee.joinedOn)}
              {!employee.isActive && ' · inactive'}
            </div>
            {employee.address && <div className="page__sub">{employee.address}</div>}
          </div>
        </div>

        <div className="row">
          {hasMobile(employee.mobile) && (
            <>
              <a className="btn btn--ghost" href={`tel:+91${employee.mobile}`}>
                Call
              </a>
              <a
                className="btn btn--ghost"
                href={`https://wa.me/91${employee.mobile}`}
                target="_blank"
                rel="noreferrer"
              >
                WhatsApp
              </a>
            </>
          )}
          <Link to="/employees" className="btn btn--quiet">
            ← Back
          </Link>
        </div>
      </div>

      <div className="stack">
        <div className="tiles">
          <MiniTile label="Present" value={totals.present} color={STATUS.present.color} />
          <MiniTile label="Absent" value={totals.absent} color={STATUS.absent.color} />
          <MiniTile label="Half Day" value={totals.halfDay} color={STATUS.half_day.color} />
          <MiniTile label="Leave" value={totals.leave} color={STATUS.leave.color} />
          <MiniTile label="Payable days" value={payableDays(totals)} color="var(--primary)" />
          {(hasSalary(employee) || monthSalary > 0) && (
            <MiniTile label="Salary" value={formatINR(monthSalary)} color="var(--primary)" />
          )}
        </div>

        <section className="card">
          <div className="card__head">
            <h2>Salary</h2>
            <Button variant="ghost" size="sm" onClick={openSalary}>
              {hasSalary(employee) ? 'Edit' : '+ Add salary'}
            </Button>
          </div>
          <div style={{ padding: 'var(--sp-4) var(--sp-5)' }}>
            {hasSalary(employee) ? (
              <div className="row" style={{ gap: 'var(--sp-4)', flexWrap: 'wrap' }}>
                <div className="tabnums" style={{ fontSize: '1.5rem', fontWeight: 700 }}>
                  {formatINR(perDaySalary(employee))}
                  <span className="muted small" style={{ fontWeight: 500 }}> / day</span>
                </div>
                <span className="muted small">
                  {employee.salaryType === 'monthly'
                    ? `${formatINR(monthlySalary(employee))} per month`
                    : `≈ ${formatINR(monthlySalary(employee))} per month`}
                </span>
              </div>
            ) : (
              <p className="small muted" style={{ margin: 0 }}>
                No salary set yet. Add a daily or monthly wage to see this person&apos;s pay
                in reports.
              </p>
            )}
          </div>
        </section>

        <section className="card">
          <div className="card__head">
            <h2>Attendance</h2>
            <MonthPicker
              year={year}
              month={month}
              onChange={(y, m) => {
                setYear(y);
                setMonth(m);
              }}
            />
          </div>

          <div style={{ padding: 'var(--sp-5)' }}>
            <MonthCalendar
              year={year}
              month={month}
              statusByDay={statusByDay}
              joinedOn={employee.joinedOn}
              onPick={openDay}
            />
            <div className="row row--wrap" style={{ marginTop: 16 }}>
              {Object.values(STATUS).map((meta) => (
                <span key={meta.dbValue} className="pill" style={{ color: meta.color }}>
                  <span className="dot" style={{ background: meta.color }} />
                  {meta.label}
                </span>
              ))}
            </div>
          </div>
        </section>
      </div>

      {editingDay != null && (
        <Modal
          title={AppDate.displayLong(new Date(year, month - 1, editingDay))}
          onClose={() => setEditingDay(null)}
          footer={
            <>
              {existing && (
                <Button variant="quiet" onClick={clearDay} disabled={busy}>
                  Clear
                </Button>
              )}
              <Button variant="ghost" onClick={() => setEditingDay(null)} disabled={busy}>
                Cancel
              </Button>
            </>
          }
        >
          <div className="stack" style={{ paddingBottom: 4 }}>
            <div>
              <div className="field__label" style={{ marginBottom: 6 }}>
                Status — tap to save
              </div>
              <StatusSelector value={existing?.status ?? null} onChange={setStatus} />
            </div>

            <label className="field">
              <span className="field__label">Amount (₹, optional)</span>
              <input
                className="input"
                inputMode="decimal"
                value={amount}
                onChange={(e) => setAmount(e.target.value.replace(/[^0-9.]/g, ''))}
                placeholder={
                  hasSalary(employee)
                    ? `Default ${formatINR(defaultAmountFor(employee, existing?.status ?? 'present'))}`
                    : 'Leave blank to skip'
                }
              />
              <span className="field__hint">
                Overrides the pay derived from the daily rate for this day.
              </span>
            </label>

            <label className="field">
              <span className="field__label">Note (optional)</span>
              <textarea
                className="textarea"
                value={note}
                onChange={(e) => setNote(e.target.value)}
                placeholder="Reason, half-day timing, etc."
              />
              <span className="field__hint">
                The note and amount are saved together with the status you pick above.
              </span>
            </label>
          </div>
        </Modal>
      )}

      {editingSalary && (
        <Modal
          title="Salary"
          onClose={() => setEditingSalary(false)}
          footer={
            <>
              {hasSalary(employee) && (
                <Button
                  variant="quiet"
                  onClick={() => persistSalary(null, employee.salaryType)}
                  disabled={savingSalary}
                >
                  Remove
                </Button>
              )}
              <Button
                variant="ghost"
                onClick={() => setEditingSalary(false)}
                disabled={savingSalary}
              >
                Cancel
              </Button>
              <Button onClick={saveSalary} loading={savingSalary}>
                Save
              </Button>
            </>
          }
        >
          <div className="stack" style={{ paddingBottom: 4 }}>
            <div className="field">
              <span className="field__label">Salary type</span>
              <div className="seg" role="group" aria-label="Salary type">
                {(['per_day', 'monthly'] as SalaryType[]).map((t) => (
                  <button
                    key={t}
                    type="button"
                    aria-pressed={salType === t}
                    className={`seg__btn${salType === t ? ' seg__btn--on' : ''}`}
                    style={salType === t ? { background: 'var(--primary)' } : undefined}
                    onClick={() => setSalType(t)}
                  >
                    {t === 'per_day' ? 'Per day' : 'Monthly'}
                  </button>
                ))}
              </div>
            </div>

            <Field
              label={salType === 'monthly' ? 'Monthly salary (₹)' : 'Per-day salary (₹)'}
              value={salAmount}
              inputMode="decimal"
              autoFocus
              hint={salRateHint}
              onChange={(e) => setSalAmount(e.target.value.replace(/[^0-9.]/g, ''))}
              placeholder="500"
            />
          </div>
        </Modal>
      )}
    </main>
  );
}

function MiniTile({
  label,
  value,
  color,
}: {
  label: string;
  value: number | string;
  color: string;
}) {
  return (
    <div className="tile">
      <div className="tile__value tabnums" style={{ color }}>
        {value}
      </div>
      <div className="tile__label">{label}</div>
    </div>
  );
}
