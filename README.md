# Attendance

A single-owner employee attendance app for a small business. One person — the
owner — logs in, keeps a list of employees, marks attendance each working day,
and exports monthly reports as CSV or PDF to share with an accountant over
WhatsApp or email.

There are **no employee logins**. Only the owner uses the app.

- **Frontend:** Flutter (Material 3), Riverpod, go_router
- **Backend:** Supabase (Postgres + Auth) — free tier only
- **Platforms:** Android (primary), iOS-compatible

---

## What it does

| Screen | What happens there |
| --- | --- |
| **Login** | Email + password, "Forgot password?" sends a Supabase reset link. No sign-up — the account is created by hand in the dashboard. |
| **Home** | Today's date and status, a Mark/Edit button, four stat tiles (Employees / Present / Absent / Not Marked), and this month's per-employee tally. Pull to refresh. |
| **Employees** | Searchable, filterable roster. Long-press a row for Call / WhatsApp / Edit / Deactivate. Add and edit with validation. |
| **Employee detail** | Profile, tap-to-call, WhatsApp link, plus a month calendar where every day is tinted by status. Tap a day to change it. |
| **Mark Attendance** | One row per active employee, a P / A / H / L selector, "Mark All Present", per-row notes, and a single batched save. |
| **Reports** | Month + scope picker, a scrollable matrix with a frozen name column, and CSV / PDF / Print exports through the system share sheet. The PDF carries the SKPS mark in its header and as a faint watermark on every page. |
| **Settings** | Business name (printed on the PDF), theme mode, colour skin (Classic or SKPS), app version, log out. |

---

## Prerequisites

- Flutter **3.38** or newer (Dart 3.10+) — check with `flutter --version`
- Android Studio / Android SDK with a device or emulator
- A free Supabase account

---

## 1. Set up Supabase

Full walkthrough: [`supabase/README.md`](supabase/README.md). In short:

1. Create a project at <https://supabase.com/dashboard>.
2. **SQL Editor → New query**, paste [`supabase/schema.sql`](supabase/schema.sql), press **Run**.
3. **Authentication → Users → Add user**: enter the owner's email and password,
   and tick **Auto Confirm User**.
4. **Project Settings → API**: copy the **Project URL** and the **`anon` public** key.

> Only the `anon` key belongs in the app. The `service_role` key bypasses every
> Row Level Security policy and must never be shipped in a mobile build.

## 2. Configure the app

```bash
cp .env.example .env
```

Then fill in `.env`:

```
SUPABASE_URL=https://YOUR-PROJECT.supabase.co
SUPABASE_ANON_KEY=eyJhbGciOi...
```

`.env` is git-ignored. Nothing secret is ever committed, and no key is
hardcoded in Dart — `lib/core/config/env.dart` reads both values through
`String.fromEnvironment`, and the app refuses to boot with a readable error if
either is missing.

## 3. Run it

```bash
flutter pub get
flutter run --dart-define-from-file=.env
```

Or use the helper scripts:

```bash
./run.sh          # macOS / Linux / Git Bash
.\run.ps1         # Windows PowerShell
```

VS Code users can just press **F5** — `.vscode/launch.json` already passes
`--dart-define-from-file=.env`.

The explicit form, if you prefer passing values by hand:

```bash
flutter run \
  --dart-define=SUPABASE_URL=https://YOUR-PROJECT.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=YOUR-ANON-KEY
```

## 4. Build a release APK

```bash
flutter build apk --split-per-abi --dart-define-from-file=.env
```

Output lands in `build/app/outputs/flutter-apk/`. Install the one matching the
phone's CPU — `app-arm64-v8a-release.apk` for essentially every modern Android
device.

For a Play Store bundle instead:

```bash
flutter build appbundle --dart-define-from-file=.env
```

Release builds are signed with the debug key until you add your own
`android/key.properties` — fine for sideloading, not for the Play Store.

---

## Project layout

```
lib/
  main.dart                     boot, env validation, Supabase init
  app.dart                      MaterialApp.router + theme wiring
  core/
    config/                     dart-define reader, app metadata
    errors/app_exception.dart   the only error type that leaves a repository
    theme/                      colours, brand skins, spacing, light + dark ThemeData
    router/                     go_router with the auth redirect guard
    utils/                      dates, validators, tel/WhatsApp launcher
    widgets/                    empty state, error view, skeletons, buttons…
  data/
    models/                     plain immutable classes, hand-written
    local/offline_store.dart    roster cache + offline attendance queue
    repositories/               the only place Supabase is touched
  features/
    auth/ dashboard/ employees/ attendance/ reports/ settings/
assets/
  brand/                          the SKPS mark (UI copy + smaller print copy)
  icon/                           launcher icon + splash sources
```

Regenerate the launcher icon and splash after changing anything in
`assets/icon/`:

```bash
dart run flutter_launcher_icons
dart run flutter_native_splash:create
```

Rules the code sticks to:

- **Screens never call Supabase.** Only repositories do.
- **Repositories only throw `AppException`,** with a message written for the
  owner, not a `PostgrestException`.
- **Providers live next to the feature that owns them.**
- **Dates for the `day` column are always local `YYYY-MM-DD` strings.** India is
  UTC+05:30, so converting to UTC first would shift days backwards.

## Testing and quality

```bash
flutter analyze     # 0 issues
flutter test        # unit + widget tests
dart format .
```

## Notes

- **Offline:** the active roster and the last few days of attendance are cached
  locally. If a save fails because the phone is offline, it is queued and
  flushed automatically on the next successful connection; the home screen shows
  a "pending sync" banner until it clears.
- **Deleting employees:** the app deactivates by default so past reports keep
  their history. Permanent delete is available behind a confirmation, and it
  cascades to that employee's attendance rows.
- **Fonts:** Inter is fetched by `google_fonts` at first launch. Offline, the
  app falls back to the platform font — layout is unaffected.
