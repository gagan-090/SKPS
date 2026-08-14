import { useMemo, useState } from 'react';
import { Link } from 'react-router-dom';

import EmployeeForm from '../components/EmployeeForm';
import { Banner, Button, EmptyState, Loading, Avatar, Modal } from '../components/ui';
import { useToast } from '../context/ToastContext';
import {
  draftFrom,
  emptyDraft,
  employeeRepo,
  type EmployeeDraft,
} from '../data/employees';
import { useAsync } from '../hooks/useAsync';
import { AppDate } from '../lib/date';
import { errorMessage } from '../lib/errors';
import { type Employee, displayMobile, hasMobile } from '../types';

type Filter = 'active' | 'inactive' | 'all';

export default function Employees() {
  const { notify, notifyError } = useToast();
  const [query, setQuery] = useState('');
  const [filter, setFilter] = useState<Filter>('active');

  const [editing, setEditing] = useState<{ employee: Employee | null } | null>(null);
  const [confirmDelete, setConfirmDelete] = useState<Employee | null>(null);
  const [busy, setBusy] = useState(false);
  const [formError, setFormError] = useState<string | null>(null);

  const { data, loading, error, reload } = useAsync(() => employeeRepo.fetchAll(), []);

  const visible = useMemo(() => {
    const q = query.trim().toLowerCase();
    return (data ?? [])
      .filter((e) =>
        filter === 'all' ? true : filter === 'active' ? e.isActive : !e.isActive,
      )
      .filter(
        (e) =>
          !q ||
          e.name.toLowerCase().includes(q) ||
          (e.mobile ?? '').includes(q) ||
          (e.address ?? '').toLowerCase().includes(q),
      );
  }, [data, query, filter]);

  async function save(draft: EmployeeDraft) {
    setBusy(true);
    setFormError(null);
    try {
      const target = editing?.employee;
      if (target) {
        await employeeRepo.update(target.id, draft);
        notify('Employee updated');
      } else {
        await employeeRepo.create(draft);
        notify('Employee added');
      }
      setEditing(null);
      reload();
    } catch (err) {
      setFormError(errorMessage(err));
    } finally {
      setBusy(false);
    }
  }

  async function toggleActive(employee: Employee) {
    try {
      await employeeRepo.setActive(employee.id, !employee.isActive);
      notify(employee.isActive ? 'Employee deactivated' : 'Employee reactivated');
      reload();
    } catch (err) {
      notifyError(err);
    }
  }

  async function remove(employee: Employee) {
    setBusy(true);
    try {
      await employeeRepo.remove(employee.id);
      notify('Employee deleted');
      setConfirmDelete(null);
      reload();
    } catch (err) {
      notifyError(err);
    } finally {
      setBusy(false);
    }
  }

  return (
    <main className="page">
      <div className="page__head">
        <div>
          <h1>Employees</h1>
          <div className="page__sub">
            {(data ?? []).filter((e) => e.isActive).length} active ·{' '}
            {(data ?? []).length} total
          </div>
        </div>
        <Button onClick={() => { setFormError(null); setEditing({ employee: null }); }}>
          + Add employee
        </Button>
      </div>

      {error && <Banner kind="error">{error}</Banner>}

      <div className="stack">
        <div className="row row--wrap">
          <input
            className="input grow"
            style={{ maxWidth: 340 }}
            placeholder="Search name, mobile or address"
            value={query}
            onChange={(e) => setQuery(e.target.value)}
          />
          <div className="seg">
            {(['active', 'inactive', 'all'] as Filter[]).map((key) => (
              <button
                key={key}
                type="button"
                className={`seg__btn${filter === key ? ' seg__btn--on' : ''}`}
                style={
                  filter === key ? { background: 'var(--primary)', minWidth: 72 } : { minWidth: 72 }
                }
                onClick={() => setFilter(key)}
              >
                {key[0].toUpperCase() + key.slice(1)}
              </button>
            ))}
          </div>
        </div>

        {loading && !data ? (
          <Loading rows={5} />
        ) : visible.length === 0 ? (
          <div className="card">
            <EmptyState
              icon="👥"
              title={query ? 'No matches' : 'Nobody here yet'}
              body={
                query
                  ? 'Try a different name or number.'
                  : 'Add your first employee to start marking attendance.'
              }
            />
          </div>
        ) : (
          <div className="card list">
            {visible.map((employee) => (
              <div key={employee.id} className="list__row">
                <Avatar name={employee.name} />

                <Link to={`/employees/${employee.id}`} className="grow" style={{ color: 'inherit' }}>
                  <div className="list__title truncate">
                    {employee.name}
                    {!employee.isActive && (
                      <span className="muted small"> · inactive</span>
                    )}
                  </div>
                  <div className="list__meta truncate">
                    {hasMobile(employee.mobile)
                      ? displayMobile(employee.mobile)
                      : 'No mobile'}{' '}
                    · joined {AppDate.display(employee.joinedOn)}
                  </div>
                </Link>

                <div className="row no-print">
                  {hasMobile(employee.mobile) && (
                    <>
                      <a
                        className="btn btn--quiet btn--sm"
                        href={`tel:+91${employee.mobile}`}
                        title="Call"
                      >
                        Call
                      </a>
                      <a
                        className="btn btn--quiet btn--sm"
                        href={`https://wa.me/91${employee.mobile}`}
                        target="_blank"
                        rel="noreferrer"
                        title="WhatsApp"
                      >
                        WhatsApp
                      </a>
                    </>
                  )}
                  <Button
                    variant="quiet"
                    size="sm"
                    onClick={() => {
                      setFormError(null);
                      setEditing({ employee });
                    }}
                  >
                    Edit
                  </Button>
                  <Button variant="quiet" size="sm" onClick={() => toggleActive(employee)}>
                    {employee.isActive ? 'Deactivate' : 'Reactivate'}
                  </Button>
                  <Button
                    variant="quiet"
                    size="sm"
                    onClick={() => setConfirmDelete(employee)}
                    style={{ color: 'var(--absent)' }}
                  >
                    Delete
                  </Button>
                </div>
              </div>
            ))}
          </div>
        )}
      </div>

      {editing && (
        <EmployeeForm
          title={editing.employee ? 'Edit employee' : 'Add employee'}
          initial={editing.employee ? draftFrom(editing.employee) : emptyDraft()}
          busy={busy}
          error={formError}
          onCancel={() => setEditing(null)}
          onSubmit={save}
        />
      )}

      {confirmDelete && (
        <Modal
          title="Delete permanently?"
          onClose={() => setConfirmDelete(null)}
          footer={
            <>
              <Button variant="ghost" onClick={() => setConfirmDelete(null)} disabled={busy}>
                Cancel
              </Button>
              <Button variant="danger" loading={busy} onClick={() => remove(confirmDelete)}>
                Delete
              </Button>
            </>
          }
        >
          <p className="small">
            <strong>{confirmDelete.name}</strong> and every attendance record for them
            will be deleted. Past reports will no longer include this person.
          </p>
          <p className="small muted">
            Deactivating instead keeps the history and just hides them from Mark
            Attendance.
          </p>
        </Modal>
      )}
    </main>
  );
}
