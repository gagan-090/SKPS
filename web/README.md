# Attendance — Web

The React version of the Flutter attendance app. Same features, same Supabase
project, same database — it is a second client, not a second backend.

- **Stack:** React 19 + TypeScript + Vite, React Router, `@supabase/supabase-js`
- **Backend:** the *existing* Supabase project. Nothing new to deploy.
- **Hosting:** Vercel (static SPA)

---

## How this relates to the Flutter app

Both clients talk straight to Supabase and are protected by the same Row Level
Security policies in [`../supabase/schema.sql`](../supabase/schema.sql). Log in
as the same owner on either one and you see the same roster and the same
attendance — mark someone present on your phone, refresh the website, it's there.

| | Flutter app | This web app |
| --- | --- | --- |
| Config | `--dart-define-from-file=.env` | `VITE_*` env vars |
| Local prefs | SharedPreferences | localStorage (same keys) |
| Exports | share sheet | browser download |
| Offline queue | yes | no — the browser needs a connection |

The one deliberate gap is the offline queue. The Flutter app caches the roster
and queues failed saves; the web app reports the error and lets you retry.

---

## Run it locally

```bash
cd web
npm install
cp .env.example .env      # then fill in both values
npm run dev
```

`.env` needs the same two values as the Flutter `.env`, with a `VITE_` prefix —
Vite only exposes prefixed variables to the browser:

```
VITE_SUPABASE_URL=https://YOUR-PROJECT.supabase.co
VITE_SUPABASE_ANON_KEY=eyJhbGciOi...
```

Only the `anon` key belongs here. It ships inside the JavaScript bundle where
anyone can read it — that is expected and safe, because RLS is what actually
restricts the data. The `service_role` key bypasses RLS and must never be used
in a browser.

Env vars are read at **build** time, so restart the dev server after editing
`.env`, and redeploy after changing them on Vercel.

## Deploy to Vercel

1. Push this repo to GitHub.
2. In Vercel: **Add New → Project**, import the repo.
3. Set **Root Directory** to `web`. This is the important step — the repository
   root is a Flutter project, and Vercel will fail to detect a framework if you
   leave it pointing there.
4. Framework preset **Vite** is detected automatically; the build command
   (`npm run build`) and output directory (`dist`) are already in
   [`vercel.json`](./vercel.json).
5. Under **Environment Variables**, add `VITE_SUPABASE_URL` and
   `VITE_SUPABASE_ANON_KEY` for Production, Preview and Development.
6. Deploy.

From the CLI instead:

```bash
cd web
npx vercel            # preview deploy
npx vercel --prod     # production
```

### Supabase settings the website needs

Two things must be set once, or login will work but password reset won't:

**Authentication → URL Configuration**

- **Site URL:** your production URL, e.g. `https://attendance.vercel.app`
- **Redirect URLs:** add both
  - `https://attendance.vercel.app/reset-password`
  - `http://localhost:5173/reset-password`

Without these, the reset email's link bounces to the Site URL and
`/reset-password` never receives the recovery session.

Supabase allows requests from any origin by default, so no CORS change is
needed. If you have restricted it, add your Vercel domain.

## Scripts

```bash
npm run dev        # dev server on :5173
npm run build      # typecheck + production build into dist/
npm run preview    # serve the built output locally
npm run typecheck  # tsc only
```

## Project layout

```
src/
  main.tsx              boot, env guard, providers
  App.tsx               routes + the auth redirect guard
  styles.css            design tokens ported from app_colors.dart
  lib/
    env.ts              VITE_* reader, mirrors core/config/env.dart
    supabase.ts         the single client
    date.ts             AppDate — local YYYY-MM-DD, never UTC
    validators.ts       same rules as core/utils/validators.dart
    errors.ts           AppError — the only error a repo throws
    colors.ts           status colours + deterministic avatar tints
    csv.ts / pdf.ts     export builders
  types/index.ts        Employee, AttendanceRecord, status enum, aggregates
  data/                 the only place Supabase is touched
  context/              auth session, settings, toasts
  hooks/useAsync.ts     small data-loading hook
  components/           shared UI
  pages/                one file per screen
```

Rules carried over from the Flutter app:

- **Screens never call Supabase.** Only the modules in `data/` do.
- **Repositories only throw `AppError`,** with a message written for the owner.
- **Dates for the `day` column are always local `YYYY-MM-DD` strings.** India is
  UTC+05:30, so converting to UTC first would shift days backwards.

## Notes

- **PDF export** is code-split — jsPDF (~420 kB) only downloads when you click
  PDF or Print, so the rest of the app stays light.
- **Print** opens the generated PDF in a new tab with the print dialog armed,
  which is more predictable across browsers than printing the HTML table.
- **CSV** is written with a UTF-8 BOM so Excel on Windows detects the encoding.
