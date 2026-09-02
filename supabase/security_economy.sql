-- 台籃模擬器：伺服器經濟、付費與版本安全層
-- 先執行本檔，再由新客戶端改用 godot_economy_apply。

create schema if not exists tb_economy_private;
revoke all on schema tb_economy_private from public, anon, authenticated;

create table if not exists public.godot_economy_accounts (
  owner_id uuid primary key references auth.users(id) on delete cascade,
  budget_million integer not null default 300 check (budget_million >= 0),
  gold integer not null default 100 check (gold >= 0),
  scout_points integer not null default 20 check (scout_points >= 0),
  training_points integer not null default 2 check (training_points >= 0),
  version bigint not null default 1,
  updated_at timestamptz not null default clock_timestamp()
);
alter table public.godot_economy_accounts enable row level security;
drop policy if exists "economy own read" on public.godot_economy_accounts;
create policy "economy own read" on public.godot_economy_accounts
  for select using ((select auth.uid()) = owner_id);
revoke insert, update, delete on public.godot_economy_accounts from anon, authenticated;

create table if not exists tb_economy_private.ledger (
  owner_id uuid not null references auth.users(id) on delete cascade,
  request_id uuid not null,
  action text not null check (action ~ '^[a-z0-9_]{2,40}$'),
  delta_budget integer not null default 0,
  delta_gold integer not null default 0,
  delta_scout integer not null default 0,
  delta_training integer not null default 0,
  balance_after jsonb not null,
  created_at timestamptz not null default clock_timestamp(),
  primary key(owner_id, request_id)
);
create index if not exists economy_ledger_owner_time on tb_economy_private.ledger(owner_id, created_at desc);
alter table tb_economy_private.ledger enable row level security;
revoke all on tb_economy_private.ledger from public, anon, authenticated;

create or replace function tb_economy_private.apply_transaction(
  p_action text,
  p_request_id uuid,
  p_delta_budget integer default 0,
  p_delta_gold integer default 0,
  p_delta_scout integer default 0,
  p_delta_training integer default 0
) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  uid uuid := auth.uid();
  account public.godot_economy_accounts;
  prior tb_economy_private.ledger;
  next_budget integer;
  next_gold integer;
  next_scout integer;
  next_training integer;
  result jsonb;
begin
  -- Client calls may only spend balances. Grants are issued by a future
  -- owner-scoped Edge Function after validating a match, mission or receipt.
  if uid is null then raise exception 'LOGIN_REQUIRED' using errcode = '28000'; end if;
  if p_request_id is null or p_action is null or p_action !~ '^[a-z0-9_]{2,40}$' then
    raise exception 'INVALID_ECONOMY_REQUEST';
  end if;
  if abs(coalesce(p_delta_budget,0)) > 1000000 or abs(coalesce(p_delta_gold,0)) > 1000000
     or abs(coalesce(p_delta_scout,0)) > 1000000 or abs(coalesce(p_delta_training,0)) > 100000 then
    raise exception 'ECONOMY_DELTA_TOO_LARGE';
  end if;
  if coalesce((select auth.jwt()->>'role'),'') <> 'service_role' and (
      p_action not in ('sign_player','trade_fee','scout_purchase','scout_refresh','training')
      or p_delta_budget > 0 or p_delta_gold > 0 or p_delta_scout > 0 or p_delta_training > 0
    ) then
    raise exception 'CLIENT_REWARD_FORBIDDEN';
  end if;
  perform pg_advisory_xact_lock(hashtextextended(uid::text || ':economy', 0));
  select * into prior from tb_economy_private.ledger where owner_id = uid and request_id = p_request_id;
  if found then return jsonb_build_object('ok', true, 'replayed', true, 'balance', prior.balance_after); end if;
  select * into account from public.godot_economy_accounts where owner_id = uid for update;
  if not found then
    insert into public.godot_economy_accounts(owner_id) values (uid) returning * into account;
  end if;
  next_budget := account.budget_million + coalesce(p_delta_budget,0);
  next_gold := account.gold + coalesce(p_delta_gold,0);
  next_scout := account.scout_points + coalesce(p_delta_scout,0);
  next_training := account.training_points + coalesce(p_delta_training,0);
  if next_budget < 0 or next_gold < 0 or next_scout < 0 or next_training < 0 then
    raise exception 'INSUFFICIENT_FUNDS';
  end if;
  result := jsonb_build_object('budget_million',next_budget,'gold',next_gold,'scout_points',next_scout,'training_points',next_training);
  update public.godot_economy_accounts set budget_million=next_budget, gold=next_gold,
    scout_points=next_scout, training_points=next_training, version=version+1, updated_at=clock_timestamp()
    where owner_id=uid;
  insert into tb_economy_private.ledger(owner_id,request_id,action,delta_budget,delta_gold,delta_scout,delta_training,balance_after)
    values(uid,p_request_id,p_action,coalesce(p_delta_budget,0),coalesce(p_delta_gold,0),coalesce(p_delta_scout,0),coalesce(p_delta_training,0),result);
  return jsonb_build_object('ok',true,'replayed',false,'balance',result);
