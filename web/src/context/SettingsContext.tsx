import {
  createContext,
  useCallback,
  useContext,
  useEffect,
  useMemo,
  useState,
  type ReactNode,
} from 'react';

/**
 * Local preferences, the web equivalent of the app's SharedPreferences.
 * Same keys as `settings_controller.dart`, stored in localStorage.
 */

export type ThemeMode = 'system' | 'light' | 'dark';

/** Colour skins, matching `AppBrand` in lib/core/theme/app_colors.dart. */
export type Brand = 'classic' | 'skps';

export const BRAND_LABEL: Record<Brand, string> = {
  classic: 'Classic',
  skps: 'SKPS',
};

const K_THEME = 'theme_mode';
const K_BRAND = 'brand';
const K_BUSINESS = 'business_name';
const DEFAULT_BUSINESS = 'SKPS';

interface SettingsValue {
  themeMode: ThemeMode;
  brand: Brand;
  businessName: string;
  setThemeMode: (mode: ThemeMode) => void;
  setBrand: (brand: Brand) => void;
  setBusinessName: (name: string) => void;
  /** The theme actually painted, after resolving `system`. */
  resolvedTheme: 'light' | 'dark';
}

const SettingsContext = createContext<SettingsValue | null>(null);

function read(key: string, fallback: string): string {
  try {
    return localStorage.getItem(key)?.trim() || fallback;
  } catch {
    return fallback;
  }
}

export function SettingsProvider({ children }: { children: ReactNode }) {
  const [themeMode, setThemeState] = useState<ThemeMode>(
    () => read(K_THEME, 'system') as ThemeMode,
  );
  const [brand, setBrandState] = useState<Brand>(() =>
    read(K_BRAND, 'classic') === 'skps' ? 'skps' : 'classic',
  );
  const [businessName, setBusinessState] = useState(() =>
    read(K_BUSINESS, DEFAULT_BUSINESS),
  );
  const [systemDark, setSystemDark] = useState(
    () => window.matchMedia('(prefers-color-scheme: dark)').matches,
  );

  useEffect(() => {
    const mq = window.matchMedia('(prefers-color-scheme: dark)');
    const onChange = (e: MediaQueryListEvent) => setSystemDark(e.matches);
    mq.addEventListener('change', onChange);
    return () => mq.removeEventListener('change', onChange);
  }, []);

  const resolvedTheme: 'light' | 'dark' =
    themeMode === 'system' ? (systemDark ? 'dark' : 'light') : themeMode;

  useEffect(() => {
    document.documentElement.setAttribute('data-theme', resolvedTheme);
  }, [resolvedTheme]);

  useEffect(() => {
    document.documentElement.setAttribute('data-brand', brand);
  }, [brand]);

  const setThemeMode = useCallback((mode: ThemeMode) => {
    setThemeState(mode);
    try {
      localStorage.setItem(K_THEME, mode);
    } catch {
      /* private browsing — the choice just won't persist */
    }
  }, []);

  const setBrand = useCallback((next: Brand) => {
    setBrandState(next);
    try {
      localStorage.setItem(K_BRAND, next);
    } catch {
      /* private browsing — the choice just won't persist */
    }
  }, []);

  const setBusinessName = useCallback((name: string) => {
    const trimmed = name.trim() || DEFAULT_BUSINESS;
    setBusinessState(trimmed);
    try {
      localStorage.setItem(K_BUSINESS, trimmed);
    } catch {
      /* ignored */
    }
  }, []);

  const value = useMemo<SettingsValue>(
    () => ({
      themeMode,
      brand,
      businessName,
      setThemeMode,
      setBrand,
      setBusinessName,
      resolvedTheme,
    }),
    [
      themeMode,
      brand,
      businessName,
      setThemeMode,
      setBrand,
      setBusinessName,
      resolvedTheme,
    ],
  );

  return <SettingsContext.Provider value={value}>{children}</SettingsContext.Provider>;
}

export function useSettings(): SettingsValue {
  const value = useContext(SettingsContext);
  if (!value) throw new Error('useSettings must be used inside <SettingsProvider>');
  return value;
}
