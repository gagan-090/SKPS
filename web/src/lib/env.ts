/**
 * Runtime configuration, supplied by Vite at build time.
 *
 * Mirrors `lib/core/config/env.dart`: nothing is hardcoded, and the app shows a
 * readable error instead of booting half-broken when a value is missing.
 */

const url = (import.meta.env.VITE_SUPABASE_URL ?? '').trim();
const anonKey = (import.meta.env.VITE_SUPABASE_ANON_KEY ?? '').trim();

export const Env = {
  supabaseUrl: url,
  supabaseAnonKey: anonKey,

  get missingKeys(): string[] {
    return [
      ...(url ? [] : ['VITE_SUPABASE_URL']),
      ...(anonKey ? [] : ['VITE_SUPABASE_ANON_KEY']),
    ];
  },

  get isConfigured(): boolean {
    return this.missingKeys.length === 0;
  },

  get missingConfigMessage(): string {
    return (
      `Missing build configuration: ${this.missingKeys.join(', ')}.\n\n` +
      'Locally: copy .env.example to .env and fill both values, then restart ' +
      'the dev server.\n\n' +
      'On Vercel: add them under Project Settings → Environment Variables and ' +
      'redeploy.'
    );
  },
} as const;

export const AppInfo = {
  name: 'SKPS Attendance',
  shortName: 'SKPS',
  version: '1.0.0',
  buildNumber: '1',
  versionLabel: '1.0.0 (1)',
  tagline: 'Daily staff attendance, kept simple.',
  /** The SKPS mark, served from `web/public`. */
  logo: '/skps-logo.png',
} as const;
