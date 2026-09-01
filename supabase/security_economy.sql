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
  if uid is null then raise exception 'LOGIN_REQUIRED' using errcode = '28000'; end if;
  if p_request_id is null or p_action is null or p_action !~ '^[a-z0-9_]{2,40}$' then
    raise exception 'INVALID_ECONOMY_REQUEST';
  end if;
  if abs(coalesce(p_delta_budget,0)) > 1000000 or abs(coalesce(p_delta_gold,0)) > 1000000
     or abs(coalesce(p_delta_scout,0)) > 1000000 or abs(coalesce(p_delta_training,0)) > 100000 then
    raise exception 'ECONOMY_DELTA_TOO_LARGE';
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
