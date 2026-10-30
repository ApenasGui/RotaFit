-- Execute no SQL Editor do Supabase. Os testes usam este mesmo schema.
create table public.runs (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  started_at timestamptz not null,
  ended_at timestamptz not null,
  distance_meters numeric(10, 2) not null check (distance_meters >= 0),
  duration_seconds integer not null check (duration_seconds > 0),
  avg_pace_sec_per_km numeric(8, 2) check (avg_pace_sec_per_km > 0),
  route jsonb not null default '[]'::jsonb check (jsonb_typeof(route) = 'array'),
  spotify_track_name text,
  created_at timestamptz not null default now(),
  constraint ended_after_started check (ended_at >= started_at)
);

create index runs_user_started_at_idx on public.runs (user_id, started_at desc);

alter table public.runs enable row level security;
revoke all on public.runs from anon, authenticated;
grant select, insert, delete on public.runs to authenticated;

create policy runs_select_own on public.runs for select to authenticated
  using (user_id = (select auth.uid()));
create policy runs_insert_own on public.runs for insert to authenticated
  with check (user_id = (select auth.uid()));
create policy runs_delete_own on public.runs for delete to authenticated
  using (user_id = (select auth.uid()));

create function public.weekly_stats()
returns table (
  total_distance_meters numeric,
  total_duration_seconds bigint,
  run_count bigint
)
language sql stable security invoker
set search_path = ''
as $$
  select coalesce(sum(distance_meters), 0), coalesce(sum(duration_seconds), 0), count(*)
  from public.runs
  where user_id = (select auth.uid())
    and started_at >= date_trunc('week', now())
    and started_at < date_trunc('week', now()) + interval '1 week'
$$;

revoke all on function public.weekly_stats() from public, anon;
grant execute on function public.weekly_stats() to authenticated;
