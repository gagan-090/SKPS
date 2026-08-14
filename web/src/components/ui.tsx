import {
  useEffect,
  type ButtonHTMLAttributes,
  type InputHTMLAttributes,
  type ReactNode,
} from 'react';

import { avatarFor, initials } from '../lib/colors';
import { STATUS, type StatusKey } from '../types';

/* ---- avatar -------------------------------------------------------------- */

export function Avatar({
  name,
  size = 'md',
}: {
  name: string;
  size?: 'sm' | 'md' | 'lg';
}) {
  const cls = size === 'lg' ? 'avatar avatar--lg' : size === 'sm' ? 'avatar avatar--sm' : 'avatar';
  return (
    <div className={cls} style={{ background: avatarFor(name) }} aria-hidden>
      {initials(name)}
    </div>
  );
}

/* ---- status -------------------------------------------------------------- */

export function StatusPill({ status }: { status: StatusKey }) {
  const meta = STATUS[status];
  return (
    <span
      className="pill"
      style={{
        color: meta.color,
        background: `color-mix(in srgb, ${meta.color} 14%, transparent)`,
      }}
    >
      <span className="dot" style={{ background: meta.color }} />
      {meta.label}
    </span>
  );
}

/** The P / A / H / L selector used on Mark Attendance and the calendar editor. */
export function StatusSelector({
  value,
  onChange,
  onClear,
}: {
  value: StatusKey | null;
  onChange: (status: StatusKey) => void;
  onClear?: () => void;
}) {
  return (
    <div className="seg" role="group" aria-label="Attendance status">
      {(Object.keys(STATUS) as StatusKey[]).map((key) => {
        const meta = STATUS[key];
        const on = value === key;
        return (
          <button
            key={key}
            type="button"
            title={meta.label}
            aria-pressed={on}
            className={`seg__btn${on ? ' seg__btn--on' : ''}`}
            style={on ? { background: meta.color } : undefined}
            onClick={() => onChange(key)}
          >
            {meta.shortCode}
          </button>
        );
      })}
      {onClear && (
        <button
          type="button"
          title="Clear — back to not marked"
          className="seg__btn"
          onClick={onClear}
        >
          ×
        </button>
      )}
    </div>
  );
}

/* ---- buttons ------------------------------------------------------------- */

type ButtonProps = ButtonHTMLAttributes<HTMLButtonElement> & {
  variant?: 'primary' | 'ghost' | 'quiet' | 'danger';
  size?: 'md' | 'sm';
  block?: boolean;
  loading?: boolean;
};

export function Button({
  variant = 'primary',
  size = 'md',
  block,
  loading,
  children,
  className = '',
  disabled,
  ...rest
}: ButtonProps) {
  const classes = [
    'btn',
    variant === 'ghost' ? 'btn--ghost' : '',
    variant === 'quiet' ? 'btn--quiet' : '',
    variant === 'danger' ? 'btn--danger' : '',
    size === 'sm' ? 'btn--sm' : '',
    block ? 'btn--block' : '',
    className,
  ]
    .filter(Boolean)
    .join(' ');

  return (
    <button className={classes} disabled={disabled || loading} {...rest}>
      {loading && <span className="spinner" style={{ width: 15, height: 15 }} />}
      {children}
    </button>
  );
}

/* ---- forms --------------------------------------------------------------- */

type FieldProps = InputHTMLAttributes<HTMLInputElement> & {
  label: string;
  error?: string | null;
  hint?: string;
};

export function Field({ label, error, hint, className = '', ...rest }: FieldProps) {
  return (
    <label className="field">
      <span className="field__label">{label}</span>
      <input
        className={`input ${error ? 'input--error' : ''} ${className}`}
        aria-invalid={!!error}
        {...rest}
      />
      {error ? (
        <span className="field__error">{error}</span>
      ) : hint ? (
        <span className="field__hint">{hint}</span>
      ) : null}
    </label>
  );
}

/* ---- feedback ------------------------------------------------------------ */

export function Banner({
  kind = 'info',
  children,
}: {
  kind?: 'error' | 'ok' | 'info';
  children: ReactNode;
}) {
  return (
    <div className={`banner banner--${kind}`} role={kind === 'error' ? 'alert' : undefined}>
      {children}
    </div>
  );
}

export function EmptyState({
  icon = '📋',
  title,
  body,
  action,
}: {
  icon?: string;
  title: string;
  body?: string;
  action?: ReactNode;
}) {
  return (
    <div className="empty">
      <div className="empty__icon">{icon}</div>
      <h3>{title}</h3>
      {body && <p className="small" style={{ margin: 0, maxWidth: 380 }}>{body}</p>}
      {action && <div style={{ marginTop: 8 }}>{action}</div>}
    </div>
  );
}

export function Loading({ rows = 3 }: { rows?: number }) {
  return (
    <div className="stack" aria-busy="true" aria-label="Loading">
      {Array.from({ length: rows }, (_, i) => (
        <div key={i} className="skeleton" />
      ))}
    </div>
  );
}

export function Toast({
  message,
  kind = 'ok',
  onDone,
}: {
  message: string;
  kind?: 'ok' | 'error';
  onDone: () => void;
}) {
  useEffect(() => {
    const t = setTimeout(onDone, kind === 'error' ? 5000 : 2800);
    return () => clearTimeout(t);
  }, [message, kind, onDone]);

  return (
    <div className={`toast${kind === 'error' ? ' toast--error' : ''}`} role="status">
      {message}
    </div>
  );
}

/* ---- modal --------------------------------------------------------------- */

export function Modal({
  title,
  children,
  footer,
  onClose,
  wide,
}: {
  title: string;
  children: ReactNode;
  footer?: ReactNode;
  onClose: () => void;
  wide?: boolean;
}) {
  useEffect(() => {
    const onKey = (e: KeyboardEvent) => {
      if (e.key === 'Escape') onClose();
    };
    document.addEventListener('keydown', onKey);
    return () => document.removeEventListener('keydown', onKey);
  }, [onClose]);

  return (
    <div
      className="modal-scrim"
      onMouseDown={(e) => {
        if (e.target === e.currentTarget) onClose();
      }}
    >
      <div
        className="modal"
        role="dialog"
        aria-modal="true"
        aria-label={title}
        style={wide ? { maxWidth: 620 } : undefined}
      >
        <div className="modal__head">
          <h2>{title}</h2>
        </div>
        <div className="modal__body">{children}</div>
        {footer && <div className="modal__foot">{footer}</div>}
      </div>
    </div>
  );
}
