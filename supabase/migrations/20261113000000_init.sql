-- Life RPG — initial schema.
--
-- Security model
--   * Every table is protected by Row Level Security: a user only ever sees
--     and changes their own rows (user_id = auth.uid()).
--   * Mutable data (character, quests, rewards, journal…) is written directly
--     by the client under RLS.
--   * The ledger (XP, Gold, completions, purchases, achievements) has NO
--     insert/update policies. It is written only through `sync_ledger`, a
--     SECURITY DEFINER function that validates amounts, ownership, balances
--     and one-time rewards. Editing the client cannot mint XP or Gold.
--   * Ledger row ids are deterministic on the client (UUID v5), so retries and
--     two offline devices never double-award: duplicates hit the primary key.

-- ───────────────────────────── catalogs ─────────────────────────────

create table public.skills (
  id text primary key,
  attribute text not null,
  tier int not null check (tier between 1 and 5),
  cost int not null check (cost > 0),
  required_level int not null,
  requires text[] not null default '{}',
  required_achievement text
);

create table public.achievements (
  id text primary key,
  rarity text not null check (rarity in ('common','rare','epic','legendary')),
  xp int not null,
  gold int not null
);

-- ───────────────────────────── player data ─────────────────────────────

create table public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  created_at timestamptz not null default now()
);

