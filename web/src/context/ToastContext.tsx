import {
  createContext,
  useCallback,
  useContext,
  useMemo,
  useState,
  type ReactNode,
} from 'react';

import { Toast } from '../components/ui';
import { errorMessage } from '../lib/errors';

interface ToastValue {
  notify: (message: string) => void;
  /** Turns any thrown value into the owner-facing message and shows it. */
  notifyError: (error: unknown) => void;
}

const ToastContext = createContext<ToastValue | null>(null);

export function ToastProvider({ children }: { children: ReactNode }) {
  const [toast, setToast] = useState<{ message: string; kind: 'ok' | 'error' } | null>(
    null,
  );

  const value = useMemo<ToastValue>(
    () => ({
      notify: (message: string) => setToast({ message, kind: 'ok' }),
      notifyError: (error: unknown) =>
        setToast({ message: errorMessage(error), kind: 'error' }),
    }),
    [],
  );

  const clear = useCallback(() => setToast(null), []);

  return (
    <ToastContext.Provider value={value}>
      {children}
      {toast && <Toast message={toast.message} kind={toast.kind} onDone={clear} />}
    </ToastContext.Provider>
  );
}

export function useToast(): ToastValue {
  const value = useContext(ToastContext);
  if (!value) throw new Error('useToast must be used inside <ToastProvider>');
  return value;
}
