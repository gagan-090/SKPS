import { useState, type FormEvent } from 'react';

import { Banner, Button, Field } from '../components/ui';
import { authRepo } from '../data/auth';
import { AppInfo } from '../lib/env';
import { errorMessage } from '../lib/errors';
import { Validators } from '../lib/validators';

/**
 * Email + password only. There is deliberately no sign-up: the owner account is
 * created by hand in the Supabase dashboard, exactly like the mobile app.
 */
export default function Login() {
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [errors, setErrors] = useState<{ email?: string; password?: string }>({});
  const [formError, setFormError] = useState<string | null>(null);
  const [notice, setNotice] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);

  async function onSubmit(event: FormEvent) {
    event.preventDefault();
    const next = {
      email: Validators.email(email) ?? undefined,
      password: Validators.password(password) ?? undefined,
    };
    setErrors(next);
    setFormError(null);
    setNotice(null);
    if (next.email || next.password) return;

    setBusy(true);
    try {
      await authRepo.signIn(email, password);
      // The auth listener flips the session and the router redirects.
    } catch (error) {
      setFormError(errorMessage(error));
    } finally {
      setBusy(false);
    }
  }

  async function onForgotPassword() {
    const emailError = Validators.email(email);
    if (emailError) {
      setErrors({ email: 'Enter your email first, then tap Forgot password' });
      return;
    }

    setBusy(true);
    setFormError(null);
    try {
      await authRepo.resetPassword(email);
      setNotice(`Reset link sent to ${email.trim()}. Check your inbox and spam.`);
    } catch (error) {
      setFormError(errorMessage(error));
    } finally {
      setBusy(false);
    }
  }

  return (
    <div className="center-screen">
      <div className="auth-card stack">
        <div style={{ textAlign: 'center' }}>
          <div
            className="topbar__mark"
            style={{ width: 52, height: 52, margin: '0 auto 14px', fontSize: '1.3rem', borderRadius: 15 }}
          >
            A
          </div>
          <h1>{AppInfo.name}</h1>
          <p className="muted small" style={{ margin: '4px 0 0' }}>
            {AppInfo.tagline}
          </p>
        </div>

        <form className="card card--pad stack" onSubmit={onSubmit} noValidate>
          {formError && <Banner kind="error">{formError}</Banner>}
          {notice && <Banner kind="ok">{notice}</Banner>}

          <Field
            label="Email"
            type="email"
            autoComplete="username"
            autoFocus
            value={email}
            error={errors.email}
            onChange={(e) => setEmail(e.target.value)}
            placeholder="owner@example.com"
          />

          <Field
            label="Password"
            type="password"
            autoComplete="current-password"
            value={password}
            error={errors.password}
            onChange={(e) => setPassword(e.target.value)}
            placeholder="••••••••"
          />

          <Button type="submit" block loading={busy}>
            Log in
          </Button>

          <Button type="button" variant="quiet" onClick={onForgotPassword} disabled={busy}>
            Forgot password?
          </Button>
        </form>

        <p className="muted small" style={{ textAlign: 'center', margin: 0 }}>
          Accounts are created in the Supabase dashboard. There is no sign-up.
        </p>
      </div>
    </div>
  );
}
