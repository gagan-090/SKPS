-- ---------------------------------------------------------------------------
-- Employee Attendance — database schema
--
-- Paste this whole file into the Supabase SQL Editor and run it.
-- Safe to run more than once.
-- ---------------------------------------------------------------------------

create extension if not exists "pgcrypto";

do $$ begin
  create type attendance_status as enum ('present','absent','half_day','leave');
exception when duplicate_object then null;
end $$;

create table if not exists employees (
  id          uuid primary key default gen_random_uuid(),
  owner_id    uuid not null references auth.users(id) on delete cascade default auth.uid(),
  name        text not null check (char_length(trim(name)) > 0),
  mobile      text check (mobile ~ '^[6-9][0-9]{9}$'),
  address     text,
  is_active   boolean not null default true,
  joined_on   date not null default current_date,
  created_at  timestamptz not null default now()
);

create table if not exists attendance (
  id          uuid primary key default gen_random_uuid(),
  owner_id    uuid not null references auth.users(id) on delete cascade default auth.uid(),
  employee_id uuid not null references employees(id) on delete cascade,
  day         date not null default current_date,
  status      attendance_status not null,
  note        text,
  marked_at   timestamptz not null default now(),
  unique (employee_id, day)
);

create index if not exists idx_attendance_owner_day on attendance (owner_id, day);
create index if not exists idx_employees_owner_active on employees (owner_id, is_active);

alter table employees  enable row level security;
alter table attendance enable row level security;

-- Policies are dropped first so re-running the file does not error.
drop policy if exists "own_employees"  on employees;
drop policy if exists "own_attendance" on attendance;

create policy "own_employees"  on employees  for all
  using (owner_id = auth.uid()) with check (owner_id = auth.uid());

create policy "own_attendance" on attendance for all
  using (owner_id = auth.uid()) with check (owner_id = auth.uid());