end;
$$;

create or replace function public.godot_economy_apply(
  p_action text, p_request_id uuid, p_delta_budget integer default 0, p_delta_gold integer default 0,
  p_delta_scout integer default 0, p_delta_training integer default 0
) returns jsonb language sql security definer set search_path = '' as $$
  select tb_economy_private.apply_transaction(p_action,p_request_id,p_delta_budget,p_delta_gold,p_delta_scout,p_delta_training);
$$;
revoke all on function public.godot_economy_apply(text,uuid,integer,integer,integer,integer) from public, anon;
grant execute on function public.godot_economy_apply(text,uuid,integer,integer,integer,integer) to authenticated;
revoke all on function tb_economy_private.apply_transaction(text,uuid,integer,integer,integer,integer) from public, anon, authenticated;

create table if not exists tb_economy_private.verified_purchases (
  owner_id uuid not null references auth.users(id) on delete cascade,
  store text not null check (store in ('apple','google')),
  transaction_id text not null,
  product_id text not null,
  status text not null check (status in ('verified','refunded','revoked')),
  raw_receipt_hash text,
  verified_at timestamptz not null default clock_timestamp(),
  primary key(store, transaction_id)
);
revoke all on tb_economy_private.verified_purchases from public, anon, authenticated;

create table if not exists public.godot_release_config (
  platform text primary key check (platform in ('android','ios','web','all')),
  minimum_version text not null default '0.9.3',
  maintenance boolean not null default false,
  message text not null default '',
  updated_at timestamptz not null default clock_timestamp()
);
alter table public.godot_release_config enable row level security;
drop policy if exists "release config public read" on public.godot_release_config;
create policy "release config public read" on public.godot_release_config for select using (true);
revoke insert, update, delete on public.godot_release_config from anon, authenticated;
insert into public.godot_release_config(platform,minimum_version) values
  ('android','0.9.3'),('ios','0.9.3'),('web','0.9.3'),('all','0.9.3')
on conflict (platform) do nothing;

-- One-time, non-destructive backfill from the existing authoritative save.
-- It only creates a missing account row; it never overwrites a server ledger.
create or replace function tb_economy_private.safe_int(v text, fallback integer)
returns integer language plpgsql immutable security definer set search_path = '' as $$
begin
  if v is null or v !~ '^-?[0-9]+$' then return fallback; end if;
  return greatest(-2147483648, least(2147483647, v::numeric::integer));
end;
$$;
revoke all on function tb_economy_private.safe_int(text,integer) from public, anon, authenticated;
insert into public.godot_economy_accounts(owner_id,budget_million,gold,scout_points,training_points)
select distinct on (s.owner_id)
  s.owner_id,
  greatest(0, tb_economy_private.safe_int(s.save_json->>'budget_million',300)),
  greatest(0, tb_economy_private.safe_int(s.save_json->>'gold',100)),
  greatest(0, tb_economy_private.safe_int(s.save_json->>'scout_points',20)),
  greatest(0, tb_economy_private.safe_int(s.save_json->>'training_points',2))
from public.godot_club_slots s
where jsonb_typeof(s.save_json)='object'
  and not exists (select 1 from public.godot_economy_accounts a where a.owner_id=s.owner_id)
order by s.owner_id, s.updated_at desc, s.slot asc
on conflict (owner_id) do nothing;

