import { useState, type FormEvent } from 'react';
import { useNavigate } from 'react-router-dom';

import { Banner, Button, Field } from '../components/ui';
import { useAuth } from '../context/AuthContext';
import { authRepo } from '../data/auth';
import { errorMessage } from '../lib/errors';
import { Validators } from '../lib/validators';

/**
 * Where the Supabase reset email lands.
 *
 * The link puts a recovery session in the URL, which `detectSessionInUrl`
 * consumes; from there `updateUser` can set a new password.
 */
export default function ResetPassword() {
  const { session, loading, clearRecovering } = useAuth();
  const navigate = useNavigate();

  const [password, setPassword] = useState('');
  const [confirm, setConfirm] = useState('');
  const [error, setError] = useState<string | null>(null);
  const [fieldError, setFieldError] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);

  async function onSubmit(event: FormEvent) {
    event.preventDefault();
    const invalid = Validators.password(password);
    if (invalid) {
      setFieldError(invalid);
      return;
    }
    if (password !== confirm) {
      setFieldError('Both passwords must match');
      return;
    }

    setFieldError(null);
    setError(null);
    setBusy(true);
    try {
      await authRepo.updatePassword(password);
      clearRecovering();
      navigate('/', { replace: true });
    } catch (err) {
      setError(errorMessage(err));
    } finally {
      setBusy(false);
    }
  }

  if (loading) {
    return (
      <div className="center-screen">
        <div className="spinner" />
      </div>
    );
  }

  // Someone opened /reset-password directly, with no recovery session.
  if (!session) {
    return (
      <div className="center-screen">
        <div className="card card--pad auth-card stack">
          <h2>Link expired</h2>
          <p className="muted small" style={{ margin: 0 }}>
            This password reset link is no longer valid. Request a new one from the
            login screen.
          </p>
          <Button onClick={() => navigate('/login', { replace: true })} block>
            Back to login
          </Button>
        </div>
      </div>
    );
  }

  return (
    <div className="center-screen">
      <form className="card card--pad auth-card stack" onSubmit={onSubmit} noValidate>
        <h2>Set a new password</h2>
        {error && <Banner kind="error">{error}</Banner>}

        <Field
          label="New password"
          type="password"
          autoComplete="new-password"
          autoFocus
          value={password}
          onChange={(e) => setPassword(e.target.value)}
          hint="At least 6 characters"
        />

        <Field
          label="Confirm password"
          type="password"
          autoComplete="new-password"
          value={confirm}
          error={fieldError}
          onChange={(e) => setConfirm(e.target.value)}
        />

        <Button type="submit" block loading={busy}>
          Save password
        </Button>
      </form>
    </div>
  );
}
