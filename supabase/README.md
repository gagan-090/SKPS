# Supabase setup

Everything here fits inside the Supabase **free tier**. There are no Edge
Functions, no Storage buckets and no Realtime channels — just Postgres and Auth.

## 1. Create the project

1. Go to <https://supabase.com/dashboard> and create a new project.
2. Pick a region close to you (for India, `ap-south-1` / Mumbai).
3. Wait for provisioning to finish (about a minute).

## 2. Run the schema

1. Open **SQL Editor → New query**.
2. Paste the entire contents of [`schema.sql`](./schema.sql).
3. Press **Run**.

You should now see two tables under **Table Editor**: `employees` and
`attendance`, both with the shield icon showing RLS is enabled.

## 3. Create the owner account

There is no sign-up screen in the app — the single owner account is created
by hand.

1. Open **Authentication → Users → Add user → Create new user**.
2. Enter the owner's email and a password.
3. Tick **Auto Confirm User** so no confirmation email is needed.

To let "Forgot password?" work, make sure **Authentication → Providers → Email**
has email enabled, and that a redirect URL is configured under
**Authentication → URL Configuration** if you want the reset link to deep-link
back into the app. (Without one, the reset link opens the Supabase-hosted page,
which is fine.)

## 4. Copy the keys

**Project Settings → API**:

| Value          | Where it goes                       |
| -------------- | ----------------------------------- |
| Project URL    | `SUPABASE_URL` in `.env`            |
| `anon` public  | `SUPABASE_ANON_KEY` in `.env`       |

> The `service_role` key must **never** go into the app. It bypasses every RLS
> policy. Only the `anon` key belongs in a mobile client — Row Level Security is
> what keeps the data private.

## How the data is protected

Both tables carry `owner_id uuid not null default auth.uid()` and a single
`for all` policy of `owner_id = auth.uid()`. A logged-in user can only ever
read or write their own rows, and the `with check` half of the policy stops
anyone from inserting a row owned by someone else.

## Notes on the shape of the data

- The attendance date column is called **`day`** (`date`, not `timestamptz`).
  The app always sends a plain `YYYY-MM-DD` string built from the local device
  date. Sending a UTC timestamp would shift days backwards for IST (UTC+05:30).
- `unique (employee_id, day)` is what makes saving idempotent. The app writes
  attendance with a single batched `upsert` using `employee_id,day` as the
  conflict target, so re-marking a day overwrites rather than duplicating.
- Deleting an employee from the app normally just sets `is_active = false`, so
  past reports keep their history. The permanent delete cascades to that
  employee's attendance rows.
