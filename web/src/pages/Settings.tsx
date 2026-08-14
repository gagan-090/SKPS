import { useState } from 'react';

import { Button, Field, Modal } from '../components/ui';
import { useAuth } from '../context/AuthContext';
import {
  BRAND_LABEL,
  useSettings,
  type Brand,
  type ThemeMode,
} from '../context/SettingsContext';
import { useToast } from '../context/ToastContext';
import { authRepo } from '../data/auth';
import { AppInfo } from '../lib/env';

export default function Settings() {
  const { businessName, setBusinessName, themeMode, setThemeMode, brand, setBrand } =
    useSettings();
  const { email } = useAuth();
  const { notify, notifyError } = useToast();

  const [editing, setEditing] = useState(false);
  const [draftName, setDraftName] = useState(businessName);
  const [signingOut, setSigningOut] = useState(false);

  async function signOut() {
    setSigningOut(true);
    try {
      await authRepo.signOut();
      // The auth listener clears the session and the guard redirects to /login.
    } catch (err) {
      notifyError(err);
      setSigningOut(false);
    }
  }

  return (
    <main className="page">
      <div className="page__head">
        <div>
          <h1>Settings</h1>
          <div className="page__sub">{email}</div>
        </div>
      </div>

      <div className="stack" style={{ maxWidth: 620 }}>
        <section className="card">
          <div className="card__head">
            <h2>Business</h2>
          </div>
          <div className="list">
            <div className="list__row">
              <div className="grow">
                <div className="list__title">Business name</div>
                <div className="list__meta">Printed on the PDF report</div>
              </div>
              <span className="truncate" style={{ maxWidth: 180 }}>
                {businessName}
              </span>
              <Button
                variant="ghost"
                size="sm"
                onClick={() => {
                  setDraftName(businessName);
                  setEditing(true);
                }}
              >
                Change
              </Button>
            </div>
          </div>
        </section>

        <section className="card">
          <div className="card__head">
            <h2>Appearance</h2>
          </div>
          <div className="list">
            <div className="list__row">
              <div className="grow">
                <div className="list__title">Theme</div>
                <div className="list__meta">System follows your device setting</div>
              </div>
              <div className="seg">
                {(['system', 'light', 'dark'] as ThemeMode[]).map((mode) => (
                  <button
                    key={mode}
                    type="button"
                    className={`seg__btn${themeMode === mode ? ' seg__btn--on' : ''}`}
                    style={
                      themeMode === mode
                        ? { background: 'var(--primary)', minWidth: 64 }
                        : { minWidth: 64 }
                    }
                    onClick={() => setThemeMode(mode)}
                  >
                    {mode[0].toUpperCase() + mode.slice(1)}
                  </button>
                ))}
              </div>
            </div>

            <div className="list__row">
              <div className="grow">
                <div className="list__title">Colour</div>
                <div className="list__meta">
                  SKPS paints the panel in the colours of the SKPS logo
                </div>
              </div>
              <div className="brand-picker">
                {(['classic', 'skps'] as Brand[]).map((option) => (
                  <button
                    key={option}
                    type="button"
                    className={`brand-btn${brand === option ? ' brand-btn--on' : ''}`}
                    aria-pressed={brand === option}
                    onClick={() => setBrand(option)}
                  >
                    {option === 'skps' ? (
                      <img src={AppInfo.logo} alt="" width={20} height={20} />
                    ) : (
                      <span className="brand-btn__swatch" />
                    )}
                    {BRAND_LABEL[option]}
                  </button>
                ))}
              </div>
            </div>
          </div>
        </section>

        <section className="card">
          <div className="card__head">
            <h2>Account</h2>
          </div>
          <div className="list">
            <div className="list__row">
              <div className="grow">
                <div className="list__title">Signed in as</div>
                <div className="list__meta truncate">{email}</div>
              </div>
              <Button variant="ghost" size="sm" loading={signingOut} onClick={signOut}>
                Log out
              </Button>
            </div>
            <div className="list__row">
              <div className="grow">
                <div className="list__title">Version</div>
                <div className="list__meta">{AppInfo.tagline}</div>
              </div>
              <span className="muted">{AppInfo.versionLabel}</span>
            </div>
          </div>
        </section>
      </div>

      {editing && (
        <Modal
          title="Business name"
          onClose={() => setEditing(false)}
          footer={
            <>
              <Button variant="ghost" onClick={() => setEditing(false)}>
                Cancel
              </Button>
              <Button
                onClick={() => {
                  setBusinessName(draftName);
                  setEditing(false);
                  notify('Business name saved');
                }}
              >
                Save
              </Button>
            </>
          }
        >
          <Field
            label="Name"
            value={draftName}
            autoFocus
            onChange={(e) => setDraftName(e.target.value)}
            hint="Shown in the header and printed on exported reports."
          />
        </Modal>
      )}
    </main>
  );
}
