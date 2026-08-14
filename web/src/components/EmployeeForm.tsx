import { useState } from 'react';

import { Banner, Button, Field, Modal } from './ui';
import { type EmployeeDraft } from '../data/employees';
import { AppDate } from '../lib/date';
import { Validators } from '../lib/validators';

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
  const [errors, setErrors] = useState<{ name?: string; mobile?: string }>({});

  function submit() {
    const next = {
      name: Validators.employeeName(name) ?? undefined,
      mobile: Validators.mobileOptional(mobile) ?? undefined,
    };
    setErrors(next);
    if (next.name || next.mobile) return;

    onSubmit({
      name: name.trim(),
      mobile: mobile.trim() || null,
      address: address.trim() || null,
      isActive,
      joinedOn: AppDate.parseYmd(joinedOn),
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
