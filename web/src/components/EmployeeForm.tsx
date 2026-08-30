import { useState } from 'react';

import { Banner, Button, Field, Modal } from './ui';
import { type EmployeeDraft } from '../data/employees';
import { AppDate } from '../lib/date';
import { formatINR } from '../lib/money';
import { Validators } from '../lib/validators';
import { DAYS_IN_SALARY_MONTH, type SalaryType } from '../types';

/** Add / edit dialog, with the same validation rules as the Flutter form. */
export default function EmployeeForm({
  title,
  initial,
  busy,
  error,
  onCancel,
  onSubmit,
}: {
  title: string;
  initial: EmployeeDraft;
  busy: boolean;
  error: string | null;
  onCancel: () => void;
  onSubmit: (draft: EmployeeDraft) => void;
}) {
  const [name, setName] = useState(initial.name);
  const [mobile, setMobile] = useState(initial.mobile ?? '');
  const [address, setAddress] = useState(initial.address ?? '');
  const [joinedOn, setJoinedOn] = useState(AppDate.ymd(initial.joinedOn));
  const [isActive, setIsActive] = useState(initial.isActive);
  const [salaryType, setSalaryType] = useState<SalaryType>(initial.salaryType);
  const [salary, setSalary] = useState(
    initial.salaryAmount == null ? '' : String(initial.salaryAmount),
  );
  const [errors, setErrors] = useState<{ name?: string; mobile?: string; salary?: string }>({});

  const salaryNum = salary.trim() === '' ? null : Number(salary);
  const salaryValid = salaryNum == null || (Number.isFinite(salaryNum) && salaryNum >= 0);
  const rateHint =
    salaryNum && salaryValid
      ? salaryType === 'monthly'
        ? `≈ ${formatINR(salaryNum / DAYS_IN_SALARY_MONTH)} per day`
        : `≈ ${formatINR(salaryNum * DAYS_IN_SALARY_MONTH)} per month`
      : 'Optional — used to work out pay in reports';

  function submit() {
    const next = {
      name: Validators.employeeName(name) ?? undefined,
      mobile: Validators.mobileOptional(mobile) ?? undefined,
      salary: salaryValid ? undefined : 'Enter a valid amount',
    };
    setErrors(next);
    if (next.name || next.mobile || next.salary) return;

    onSubmit({
      name: name.trim(),
      mobile: mobile.trim() || null,
      address: address.trim() || null,
      isActive,
      joinedOn: AppDate.parseYmd(joinedOn),
      salaryType,
      salaryAmount: salaryNum,
    });
  }

  return (
    <Modal
      title={title}
      onClose={onCancel}
      footer={
        <>
          <Button variant="ghost" onClick={onCancel} disabled={busy}>
            Cancel
          </Button>
          <Button onClick={submit} loading={busy}>
            Save
          </Button>
        </>
      }
    >
      <form
        className="stack"
        style={{ paddingBottom: 4 }}
        onSubmit={(e) => {
          e.preventDefault();
          submit();
        }}
        noValidate
      >
        {error && <Banner kind="error">{error}</Banner>}

        <Field
          label="Name"
          value={name}
          autoFocus
          error={errors.name}
          onChange={(e) => setName(e.target.value)}
          placeholder="Ramesh Kumar"
        />

        <Field
          label="Mobile (optional)"
          value={mobile}
          inputMode="numeric"
          maxLength={10}
          error={errors.mobile}
          hint="10 digits, starting with 6–9"
          onChange={(e) => setMobile(e.target.value.replace(/\D/g, ''))}
          placeholder="9876543210"
        />

        <label className="field">
          <span className="field__label">Address (optional)</span>
          <textarea
            className="textarea"
            value={address}
            onChange={(e) => setAddress(e.target.value)}
            placeholder="Village / area"
          />
        </label>

        <Field
          label="Joined on"
          type="date"
          value={joinedOn}
          max={AppDate.ymd(AppDate.today())}
          onChange={(e) => setJoinedOn(e.target.value)}
        />

        <div className="field">
          <span className="field__label">Salary type</span>
          <div className="seg" role="group" aria-label="Salary type">
            {(['per_day', 'monthly'] as SalaryType[]).map((type) => (
              <button
                key={type}
                type="button"
                aria-pressed={salaryType === type}
                className={`seg__btn${salaryType === type ? ' seg__btn--on' : ''}`}
                style={salaryType === type ? { background: 'var(--primary)' } : undefined}
                onClick={() => setSalaryType(type)}
              >
                {type === 'per_day' ? 'Per day' : 'Monthly'}
              </button>
            ))}
          </div>
        </div>

        <Field
          label={salaryType === 'monthly' ? 'Monthly salary (₹)' : 'Per-day salary (₹)'}
          value={salary}
          inputMode="decimal"
          error={errors.salary}
          hint={rateHint}
          onChange={(e) => setSalary(e.target.value.replace(/[^0-9.]/g, ''))}
          placeholder="500"
        />

        <label className="row" style={{ cursor: 'pointer' }}>
          <input
            type="checkbox"
            checked={isActive}
            onChange={(e) => setIsActive(e.target.checked)}
          />
          <span className="grow">
            <span style={{ fontWeight: 600 }}>Active</span>
            <span className="field__hint" style={{ display: 'block' }}>
              Inactive staff are hidden from Mark Attendance but keep their history.
            </span>
          </span>
        </label>
      </form>
    </Modal>
  );
}
