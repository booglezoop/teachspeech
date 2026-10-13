
-- Calendar safeguards: schedule exceptions and private admin notes.
-- Requires the initial internal calendar migration to have been applied.

begin;

-- 1. Schedule exceptions for time off and one-off hours.
create type public.schedule_exception_kind as enum (
  'time_off',
  'extra_availability',
  'changed_hours'
);

create table public.schedule_exceptions (
  id uuid primary key default gen_random_uuid(),
  specialist_id uuid not null
    references public.specialists(id) on delete cascade,
  kind public.schedule_exception_kind not null,
  starts_at timestamptz not null,
  ends_at timestamptz not null,
  reason text,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint schedule_exceptions_valid_range
    check (starts_at < ends_at)
);

create index schedule_exceptions_specialist_start_idx
  on public.schedule_exceptions (specialist_id, starts_at);

alter table public.schedule_exceptions enable row level security;

revoke all on public.schedule_exceptions from anon, authenticated;
grant select, insert, update, delete
  on public.schedule_exceptions to authenticated;

create policy "schedule_exceptions_read_own_or_admin"
on public.schedule_exceptions for select to authenticated
using (
  specialist_id = (select private.current_specialist_id())
  or (select private.is_active_admin())
);

create policy "schedule_exceptions_insert_own_or_admin"
on public.schedule_exceptions for insert to authenticated
with check (
  specialist_id = (select private.current_specialist_id())
  or (select private.is_active_admin())
);

create policy "schedule_exceptions_update_own_or_admin"
on public.schedule_exceptions for update to authenticated
using (
  specialist_id = (select private.current_specialist_id())
  or (select private.is_active_admin())
)
with check (
  specialist_id = (select private.current_specialist_id())
  or (select private.is_active_admin())
);

create policy "schedule_exceptions_delete_own_or_admin"
on public.schedule_exceptions for delete to authenticated
using (
  specialist_id = (select private.current_specialist_id())
  or (select private.is_active_admin())
);

create trigger schedule_exceptions_set_updated_at
before update on public.schedule_exceptions
for each row execute function private.set_updated_at();

-- 2. Separate private notes from appointment details.
-- Existing admin_notes values are copied to the new table.
create table public.admin_appointment_notes (
  appointment_id uuid primary key
    references public.appointments(id) on delete cascade,
  notes text not null,
  updated_by uuid references auth.users(id) on delete set null,
  updated_at timestamptz not null default now()
);

alter table public.admin_appointment_notes enable row level security;

revoke all on public.admin_appointment_notes from anon, authenticated;
grant select, insert, update, delete
  on public.admin_appointment_notes to authenticated;

create policy "admin_notes_admin_only"
on public.admin_appointment_notes for all to authenticated
using ((select private.is_active_admin()))
with check ((select private.is_active_admin()));

insert into public.admin_appointment_notes (appointment_id, notes)
select id, admin_notes
from public.appointments
where admin_notes is not null;

-- The old column must not remain a way to expose private notes.
alter table public.appointments drop column admin_notes;

commit;
