-- Anonymous install/activity count. The random install_id is generated on-device
-- and is not connected to auth.users or an email address.
create table if not exists public.godot_install_sessions (
  install_id uuid primary key,
  platform text not null check (platform in ('ios','android','web','desktop','unknown')),
  game_version text not null default '',
  first_seen timestamptz not null default now(),
  last_seen timestamptz not null default now()
);

alter table public.godot_install_sessions enable row level security;
revoke all on public.godot_install_sessions from public, anon, authenticated;

create or replace function public.godot_install_ping(
  p_install_id uuid,
  p_platform text,
  p_game_version text default ''
) returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if p_install_id is null or p_platform not in ('ios','android','web','desktop','unknown') then
    raise exception 'invalid install ping';
  end if;
  insert into public.godot_install_sessions(install_id, platform, game_version)
  values (p_install_id, p_platform, left(coalesce(p_game_version,''),32))
  on conflict (install_id) do update set
    platform = excluded.platform,
    game_version = excluded.game_version,
    last_seen = now();
end;
$$;

revoke all on function public.godot_install_ping(uuid,text,text) from public;
grant execute on function public.godot_install_ping(uuid,text,text) to anon, authenticated;

-- Admin dashboard examples:
-- select platform, count(*) as installs,
--        count(*) filter (where last_seen > now()-interval '1 day') as dau
-- from public.godot_install_sessions group by platform order by platform;
