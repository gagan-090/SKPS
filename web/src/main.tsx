import { StrictMode } from 'react';
import { createRoot } from 'react-dom/client';
import { BrowserRouter } from 'react-router-dom';

import App from './App';
import { Env } from './lib/env';
import { AuthProvider } from './context/AuthContext';
import { SettingsProvider } from './context/SettingsContext';
import { ToastProvider } from './context/ToastContext';
import './styles.css';

const root = createRoot(document.getElementById('root')!);

/**
 * Refuse to boot with a readable error rather than failing on the first query,
 * mirroring the env check in `lib/main.dart`.
 */
if (!Env.isConfigured) {
  root.render(
    <div className="center-screen">
      <div className="card card--pad auth-card">
        <h2 style={{ marginBottom: 8 }}>Configuration missing</h2>
        <p className="muted small" style={{ whiteSpace: 'pre-wrap', margin: 0 }}>
          {Env.missingConfigMessage}
        </p>
      </div>
    </div>,
  );
} else {
  root.render(
    <StrictMode>
      <SettingsProvider>
        <AuthProvider>
          <ToastProvider>
            <BrowserRouter>
              <App />
            </BrowserRouter>
          </ToastProvider>
        </AuthProvider>
      </SettingsProvider>
    </StrictMode>,
  );
}
