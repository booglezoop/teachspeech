
-- TeachSpeech internal calendar: initial schema
-- Run in Supabase SQL Editor on a new project.

create extension if not exists btree_gist;
create schema if not exists private;

create type public.staff_role as enum ('admin', 'specialist');

create type public.appointment_status as enum (
  'confirmed',
  'completed',
  'cancelled'
);

-- Staff accounts are linked to Supabase Auth identities.
create table public.staff_profiles (
  user_id uuid primary key references auth.users(id) on delete cascade,
  role public.staff_role not null,
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);

-- A specialist is a staff member with a calendar.
create table public.specialists (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null unique
    references public.staff_profiles(user_id) on delete restrict,
  display_name text not null,
  appointment_minutes integer not null default 50
    check (appointment_minutes between 15 and 240),
  buffer_minutes integer not null default 10
    check (buffer_minutes between 0 and 60),
  created_at timestamptz not null default now()
);

-- Weekly recurring working hours.
-- weekday: 0 = Sunday, 6 = Saturday.
create table public.availability (
  id uuid primary key default gen_random_uuid(),
  specialist_id uuid not null
    references public.specialists(id) on delete cascade,
  weekday smallint not null check (weekday between 0 and 6),
  starts_at time not null,
  ends_at time not null,
  check (starts_at < ends_at),
  created_at timestamptz not null default now()
);

-- Phone bookings can be entered directly by staff.
-- Keep notes administrative; do not store clinical records here.
create table public.appointments (
  id uuid primary key default gen_random_uuid(),
  specialist_id uuid not null
    references public.specialists(id) on delete restrict,
  parent_name text not null,
  parent_phone text not null,
  starts_at timestamptz not null,
  ends_at timestamptz not null,
  status public.appointment_status not null default 'confirmed',
  session_type text not null default 'in_person'
    check (session_type in ('in_person', 'online', 'phone')),
  admin_notes text,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (starts_at < ends_at)
);

create index appointments_specialist_start_idx
  on public.appointments (specialist_id, starts_at);

create index availability_specialist_weekday_idx
  on public.availability (specialist_id, weekday);

-- Prevent overlapping confirmed appointments for the same specialist.
-- Cancelled and completed appointments do not block future slots.
alter table public.appointments
  add constraint appointments_no_confirmed_overlap
  exclude using gist (
    specialist_id with =,
    tstzrange(starts_at, ends_at, '[)') with &&
  )
  where (status = 'confirmed');

-- Private helper functions for RLS policies.
-- SECURITY DEFINER is used only to read staff identity/role securely.
create or replace function private.is_active_admin()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.staff_profiles p
    where p.user_id = (select auth.uid())
      and p.role = 'admin'
      and p.is_active = true
  );
$$;

create or replace function private.current_specialist_id()
returns uuid
language sql
stable
security definer
set search_path = ''
as $$
  select s.id
  from public.specialists s
  join public.staff_profiles p on p.user_id = s.user_id
  where p.user_id = (select auth.uid())
    and p.role = 'specialist'
    and p.is_active = true
  limit 1;
$$;

revoke all on schema private from public, anon;
grant usage on schema private to authenticated;

revoke all on function private.is_active_admin() from public, anon;
revoke all on function private.current_specialist_id() from public, anon;
grant execute on function private.is_active_admin() to authenticated;
grant execute on function private.current_specialist_id() to authenticated;

-- Enable row-level security on every application table.
alter table public.staff_profiles enable row level security;
alter table public.specialists enable row level security;
alter table public.availability enable row level security;
alter table public.appointments enable row level security;

-- Explicit table privileges: policies below further restrict each row.
revoke all on public.staff_profiles from anon, authenticated;
revoke all on public.specialists from anon, authenticated;
revoke all on public.availability from anon, authenticated;
revoke all on public.appointments from anon, authenticated;

grant select, insert, update, delete
  on public.staff_profiles to authenticated;
grant select, insert, update, delete
  on public.specialists to authenticated;
grant select, insert, update, delete
  on public.availability to authenticated;
grant select, insert, update
  on public.appointments to authenticated;

-- Staff profiles: staff can read their own profile;
-- only an active admin can manage staff roles and account status.
create policy "staff_read_self_or_admin"
on public.staff_profiles for select
to authenticated
using (
  user_id = (select auth.uid())
  or (select private.is_active_admin())
);

create policy "admin_insert_staff"
on public.staff_profiles for insert
to authenticated
with check ((select private.is_active_admin()));

create policy "admin_update_staff"
on public.staff_profiles for update
to authenticated
using ((select private.is_active_admin()))
with check ((select private.is_active_admin()));

create policy "admin_delete_staff"
on public.staff_profiles for delete
to authenticated
using ((select private.is_active_admin()));

-- Specialist records: specialists can read their own record;
-- only admins manage specialist profiles.
create policy "specialist_read_own_or_admin"
on public.specialists for select
to authenticated
using (
  user_id = (select auth.uid())
  or (select private.is_active_admin())
);

create policy "admin_insert_specialist"
on public.specialists for insert
to authenticated
with check ((select private.is_active_admin()));

create policy "admin_update_specialist"
on public.specialists for update
to authenticated
using ((select private.is_active_admin()))
with check ((select private.is_active_admin()));

create policy "admin_delete_specialist"
on public.specialists for delete
to authenticated
using ((select private.is_active_admin()));

-- Availability: admins manage all schedules;
-- specialists manage only their own working hours.
create policy "availability_read_own_or_admin"
on public.availability for select
to authenticated
using (
  specialist_id = (select private.current_specialist_id())
  or (select private.is_active_admin())
);

create policy "availability_insert_own_or_admin"
on public.availability for insert
to authenticated
with check (
  specialist_id = (select private.current_specialist_id())
  or (select private.is_active_admin())
);

create policy "availability_update_own_or_admin"
on public.availability for update
to authenticated
using (
  specialist_id = (select private.current_specialist_id())
  or (select private.is_active_admin())
)
with check (
  specialist_id = (select private.current_specialist_id())
  or (select private.is_active_admin())
);

create policy "availability_delete_own_or_admin"
on public.availability for delete
to authenticated
using (
  specialist_id = (select private.current_specialist_id())
  or (select private.is_active_admin())
);

-- Appointments: admins see all; specialists see and manage their own.
create policy "appointments_read_own_or_admin"
on public.appointments for select
to authenticated
using (
  specialist_id = (select private.current_specialist_id())
  or (select private.is_active_admin())
);

create policy "appointments_insert_own_or_admin"
on public.appointments for insert
to authenticated
with check (
  (
    specialist_id = (select private.current_specialist_id())
    and (select auth.uid()) is not null
  )
  or (select private.is_active_admin())
);

create policy "appointments_update_own_or_admin"
on public.appointments for update
to authenticated
using (
  specialist_id = (select private.current_specialist_id())
  or (select private.is_active_admin())
)
with check (
  specialist_id = (select private.current_specialist_id())
  or (select private.is_active_admin())
);

-- Keep updated_at current on appointment edits.
create or replace function private.set_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create trigger appointments_set_updated_at
before update on public.appointments
for each row execute function private.set_updated_at();
