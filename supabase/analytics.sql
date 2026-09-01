-- Private product analytics for Taiwan Basketball Manager.
-- Run once in Supabase SQL Editor. No email or provider token is stored.
create table if not exists public.godot_analytics_events (
  id bigint generated always as identity primary key,
  owner_id uuid not null references auth.users(id) on delete cascade,
  event_name text not null check (event_name ~ '^[a-z][a-z0-9_.-]{1,63}$'),
  platform text not null default 'unknown' check (platform in ('ios','android','web','desktop','unknown')),
  game_version text not null default '',
  properties jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

alter table public.godot_analytics_events enable row level security;
drop policy if exists "analytics own insert" on public.godot_analytics_events;
create policy "analytics own insert" on public.godot_analytics_events
  for insert to authenticated
  with check ((select auth.uid()) = owner_id);
revoke all on public.godot_analytics_events from anon;
grant insert on public.godot_analytics_events to authenticated;

create index if not exists godot_analytics_events_created_idx
  on public.godot_analytics_events(created_at desc);
create index if not exists godot_analytics_events_name_idx
  on public.godot_analytics_events(event_name, created_at desc);
create index if not exists godot_analytics_events_owner_idx
  on public.godot_analytics_events(owner_id, created_at desc);

-- Admin-only reporting view. Keep the table itself unreadable by clients.
create or replace view public.godot_analytics_daily
  with (security_invoker = true) as
select date(timezone('Asia/Taipei', created_at)) as day,
       platform,
       game_version,
       event_name,
       count(*)::bigint as events,
       count(distinct owner_id)::bigint as users
from public.godot_analytics_events
group by 1,2,3,4;
revoke all on public.godot_analytics_daily from anon, authenticated;

-- Useful dashboard queries (run as an admin in SQL Editor):
-- select day, count(distinct owner_id) filter (where event_name='session_start') as dau
-- from public.godot_analytics_events group by day order by day desc;
-- select event_name, count(*) as events, count(distinct owner_id) as users
-- from public.godot_analytics_events where created_at > now()-interval '7 days'
-- group by event_name order by users desc;
