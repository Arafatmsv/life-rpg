-- Economy rebalance (2026-11-15).
--
-- Less XP and Gold per action; skill points only from character levels, so
-- the skill tree opens about one cheap skill per day or two of real effort.
-- Mirrors GameConfig in lib/app/config/game_config.dart. Rows earned under
-- the old rules stay as they are.

update public.achievements set
  xp = case rarity when 'common' then 5 when 'rare' then 15 when 'epic' then 40 else 100 end,
  gold = case rarity when 'common' then 10 when 'rare' then 30 when 'epic' then 75 else 200 end;

-- 1 skill point per character level above 1.
create or replace function public.user_skill_points(uid uuid)
returns int language sql stable security definer set search_path = public as $$
  select public.user_level(uid) - 1;
$$;

-- Same function as in the initial migration with the new limits:
-- quest gold <= 100 per completion, daily clear <= 10 XP / 5 Gold,
-- level reward = 20 + level * 5.
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
    if (p_row->>'gold')::int > 100 then raise exception 'gold above cap'; end if;
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
        if amt > 10 or amt < 0 or exists (select 1 from xp_transactions
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
        if amt > 5 or amt < 0 or exists (select 1 from gold_transactions
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
        if lvl < 2 or lvl > public.user_level(uid) or amt <> 20 + lvl * 5
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
