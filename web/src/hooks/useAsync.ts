import { useCallback, useEffect, useRef, useState } from 'react';

import { errorMessage } from '../lib/errors';

interface AsyncState<T> {
  data: T | null;
  loading: boolean;
  error: string | null;
  /** Re-runs the loader. Safe to pass straight to a Refresh button. */
  reload: () => void;
  /** Optimistic local update, so a save doesn't need a full round trip. */
  setData: (updater: T | ((current: T | null) => T | null)) => void;
}

/**
 * Small data-loading hook — the web stand-in for the Riverpod async providers.
 * `deps` behaves like a useEffect dependency list.
 */
export function useAsync<T>(loader: () => Promise<T>, deps: unknown[]): AsyncState<T> {
  const [data, setData] = useState<T | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [tick, setTick] = useState(0);

  // Guards against a slow earlier request overwriting a newer one.
  const runId = useRef(0);

  useEffect(() => {
    const id = ++runId.current;
    let cancelled = false;

    setLoading(true);
    setError(null);

    loader()
      .then((result) => {
        if (cancelled || id !== runId.current) return;
        setData(result);
      })
      .catch((err) => {
        if (cancelled || id !== runId.current) return;
        setError(errorMessage(err));
      })
      .finally(() => {
        if (cancelled || id !== runId.current) return;
        setLoading(false);
      });

    return () => {
      cancelled = true;
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [...deps, tick]);

  const reload = useCallback(() => setTick((t) => t + 1), []);

  return { data, loading, error, reload, setData: setData as AsyncState<T>['setData'] };
}