create or replace function public.godot_economy_bootstrap()
returns jsonb language plpgsql security definer set search_path = '' as $$
declare uid uuid := auth.uid(); row public.godot_economy_accounts;
begin
  if uid is null then raise exception 'LOGIN_REQUIRED' using errcode='28000'; end if;
  select * into row from public.godot_economy_accounts where owner_id=uid;
  if not found then
    insert into public.godot_economy_accounts(owner_id,budget_million,gold,scout_points,training_points)
    select uid,
      greatest(0,tb_economy_private.safe_int(s.save_json->>'budget_million',300)),
      greatest(0,tb_economy_private.safe_int(s.save_json->>'gold',100)),
      greatest(0,tb_economy_private.safe_int(s.save_json->>'scout_points',20)),
      greatest(0,tb_economy_private.safe_int(s.save_json->>'training_points',2))
    from public.godot_club_slots s where s.owner_id=uid
    order by s.updated_at desc, s.slot asc limit 1
    on conflict (owner_id) do nothing;
    select * into row from public.godot_economy_accounts where owner_id=uid;
  end if;
  return jsonb_build_object('budget_million',row.budget_million,'gold',row.gold,
    'scout_points',row.scout_points,'training_points',row.training_points,'version',row.version);
end;
$$;
revoke all on function public.godot_economy_bootstrap() from public, anon;
grant execute on function public.godot_economy_bootstrap() to authenticated;

-- Match settlement envelope. The client reports only the completed match
-- outcome; the server enforces the reward envelope and idempotency.
create table if not exists tb_economy_private.match_settlements (
  owner_id uuid not null references auth.users(id) on delete cascade,
  match_id uuid not null,
  won boolean not null,
  league text not null check (league in ('SBL','PLG','TPBL','extra')),
  budget integer not null,
  gold integer not null,
  scout integer not null,
  training integer not null,
  created_at timestamptz not null default clock_timestamp(),
  primary key(owner_id, match_id)
);
alter table tb_economy_private.match_settlements enable row level security;
revoke all on tb_economy_private.match_settlements from public, anon, authenticated;

create or replace function public.godot_match_settle(
  p_match_id uuid, p_won boolean, p_league text, p_budget integer,
  p_gold integer default 0, p_scout integer default 0, p_training integer default 0
) returns jsonb language plpgsql security definer set search_path = '' as $$
declare uid uuid := auth.uid(); a public.godot_economy_accounts; old tb_economy_private.match_settlements;
declare b integer; g integer; s integer; t integer; reward_budget integer; reward_gold integer; reward_scout integer; reward_training integer; result jsonb;
begin
  if uid is null then raise exception 'LOGIN_REQUIRED' using errcode='28000'; end if;
  if p_match_id is null or p_league not in ('SBL','PLG','TPBL','extra') then raise exception 'INVALID_MATCH'; end if;
  -- Never trust reward values supplied by a client.  Keep the arguments for
  -- backwards-compatible RPC calls, but derive the canonical envelope here.
  if p_won then
    reward_budget := 20;
    reward_gold := 5 + mod(abs(hashtextextended(p_match_id::text, 0)), 6);
    reward_scout := 1 + mod(abs(hashtextextended(p_match_id::text || ':scout', 0)), 3);
    reward_training := 1;
  else
    reward_budget := 10;
    reward_gold := 0;
    reward_scout := 0;
    reward_training := 0;
  end if;
  perform pg_advisory_xact_lock(hashtextextended(uid::text || ':match:' || p_match_id::text,0));
  select * into old from tb_economy_private.match_settlements where owner_id=uid and match_id=p_match_id;
  if found then
    select * into a from public.godot_economy_accounts where owner_id=uid;
    return jsonb_build_object('ok',true,'replayed',true,'balance',jsonb_build_object('budget_million',a.budget_million,'gold',a.gold,'scout_points',a.scout_points,'training_points',a.training_points));
  end if;
  select * into a from public.godot_economy_accounts where owner_id=uid for update;
  if not found then insert into public.godot_economy_accounts(owner_id) values(uid) returning * into a; end if;
  b:=a.budget_million+reward_budget; g:=a.gold+reward_gold; s:=a.scout_points+reward_scout; t:=a.training_points+reward_training;
  update public.godot_economy_accounts set budget_million=b,gold=g,scout_points=s,training_points=t,version=version+1,updated_at=clock_timestamp() where owner_id=uid;
  result:=jsonb_build_object('budget_million',b,'gold',g,'scout_points',s,'training_points',t);
  insert into tb_economy_private.match_settlements(owner_id,match_id,won,league,budget,gold,scout,training) values(uid,p_match_id,p_won,p_league,reward_budget,reward_gold,reward_scout,reward_training);
  return jsonb_build_object('ok',true,'replayed',false,'balance',result);
end;
$$;
revoke all on function public.godot_match_settle(uuid,boolean,text,integer,integer,integer,integer) from public, anon;
grant execute on function public.godot_match_settle(uuid,boolean,text,integer,integer,integer,integer) to authenticated;