create table public.characters (
  id uuid primary key,
  user_id uuid not null unique references auth.users (id) on delete cascade,
  name text not null check (char_length(name) between 1 and 32),
  avatar_id text not null,
  avatar_color int not null default 0,
  gender text,
  age int check (age is null or age between 5 and 120),
  class_id text not null,
  focus jsonb not null default '[]',
  goals jsonb not null default '[]',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.user_settings (
  user_id uuid primary key references auth.users (id) on delete cascade,
  data jsonb not null default '{}',
  updated_at timestamptz not null default now()
);

create table public.quests (
  id uuid primary key,
  user_id uuid not null references auth.users (id) on delete cascade,
  title text not null check (char_length(title) between 1 and 120),
  description text not null default '',
  type text not null check (type in ('daily','weekly','main','side','boss')),
  attribute text not null check (attribute in ('physique','intelligence','discipline','career','finance','social','mental')),
  difficulty text not null check (difficulty in ('easy','normal','hard','epic')),
  xp_reward int not null check (xp_reward between 1 and 400),
  custom_xp boolean not null default false,
  recurrence jsonb not null default '{}',
  start_day date not null,
  due_day date,
  duration_minutes int check (duration_minutes is null or duration_minutes between 1 and 1440),
  reminder_time text,
  target_amount int not null default 1 check (target_amount between 1 and 100000000),
  unit text not null default 'none',
  status text not null default 'active' check (status in ('active','completed','failed','paused','archived')),
  subtasks jsonb not null default '[]',
  is_recovery boolean not null default false,
  penalty_id uuid,
  completed_at timestamptz,
  failed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted boolean not null default false
);
create index quests_user_idx on public.quests (user_id, updated_at);

-- "Missions" are quests of type main/boss; a view keeps one source of truth.
create view public.missions with (security_invoker = true) as
  select * from public.quests where type in ('main','boss');

create table public.quest_progress (
  id uuid primary key,
  user_id uuid not null references auth.users (id) on delete cascade,
  quest_id uuid not null references public.quests (id) on delete cascade,
  period_key text not null,
  day_key date not null,
  amount int not null check (amount between -100000000 and 1000000),
  unit text not null default 'none',
  logged_at timestamptz not null default now()
);
create index quest_progress_user_idx on public.quest_progress (user_id, quest_id, period_key);

create table public.quest_completions (
  id uuid primary key,
  user_id uuid not null references auth.users (id) on delete cascade,
  quest_id uuid not null references public.quests (id) on delete cascade,
  period_key text not null,
  day_key date not null,
  completed_at timestamptz not null,
  xp int not null check (xp >= 0),
  gold int not null check (gold >= 0),
  attribute text not null,
  quest_type text not null,
  duration_minutes int,
  reverted_at timestamptz
);
-- One active completion per quest and period: no double rewards.
create unique index quest_completions_once
  on public.quest_completions (quest_id, period_key) where reverted_at is null;
create index quest_completions_user_idx on public.quest_completions (user_id, day_key);

create table public.xp_transactions (
  id uuid primary key,
  user_id uuid not null references auth.users (id) on delete cascade,
  amount int not null,
  attribute text,
  source text not null,
  source_id text,
  note text not null default '',
  day_key date not null,
  created_at timestamptz not null default now()
);
create index xp_transactions_user_idx on public.xp_transactions (user_id, day_key);
create index xp_transactions_source_idx on public.xp_transactions (user_id, source, source_id);

create table public.gold_transactions (
  id uuid primary key,
  user_id uuid not null references auth.users (id) on delete cascade,
  amount int not null,
  source text not null,
  source_id text,
  note text not null default '',
  day_key date not null,
  created_at timestamptz not null default now()
);
create index gold_transactions_user_idx on public.gold_transactions (user_id, day_key);
create index gold_transactions_source_idx on public.gold_transactions (user_id, source, source_id);

-- Attribute XP is derived from the ledger (never stored twice).
create view public.attributes with (security_invoker = true) as
  select user_id, attribute, sum(amount)::int as xp
  from public.xp_transactions
  where attribute is not null
  group by user_id, attribute;

create table public.penalties (
  id uuid primary key,
  user_id uuid not null references auth.users (id) on delete cascade,
  kind text not null,
  severity text not null check (severity in ('light','medium','severe')),
  title text not null,
  quest_id uuid,
  period_key text,
  day_key date not null,
  status text not null default 'open' check (status in ('open','recovered','excused','rescheduled')),
  created_at timestamptz not null default now(),
  resolved_at timestamptz,
  recovery_quest_id uuid,
  gold_lost int not null default 0 check (gold_lost >= 0),
  xp_lost int not null default 0 check (xp_lost >= 0),
  bonus_blocked_until date
);
create index penalties_user_idx on public.penalties (user_id, day_key);

create table public.rewards (
  id uuid primary key,
  user_id uuid not null references auth.users (id) on delete cascade,
  title text not null check (char_length(title) between 1 and 80),
  description text not null default '',
  cost int not null check (cost between 1 and 1000000),
  icon text not null default 'gift',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted boolean not null default false
);
create index rewards_user_idx on public.rewards (user_id);

create table public.reward_purchases (
  id uuid primary key,
  user_id uuid not null references auth.users (id) on delete cascade,
  reward_id uuid not null references public.rewards (id) on delete cascade,
  reward_title text not null,
  cost int not null check (cost > 0),
  purchased_at timestamptz not null,
  refunded_at timestamptz
);
create index reward_purchases_user_idx on public.reward_purchases (user_id, purchased_at);

create table public.journal_entries (
  id uuid primary key,
  user_id uuid not null references auth.users (id) on delete cascade,
  day_key date not null,
  wins text not null default '',
  fails text not null default '',
  learned text not null default '',
  improve text not null default '',
  day_notes text not null default '',
  tomorrow text not null default '',
  rating int check (rating is null or rating between 1 and 10),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted boolean not null default false,
  unique (user_id, day_key)
);

create table public.user_skills (
  user_id uuid not null references auth.users (id) on delete cascade,
  skill_id text not null references public.skills (id),
  unlocked_at timestamptz not null default now(),
  cost int not null,
  primary key (user_id, skill_id)
);

create table public.user_achievements (
  user_id uuid not null references auth.users (id) on delete cascade,
  achievement_id text not null references public.achievements (id),
  unlocked_at timestamptz not null default now(),
  primary key (user_id, achievement_id)
);

-- Rest days and streak freezes (days that keep a streak alive).
create table public.streaks (
  user_id uuid not null references auth.users (id) on delete cascade,
  day_key date not null,
  kind text not null check (kind in ('rest','freeze')),
  created_at timestamptz not null default now(),
  primary key (user_id, day_key)
);

-- ───────────────────────────── RLS ─────────────────────────────

alter table public.skills enable row level security;
alter table public.achievements enable row level security;
create policy "catalog readable" on public.skills for select to authenticated using (true);
create policy "catalog readable" on public.achievements for select to authenticated using (true);

alter table public.profiles enable row level security;
create policy "own profile" on public.profiles for select to authenticated using (id = auth.uid());

do $$
declare t text;
begin
  -- Directly writable by the owner.
  foreach t in array array['characters','user_settings','quests','quest_progress','penalties',
                           'rewards','journal_entries','user_skills','streaks'] loop
    execute format('alter table public.%I enable row level security', t);
    execute format('create policy "own rows select" on public.%I for select to authenticated using (user_id = auth.uid())', t);
    execute format('create policy "own rows insert" on public.%I for insert to authenticated with check (user_id = auth.uid())', t);
    execute format('create policy "own rows update" on public.%I for update to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid())', t);
    execute format('create policy "own rows delete" on public.%I for delete to authenticated using (user_id = auth.uid())', t);
  end loop;
  -- Ledger: read-only for the owner; writes only via sync_ledger().
  foreach t in array array['quest_completions','xp_transactions','gold_transactions',
                           'reward_purchases','user_achievements'] loop
    execute format('alter table public.%I enable row level security', t);
    execute format('create policy "own rows select" on public.%I for select to authenticated using (user_id = auth.uid())', t);
  end loop;
end $$;

-- ───────────────────────────── game rules (server side) ─────────────────────────────

-- Mirrors GameConfig: XP to go from `lvl` to `lvl + 1` is base + lvl × per.
create or replace function public.level_from_xp(total int, base int, per int)
returns int language plpgsql immutable as $$
declare lvl int := 1; rest int := greatest(total, 0);
begin
  while lvl < 10000 and rest >= base + lvl * per loop
    rest := rest - (base + lvl * per);
    lvl := lvl + 1;
  end loop;
  return lvl;
end $$;

create or replace function public.user_level(uid uuid)
returns int language sql stable security definer set search_path = public as $$
  select public.level_from_xp(coalesce(sum(amount), 0)::int, 100, 50)
  from xp_transactions where user_id = uid;
$$;

-- Skill points: 1 per character level and 1 per attribute level above 1.
create or replace function public.user_skill_points(uid uuid)
returns int language sql stable security definer set search_path = public as $$
  select (public.user_level(uid) - 1)
       + coalesce((select sum(public.level_from_xp(greatest(xp, 0), 50, 25) - 1)
                   from (select sum(amount)::int as xp from xp_transactions
                         where user_id = uid and attribute is not null
                         group by attribute) a), 0)::int;
$$;

-- Upper bound of XP one completion may pay: custom ×1.5, player multiplier
-- ×2, streak/focus/skill bonuses ×1.45 and the discipline share ×1.25.
create or replace function public.quest_xp_cap(q_type text, q_difficulty text)
returns int language sql immutable as $$
  select ceil(
    (case when q_type in ('main','boss')
          then case q_difficulty when 'easy' then 100 when 'normal' then 150 when 'hard' then 200 else 250 end
          else case q_difficulty when 'easy' then 10 when 'normal' then 20 when 'hard' then 40 else 70 end
     end) * 1.5 * 2.0 * 1.45 * 1.25)::int + 1;
$$;

-- Skill unlocks are checked against the server-side ledger.
create or replace function public.check_skill_unlock()
returns trigger language plpgsql security definer set search_path = public as $$
declare s skills; spent int;
begin
  select * into s from skills where id = new.skill_id;
  if not found then raise exception 'unknown skill %', new.skill_id; end if;
  new.cost := s.cost;
  select coalesce(sum(cost), 0) into spent
    from user_skills where user_id = new.user_id and skill_id <> new.skill_id;
  if spent + s.cost > public.user_skill_points(new.user_id) then
    raise exception 'not enough skill points';
  end if;
  if exists (select 1 from unnest(s.requires) req
             where not exists (select 1 from user_skills u
                               where u.user_id = new.user_id and u.skill_id = req)) then
    raise exception 'prerequisite skill missing';
  end if;
  return new;
end $$;
create trigger user_skills_check before insert on public.user_skills
  for each row execute function public.check_skill_unlock();

-- The single entry point for ledger writes. Idempotent: replaying the same
-- row is a no-op. Raises (SQLSTATE P0001) when a row breaks the rules; the
-- client parks such rows instead of retrying forever.
create or replace function public.sync_ledger(p_table text, p_row jsonb)
returns void language plpgsql security definer set search_path = public as $$
declare
  uid uuid := auth.uid();
  rid uuid;
  amt int := coalesce((p_row->>'amount')::int, 0);
  src text := p_row->>'source';
  sid text := p_row->>'source_id';
  q quests;
  c quest_completions;
  r rewards;
  p reward_purchases;
  a achievements;
  paid int;
  lvl int;
begin
  if uid is null then raise exception 'not authenticated'; end if;

  if p_table = 'user_achievements' then
    select * into a from achievements where id = p_row->>'achievement_id';
    if not found then raise exception 'unknown achievement'; end if;
    insert into user_achievements (user_id, achievement_id, unlocked_at)
    values (uid, a.id, coalesce((p_row->>'unlocked_at')::timestamptz, now()))
    on conflict do nothing;
    return;
  end if;

  rid := (p_row->>'id')::uuid;

  if p_table = 'quest_completions' then
    select * into c from quest_completions where id = rid;
    if found then
      if c.user_id <> uid then raise exception 'forbidden'; end if;
      -- The only allowed change: marking a completion as reverted.
      if c.reverted_at is null and p_row->>'reverted_at' is not null then
        update quest_completions set reverted_at = (p_row->>'reverted_at')::timestamptz where id = rid;
      end if;
      return;
    end if;
    select * into q from quests where id = (p_row->>'quest_id')::uuid and user_id = uid;
    if not found then raise exception 'quest not found'; end if;
    if (p_row->>'xp')::int > public.quest_xp_cap(q.type, q.difficulty) then
      raise exception 'xp above cap';
    end if;
    if (p_row->>'gold')::int > 300 then raise exception 'gold above cap'; end if;
    insert into quest_completions (id, user_id, quest_id, period_key, day_key, completed_at, xp, gold,
                                   attribute, quest_type, duration_minutes, reverted_at)
    values (rid, uid, q.id, p_row->>'period_key', (p_row->>'day_key')::date,
            (p_row->>'completed_at')::timestamptz, (p_row->>'xp')::int, (p_row->>'gold')::int,
            q.attribute, q.type, (p_row->>'duration_minutes')::int,
            (p_row->>'reverted_at')::timestamptz);
    return;
  end if;

  if p_table = 'reward_purchases' then
    select * into p from reward_purchases where id = rid;
    if found then
      if p.user_id <> uid then raise exception 'forbidden'; end if;
      if p.refunded_at is null and p_row->>'refunded_at' is not null then
        update reward_purchases set refunded_at = (p_row->>'refunded_at')::timestamptz where id = rid;
      end if;
      return;
    end if;
    select * into r from rewards where id = (p_row->>'reward_id')::uuid and user_id = uid;
    if not found then raise exception 'reward not found'; end if;
    if (p_row->>'cost')::int <> r.cost then raise exception 'cost mismatch'; end if;
    if (select coalesce(sum(amount), 0) from gold_transactions where user_id = uid) < r.cost then
      raise exception 'not enough gold';
    end if;
    insert into reward_purchases (id, user_id, reward_id, reward_title, cost, purchased_at, refunded_at)
    values (rid, uid, r.id, r.title, r.cost, (p_row->>'purchased_at')::timestamptz,
            (p_row->>'refunded_at')::timestamptz);
    return;
  end if;

  if p_table = 'xp_transactions' then
    if exists (select 1 from xp_transactions where id = rid) then return; end if;
    case src
      when 'quest', 'discipline' then
        select * into c from quest_completions where id = sid::uuid and user_id = uid;
        if not found then raise exception 'completion not found'; end if;
        select coalesce(sum(amount), 0) into paid from xp_transactions
          where user_id = uid and source in ('quest','discipline') and source_id = sid;
        if amt < 0 or paid + amt > c.xp then raise exception 'xp above completion'; end if;
      when 'revert' then
        if amt > 0 then raise exception 'revert must be negative'; end if;
      when 'subtask' then
        if amt > 5 or amt < 0 or exists (select 1 from xp_transactions
            where user_id = uid and source = 'subtask' and source_id = sid) then
          raise exception 'invalid subtask xp';
        end if;
      when 'bossCheckIn' then
        if amt > 5 or amt < 0 or exists (select 1 from xp_transactions
            where user_id = uid and source = 'bossCheckIn' and source_id = sid
              and day_key = (p_row->>'day_key')::date) then
          raise exception 'invalid check-in xp';
        end if;
      when 'dailyClear' then
        if amt > 25 or amt < 0 or exists (select 1 from xp_transactions
            where user_id = uid and source = 'dailyClear' and day_key = (p_row->>'day_key')::date) then
          raise exception 'invalid daily clear xp';
        end if;
      when 'achievement' then
        select * into a from achievements where id = sid;
        if not found or amt <> a.xp or exists (select 1 from xp_transactions
            where user_id = uid and source = 'achievement' and source_id = sid) then
          raise exception 'invalid achievement xp';
        end if;
      when 'penalty' then
        -- Losses are always allowed; a refund may only return what was lost.
        if amt > 0 and (select coalesce(sum(amount), 0) from xp_transactions
            where user_id = uid and source = 'penalty' and source_id = sid) + amt > 0 then
          raise exception 'invalid penalty refund';
        end if;
      else
        raise exception 'unknown xp source %', src;
    end case;
    insert into xp_transactions (id, user_id, amount, attribute, source, source_id, note, day_key, created_at)
    values (rid, uid, amt, p_row->>'attribute', src, sid, coalesce(p_row->>'note', ''),
            (p_row->>'day_key')::date, coalesce((p_row->>'created_at')::timestamptz, now()));
    return;
  end if;

  if p_table = 'gold_transactions' then
    if exists (select 1 from gold_transactions where id = rid) then return; end if;
    case src
      when 'quest' then
        select * into c from quest_completions where id = sid::uuid and user_id = uid;
        if not found or amt < 0 or amt > c.gold or exists (select 1 from gold_transactions
            where user_id = uid and source = 'quest' and source_id = sid) then
          raise exception 'invalid quest gold';
        end if;
      when 'revert' then
        if amt > 0 then raise exception 'revert must be negative'; end if;
      when 'dailyClear' then
        if amt > 10 or amt < 0 or exists (select 1 from gold_transactions
            where user_id = uid and source = 'dailyClear' and day_key = (p_row->>'day_key')::date) then
          raise exception 'invalid daily clear gold';
        end if;
      when 'achievement' then
        select * into a from achievements where id = sid;
        if not found or amt <> a.gold or exists (select 1 from gold_transactions
            where user_id = uid and source = 'achievement' and source_id = sid) then
          raise exception 'invalid achievement gold';
        end if;
      when 'levelReward' then
        lvl := sid::int;
        if lvl < 2 or lvl > public.user_level(uid) or amt <> 50 + lvl * 10
           or exists (select 1 from gold_transactions
                      where user_id = uid and source = 'levelReward' and source_id = sid) then
          raise exception 'invalid level reward';
        end if;
      when 'purchase' then
        select * into p from reward_purchases where id = sid::uuid and user_id = uid;
        if not found or amt <> -p.cost then raise exception 'invalid purchase gold'; end if;
      when 'refund' then
        select * into p from reward_purchases where id = sid::uuid and user_id = uid;
        if not found or p.refunded_at is null or amt <> p.cost or exists (select 1 from gold_transactions
            where user_id = uid and source = 'refund' and source_id = sid) then
          raise exception 'invalid refund';
        end if;
      when 'penalty' then
        if amt > 0 and (select coalesce(sum(amount), 0) from gold_transactions
            where user_id = uid and source = 'penalty' and source_id = sid) + amt > 0 then
          raise exception 'invalid penalty refund';
        end if;
      else
        raise exception 'unknown gold source %', src;
    end case;
    insert into gold_transactions (id, user_id, amount, source, source_id, note, day_key, created_at)
    values (rid, uid, amt, src, sid, coalesce(p_row->>'note', ''),
            (p_row->>'day_key')::date, coalesce((p_row->>'created_at')::timestamptz, now()));
    return;
  end if;

  raise exception 'unknown ledger table %', p_table;
end $$;

revoke all on function public.sync_ledger(text, jsonb) from public, anon;
grant execute on function public.sync_ledger(text, jsonb) to authenticated;

-- Account deletion removes the auth user; every table cascades.
create or replace function public.delete_my_account()
returns void language plpgsql security definer set search_path = public, auth as $$
begin
  if auth.uid() is null then raise exception 'not authenticated'; end if;
  delete from auth.users where id = auth.uid();
end $$;
revoke all on function public.delete_my_account() from public, anon;
grant execute on function public.delete_my_account() to authenticated;

-- Profile row for every new account.
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  insert into public.profiles (id) values (new.id) on conflict do nothing;
  return new;
end $$;
create trigger on_auth_user_created after insert on auth.users
  for each row execute function public.handle_new_user();

-- ───────────────────────────── seeds ─────────────────────────────
-- Generated from lib/core/game/skill_catalog.dart and achievement_catalog.dart.

insert into public.skills (id, attribute, tier, cost, required_level, requires, required_achievement) values
  ('int_basics', 'intelligence', 1, 1, 1, '{}'::text[], null),
  ('int_reading', 'intelligence', 2, 2, 3, array['int_basics']::text[], null),
  ('int_focus', 'intelligence', 2, 2, 3, array['int_basics']::text[], null),
  ('int_languages', 'intelligence', 3, 3, 5, array['int_reading']::text[], null),
  ('int_systems', 'intelligence', 3, 3, 5, array['int_focus']::text[], null),
  ('int_profession', 'intelligence', 4, 4, 8, array['int_languages','int_systems']::text[], null),
  ('int_research', 'intelligence', 4, 4, 8, array['int_systems']::text[], null),
  ('int_expert', 'intelligence', 5, 5, 12, array['int_profession','int_research']::text[], 'bookworm'),
  ('phy_active', 'physique', 1, 1, 1, '{}'::text[], null),
  ('phy_walk', 'physique', 2, 2, 3, array['phy_active']::text[], null),
  ('phy_stretch', 'physique', 2, 2, 3, array['phy_active']::text[], null),
  ('phy_strength', 'physique', 3, 3, 5, array['phy_walk']::text[], null),
  ('phy_endurance', 'physique', 3, 3, 5, array['phy_stretch']::text[], null),
  ('phy_advanced', 'physique', 4, 4, 8, array['phy_strength','phy_endurance']::text[], null),
  ('phy_sport', 'physique', 4, 4, 8, array['phy_endurance']::text[], null),
  ('phy_program', 'physique', 5, 5, 12, array['phy_advanced','phy_sport']::text[], 'workout_20'),
  ('dis_plan', 'discipline', 1, 1, 1, '{}'::text[], null),
  ('dis_routine', 'discipline', 2, 2, 3, array['dis_plan']::text[], null),
  ('dis_nopro', 'discipline', 2, 2, 3, array['dis_plan']::text[], null),
  ('dis_habits', 'discipline', 3, 3, 5, array['dis_routine']::text[], null),
  ('dis_time', 'discipline', 3, 3, 5, array['dis_nopro']::text[], null),
  ('dis_consistency', 'discipline', 4, 4, 8, array['dis_habits','dis_time']::text[], null),
  ('dis_will', 'discipline', 4, 4, 8, array['dis_time']::text[], null),
  ('dis_master', 'discipline', 5, 5, 12, array['dis_consistency','dis_will']::text[], 'streak_30'),
  ('car_tasks', 'career', 1, 1, 1, '{}'::text[], null),
  ('car_tools', 'career', 2, 2, 3, array['car_tasks']::text[], null),
  ('car_projects', 'career', 2, 2, 3, array['car_tasks']::text[], null),
  ('car_skills', 'career', 3, 3, 5, array['car_tools']::text[], null),
  ('car_portfolio', 'career', 3, 3, 5, array['car_projects']::text[], null),
  ('car_lead', 'career', 4, 4, 8, array['car_skills','car_portfolio']::text[], null),
  ('car_network', 'career', 4, 4, 8, array['car_portfolio']::text[], null),
  ('car_master', 'career', 5, 5, 12, array['car_lead','car_network']::text[], 'builder'),
  ('fin_track', 'finance', 1, 1, 1, '{}'::text[], null),
  ('fin_budget', 'finance', 2, 2, 3, array['fin_track']::text[], null),
  ('fin_save', 'finance', 2, 2, 3, array['fin_track']::text[], null),
  ('fin_literacy', 'finance', 3, 3, 5, array['fin_budget']::text[], null),
  ('fin_side', 'finance', 3, 3, 5, array['fin_save']::text[], null),
  ('fin_plan', 'finance', 4, 4, 8, array['fin_literacy','fin_side']::text[], null),
  ('fin_reserve', 'finance', 4, 4, 8, array['fin_side']::text[], null),
  ('fin_master', 'finance', 5, 5, 12, array['fin_plan','fin_reserve']::text[], null),
  ('soc_talk', 'social', 1, 1, 1, '{}'::text[], null),
  ('soc_listen', 'social', 2, 2, 3, array['soc_talk']::text[], null),
  ('soc_meet', 'social', 2, 2, 3, array['soc_talk']::text[], null),
  ('soc_bonds', 'social', 3, 3, 5, array['soc_listen']::text[], null),
  ('soc_speak', 'social', 3, 3, 5, array['soc_meet']::text[], null),
  ('soc_empathy', 'social', 4, 4, 8, array['soc_bonds','soc_speak']::text[], null),
  ('soc_influence', 'social', 4, 4, 8, array['soc_speak']::text[], null),
  ('soc_master', 'social', 5, 5, 12, array['soc_empathy','soc_influence']::text[], null),
  ('men_rest', 'mental', 1, 1, 1, '{}'::text[], null),
  ('men_reflect', 'mental', 2, 2, 3, array['men_rest']::text[], null),
  ('men_mindful', 'mental', 2, 2, 3, array['men_rest']::text[], null),
  ('men_stress', 'mental', 3, 3, 5, array['men_reflect']::text[], null),
  ('men_sleep', 'mental', 3, 3, 5, array['men_mindful']::text[], null),
  ('men_balance', 'mental', 4, 4, 8, array['men_stress','men_sleep']::text[], null),
  ('men_resilience', 'mental', 4, 4, 8, array['men_sleep']::text[], null),
  ('men_master', 'mental', 5, 5, 12, array['men_balance','men_resilience']::text[], 'journal_30');

insert into public.achievements (id, rarity, xp, gold) values
  ('first_step', 'common', 10, 25),
  ('streak_7', 'rare', 30, 75),
  ('streak_30', 'epic', 80, 200),
  ('streak_100', 'legendary', 150, 500),
  ('bookworm', 'rare', 30, 75),
  ('early_bird', 'rare', 30, 75),
  ('builder', 'rare', 30, 75),
  ('boss_slayer', 'epic', 80, 200),
  ('level_10', 'epic', 80, 200),
  ('level_25', 'legendary', 150, 500),
  ('quests_100', 'epic', 80, 200),
  ('workout_20', 'rare', 30, 75),
  ('steps_100k', 'rare', 30, 75),
  ('deep_work', 'epic', 80, 200),
  ('journal_7', 'common', 10, 25),
  ('journal_30', 'rare', 30, 75),
  ('first_reward', 'common', 10, 25),
  ('skills_5', 'common', 10, 25),
  ('harmony', 'epic', 80, 200),
  ('phoenix', 'rare', 30, 75),
  ('rest_day', 'common', 10, 25);
