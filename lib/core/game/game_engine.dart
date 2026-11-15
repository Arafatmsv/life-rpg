import 'dart:math' as math;

import 'package:uuid/uuid.dart';

import '../../app/config/game_config.dart';
import '../../data/models/character.dart';
import '../../data/models/enums.dart';
import '../../data/models/game_state.dart';
import '../../data/models/journal_entry.dart';
import '../../data/models/ledger.dart';
import '../../data/models/penalty.dart';
import '../../data/models/progress_marks.dart';
import '../../data/models/quest.dart';
import '../../data/models/reward.dart';
import '../../data/models/user_settings.dart';
import '../errors/game_exception.dart';
import '../utils/day.dart';
import 'achievement_catalog.dart';
import 'game_clock.dart';
import 'game_events.dart';
import 'skill_catalog.dart';
import 'stats.dart';

class GameResult {
  const GameResult(this.state, this.changes, this.events);
  final GameState state;
  final List<EntityChange> changes;
  final List<GameEvent> events;
}

/// Input for character creation.
class CharacterDraft {
  const CharacterDraft({
    required this.name,
    required this.avatarId,
    required this.avatarColor,
    required this.characterClass,
    required this.focus,
    required this.goals,
    this.gender,
    this.age,
  });

  final String name;
  final String avatarId;
  final int avatarColor;
  final String? gender;
  final int? age;
  final CharacterClass characterClass;
  final List<AttributeType> focus;
  final List<String> goals;
}

/// Pure game rules. Every action takes a [GameState] and returns a new one
/// together with the persisted changes and UI events. No I/O happens here,
/// which keeps the rules testable and identical online and offline.
///
/// Ledger ids for one-time rewards are derived deterministically (UUID v5
/// from the character id and the reason), so two offline devices awarding
/// the same level reward produce the same row and the server keeps one.
class GameEngine {
  GameEngine({this.config = const GameConfig(), GameClock? clock})
      : clock = clock ?? GameClock();

  final GameConfig config;
  final GameClock clock;
  static const _uuid = Uuid();

  String newId() => _uuid.v4();

  String today(GameState s) => clock.today(s.settings.tzOffsetMinutes);

  GameSnapshot snapshot(GameState s) => buildSnapshot(s, config, today(s));

  String periodKey(Quest q, String day, int firstDayOfWeek) => switch (q.periodKind) {
        PeriodKind.day => 'd:$day',
        PeriodKind.week => 'w:${weekStartOf(day, firstDayOfWeek)}',
        PeriodKind.once => 'once',
      };

  String currentPeriod(GameState s, Quest q) =>
      periodKey(q, today(s), s.settings.firstDayOfWeek);

  QuestCompletion? completionFor(GameState s, String questId, String period) {
    for (final c in s.completions.values) {
      if (c.questId == questId && c.periodKey == period && c.isActive) return c;
    }
    return null;
  }

  int progressFor(GameState s, String questId, String period) {
    var sum = 0;
    for (final p in s.progress.values) {
      if (p.questId == questId && p.periodKey == period) sum += p.amount;
    }
    return sum < 0 ? 0 : sum;
  }

  /// Whether the quest should be shown as something to do today.
  bool isDueToday(GameState s, Quest q) {
    if (!q.isOpen) return false;
    final t = today(s);
    if (daysBetween(q.startDay, t) < 0) return false;
    if (q.periodKind == PeriodKind.day) return q.recurrence.isScheduledOn(t, q.startDay);
    return true;
  }

  bool isDoneThisPeriod(GameState s, Quest q) =>
      completionFor(s, q.id, currentPeriod(s, q)) != null;

  String _v5(GameState s, String name) =>
      _uuid.v5(s.character?.id ?? Namespace.url.value, name);

  // ───────────────────────────── character ─────────────────────────────

  GameResult createCharacter(GameState s, CharacterDraft d, {List<Quest> starterQuests = const []}) {
    final name = d.name.trim();
    if (name.isEmpty) throw const GameException('Введите имя персонажа');
    if (name.length > 32) throw const GameException('Имя не длиннее 32 символов');
    final now = clock.instant();
    final ch = Character(
      id: newId(),
      name: name,
      avatarId: d.avatarId,
      avatarColor: d.avatarColor,
      gender: d.gender,
      age: d.age,
      characterClass: d.characterClass,
      focus: d.focus.isEmpty ? d.characterClass.defaultFocus : d.focus,
      goals: d.goals.where((g) => g.trim().isNotEmpty).map((g) => g.trim()).toList(),
      createdAt: now,
      updatedAt: now,
    );
    final draft = _Draft(s.copyWith(character: ch));
    draft.change(Tables.characters, ch.id, ch.toJson());
    draft.putSettings(s.settings.copyWith(updatedAt: now));
    for (final q in starterQuests) {
      draft.putQuest(q);
    }
    // The creation day itself is evaluated tomorrow.
    draft.lastEvaluatedDay = addDays(today(draft.base), -1);
    return draft.finish(this);
  }

  GameResult updateCharacter(GameState s, Character Function(Character) edit) {
    final ch = s.character;
    if (ch == null) throw const GameException('Персонаж не создан');
    final next = edit(ch).copyWith(updatedAt: clock.instant());
    if (next.name.trim().isEmpty) throw const GameException('Введите имя персонажа');
    final d = _Draft(s.copyWith(character: next));
    d.change(Tables.characters, next.id, next.toJson());
    return d.finish(this);
  }

  GameResult updateSettings(GameState s, UserSettings Function(UserSettings) edit) {
    final d = _Draft(s);
    d.putSettings(edit(s.settings).copyWith(updatedAt: clock.instant()));
    return d.finish(this);
  }

  // ───────────────────────────── quests ─────────────────────────────

  /// Creates or edits a quest. Editing never touches completions, so a
  /// finished quest can be renamed without paying XP again.
  GameResult saveQuest(GameState s, Quest q) {
    final title = q.title.trim();
    if (title.isEmpty) throw const GameException('Введите название задания');
    if (title.length > 120) throw const GameException('Название слишком длинное');
    final min = config.minCustomXp(q.type, q.difficulty);
    final max = config.maxCustomXp(q.type, q.difficulty);
    final xp = q.customXp
        ? q.xpReward.clamp(min, max)
        : config.defaultXpFor(q.type, q.difficulty);
    if (q.recurrence.kind == RecurrenceKind.weekdays && q.recurrence.weekdays.isEmpty) {
      throw const GameException('Выберите хотя бы один день недели');
    }
    if (q.type == QuestType.boss && q.targetAmount < 2) {
      throw const GameException('Испытание должно длиться минимум 2 дня');
    }
    final existing = s.quests[q.id];
    var next = q.copyWith(
      title: title,
      description: q.description.trim(),
      xpReward: xp,
      recurrence: switch (q.type) {
        QuestType.daily => q.recurrence.kind == RecurrenceKind.none ||
                q.recurrence.kind == RecurrenceKind.weekly
            ? const Recurrence.daily()
            : q.recurrence,
        QuestType.weekly => const Recurrence.weekly(),
        _ => const Recurrence(),
      },
      updatedAt: clock.instant(),
    );
    // A failed one-off quest with a new future deadline becomes active again.
    if (existing != null &&
        existing.status == QuestStatus.failed &&
        next.dueDay != null &&
        daysBetween(today(s), next.dueDay!) >= 0) {
      next = next.copyWith(status: QuestStatus.active, failedAt: () => null);
    }
    final d = _Draft(s);
    d.putQuest(next);
    return d.finish(this);
  }

  GameResult setQuestStatus(GameState s, String id, QuestStatus status) {
    final q = _quest(s, id);
    final d = _Draft(s);
    d.putQuest(q.copyWith(status: status, updatedAt: clock.instant()));
    return d.finish(this);
  }

  GameResult deleteQuest(GameState s, String id) {
    final q = _quest(s, id);
    final d = _Draft(s);
    d.putQuest(q.copyWith(deleted: true, updatedAt: clock.instant()));
    return d.finish(this);
  }

  /// One tap completion for simple quests and missions.
  GameResult completeQuest(GameState s, String id) {
    final q = _quest(s, id);
    _ensureActionable(s, q);
    if (q.usesCheckIns) {
      throw const GameException('Испытание продвигается ежедневными отметками');
    }
    if (q.usesSubtasks && q.subtasks.any((t) => !t.done)) {
      throw const GameException('Сначала завершите все подзадачи');
    }
    final d = _Draft(s);
    final period = currentPeriod(s, q);
    if (q.isMeasured) {
      // Completing a measured quest logs the remaining amount.
      final left = q.targetAmount - progressFor(s, q.id, period);
      if (left > 0) _addProgress(d, q, period, left);
    }
    _awardCompletion(d, q, period);
    return d.finish(this);
  }

  /// Adds measured progress (pages, steps, minutes…). Completes the period
  /// automatically when the target is reached.
  GameResult logProgress(GameState s, String id, int amount) {
    final q = _quest(s, id);
    _ensureActionable(s, q);
    if (amount <= 0) throw const GameException('Введите положительное значение');
    if (amount > 1000000) throw const GameException('Слишком большое значение');
    final period = currentPeriod(s, q);
    final d = _Draft(s);
    _addProgress(d, q, period, amount);
    if (progressFor(d.peek(), q.id, period) >= q.targetAmount) {
      _awardCompletion(d, q, period);
    }
    return d.finish(this);
  }

  /// One check-in per day for boss quests. Each check-in pays a little XP;
  /// the final one completes the boss.
  GameResult checkInBoss(GameState s, String id) {
    final q = _quest(s, id);
    if (!q.isOpen) throw const GameException('Испытание не активно');
    if (!q.usesCheckIns) throw const GameException('Это не испытание');
    final t = today(s);
    final logId = _v5(s, 'checkin:${q.id}:$t');
    if (s.progress.containsKey(logId)) {
      throw const GameException('Сегодня отметка уже есть. Следующая завтра');
    }
    final d = _Draft(s);
    final now = clock.instant();
    d.putProgress(ProgressLog(
      id: logId,
      questId: q.id,
      periodKey: 'once',
      dayKey: t,
      amount: 1,
      unit: MetricUnit.none,
      loggedAt: now,
    ));
    d.addXp(XpTransaction(
      id: _v5(s, 'bossxp:${q.id}:$t'),
      amount: config.bossCheckInXp,
      attribute: q.attribute,
      source: LedgerSource.bossCheckIn,
      sourceId: q.id,
      note: q.title,
      dayKey: t,
      createdAt: now,
    ));
    d.events.add(XpGained(config.bossCheckInXp, q.attribute, 'Шаг испытания'));
    if (progressFor(d.peek(), q.id, 'once') >= q.targetAmount) {
      _awardCompletion(d, q, 'once');
    }
    return d.finish(this);
  }

  GameResult toggleSubtask(GameState s, String questId, String subtaskId) {
    final q = _quest(s, questId);
    if (!q.isOpen) throw const GameException('Миссия не активна');
    final idx = q.subtasks.indexWhere((t) => t.id == subtaskId);
    if (idx < 0) throw const GameException('Подзадача не найдена');
    final st = q.subtasks[idx];
    final d = _Draft(s);
    final nowDone = !st.done;
    var updated = st.copyWith(done: nowDone);
    if (nowDone && !st.rewarded) {
      updated = updated.copyWith(rewarded: true);
      final t = today(s);
      d.addXp(XpTransaction(
        id: _v5(s, 'subtask:${st.id}'),
        amount: config.subtaskXp,
        attribute: q.attribute,
        source: LedgerSource.subtask,
        sourceId: st.id,
        note: st.title,
        dayKey: t,
        createdAt: clock.instant(),
      ));
      d.events.add(XpGained(config.subtaskXp, q.attribute, 'Подзадача'));
    }
    final list = [...q.subtasks]..[idx] = updated;
    d.putQuest(q.copyWith(subtasks: list, updatedAt: clock.instant()));
    return d.finish(this);
  }

  /// Undo a completion made by mistake. Writes compensating ledger entries
  /// instead of deleting history.
  GameResult revertCompletion(GameState s, String completionId) {
    final c = s.completions[completionId];
    if (c == null || !c.isActive) throw const GameException('Выполнение не найдено');
    final now = clock.instant();
    if (now.difference(c.completedAt) > config.revertWindow) {
      throw const GameException('Отменить можно только в течение 24 часов');
    }
    final d = _Draft(s);
    final t = today(s);
    d.putCompletion(c.reverted(now));
    for (final tx in s.xp.values.where((x) => x.sourceId == c.id && x.amount > 0).toList()) {
      d.addXp(XpTransaction(
        id: _v5(s, 'revert:${tx.id}'),
        amount: -tx.amount,
        attribute: tx.attribute,
        source: LedgerSource.revert,
        sourceId: c.id,
        note: tx.note,
        dayKey: t,
        createdAt: now,
      ));
    }
    for (final g in s.gold.values.where((x) => x.sourceId == c.id && x.amount > 0).toList()) {
      d.addGold(GoldTransaction(
        id: _v5(s, 'revert:${g.id}'),
        amount: -g.amount,
        source: LedgerSource.revert,
        sourceId: c.id,
        note: g.note,
        dayKey: t,
        createdAt: now,
      ));
    }
    final q = s.quests[c.questId];
    if (q != null) {
      final progressed = progressFor(s, q.id, c.periodKey);
      if (progressed > 0 && !q.usesCheckIns) {
        d.putProgress(ProgressLog(
          id: newId(),
          questId: q.id,
          periodKey: c.periodKey,
          dayKey: t,
          amount: -progressed,
          unit: q.unit,
          loggedAt: now,
        ));
      }
      if (q.periodKind == PeriodKind.once) {
        d.putQuest(q.copyWith(
          status: QuestStatus.active,
          completedAt: () => null,
          updatedAt: now,
        ));
      }
    }
    _revokeUnearned(d, c, now, t);
    d.events.add(XpGained(-c.xp, c.attribute, 'Отмена выполнения'));
    return d.finish(this);
  }

  /// After an undo, takes back one-time rewards the player no longer
  /// qualifies for: the day-clear bonus of that day, achievements whose
  /// condition is no longer met and Gold for levels above the new level.
  /// They can be earned again later.
  void _revokeUnearned(_Draft d, QuestCompletion c, DateTime now, String t) {
    final q = d.peek().quests[c.questId];
    if (q != null && q.periodKind == PeriodKind.day && !q.isRecovery) {
      _revokeBonus(d, c.dayKey, LedgerSource.dailyClear, now, t, 'Все задания дня');
    }
    // Revoked achievement XP can lower the level, which can un-meet more
    // achievements; repeat until stable.
    for (var i = 0; i < 4; i++) {
      final snap = snapshot(d.peek());
      var changed = false;
      for (final a in achievementCatalog) {
        if (!d.peek().achievements.containsKey(a.id) || a.isMet(snap)) continue;
        d.removeAchievement(a.id);
        _revokeBonus(d, a.id, LedgerSource.achievement, now, t, a.title);
        changed = true;
      }
      if (!changed) break;
    }
    final level = snapshot(d.peek()).level.level;
    final rewarded = d.peek().gold.values
        .where((g) => g.source == LedgerSource.levelReward)
        .map((g) => g.sourceId ?? '')
        .toSet();
    for (final l in rewarded) {
      if ((int.tryParse(l) ?? 0) > level) {
        _revokeBonus(d, l, LedgerSource.levelReward, now, t, 'Уровень $l');
      }
    }
  }

  /// Net amount still held from a one-time reward ([kind] minus reverts).
  int _netXp(GameState s, String sourceId, LedgerSource kind) => s.xp.values
      .where((x) => x.sourceId == sourceId && (x.source == kind || x.source == LedgerSource.revert))
      .fold(0, (sum, x) => sum + x.amount);

  int _netGold(GameState s, String sourceId, LedgerSource kind) => s.gold.values
      .where((x) => x.sourceId == sourceId && (x.source == kind || x.source == LedgerSource.revert))
      .fold(0, (sum, x) => sum + x.amount);

  String _rewardId(GameState s, String base, int n) => _v5(s, n == 0 ? base : '$base:$n');

  void _revokeBonus(_Draft d, String sourceId, LedgerSource kind, DateTime now, String t, String note) {
    final st = d.peek();
    final xp = _netXp(st, sourceId, kind);
    if (xp > 0) {
      final n = st.xp.values.where((x) => x.sourceId == sourceId && x.source == LedgerSource.revert).length;
      d.addXp(XpTransaction(
        id: _v5(st, 'revoke-xp:$sourceId:$n'),
        amount: -xp,
        source: LedgerSource.revert,
        sourceId: sourceId,
        note: note,
        dayKey: t,
        createdAt: now,
      ));
    }
    final gold = _netGold(d.peek(), sourceId, kind);
    if (gold > 0) {
      final n = d.peek().gold.values.where((x) => x.sourceId == sourceId && x.source == LedgerSource.revert).length;
      d.addGold(GoldTransaction(
        id: _v5(st, 'revoke-gold:$sourceId:$n'),
        amount: -gold,
        source: LedgerSource.revert,
        sourceId: sourceId,
        note: note,
        dayKey: t,
        createdAt: now,
      ));
    }
  }

  // ───────────────────────────── rewards ─────────────────────────────

  GameResult saveReward(GameState s, Reward r) {
    if (r.title.trim().isEmpty) throw const GameException('Введите название награды');
    if (r.cost < 1 || r.cost > 1000000) {
      throw const GameException('Стоимость от 1 до 1 000 000 Gold');
    }
    final d = _Draft(s);
    d.putReward(r.copyWith(title: r.title.trim(), updatedAt: clock.instant()));
    return d.finish(this);
  }

  GameResult deleteReward(GameState s, String id) {
    final r = s.rewards[id];
    if (r == null) throw const GameException('Награда не найдена');
    final d = _Draft(s);
    d.putReward(r.copyWith(deleted: true, updatedAt: clock.instant()));
    return d.finish(this);
  }

  GameResult purchaseReward(GameState s, String rewardId) {
    final r = s.rewards[rewardId];
    if (r == null || r.deleted) throw const GameException('Награда не найдена');
    final balance = snapshot(s).gold;
    if (balance < r.cost) {
      throw GameException('Не хватает ${r.cost - balance} Gold');
    }
    final now = clock.instant();
    final p = RewardPurchase(
      id: newId(),
      rewardId: r.id,
      rewardTitle: r.title,
      cost: r.cost,
      purchasedAt: now,
    );
    final d = _Draft(s);
    d.putPurchase(p);
    d.addGold(GoldTransaction(
      id: _v5(s, 'purchase:${p.id}'),
      amount: -r.cost,
      source: LedgerSource.purchase,
      sourceId: p.id,
      note: r.title,
      dayKey: today(s),
      createdAt: now,
    ));
    d.events.add(RewardPurchasedEvent(r));
    d.events.add(GoldChanged(-r.cost, r.title));
    return d.finish(this);
  }

  GameResult refundPurchase(GameState s, String purchaseId) {
    final p = s.purchases[purchaseId];
    if (p == null || p.isRefunded) throw const GameException('Покупка не найдена');
    final now = clock.instant();
    final d = _Draft(s);
    d.putPurchase(p.refunded(now));
    d.addGold(GoldTransaction(
      id: _v5(s, 'refund:${p.id}'),
      amount: p.cost,
      source: LedgerSource.refund,
      sourceId: p.id,
      note: p.rewardTitle,
      dayKey: today(s),
      createdAt: now,
    ));
    d.events.add(GoldChanged(p.cost, 'Возврат: ${p.rewardTitle}'));
    return d.finish(this);
  }

  // ───────────────────────────── skills ─────────────────────────────

  /// Why a skill cannot be unlocked right now, or null if it can.
  String? skillBlocker(GameState s, SkillDef def, [GameSnapshot? snap]) {
    if (s.skills.containsKey(def.id)) return 'Уже открыт';
    final sn = snap ?? snapshot(s);
    final lvl = sn.attributeLevels[def.attribute]!.level;
    if (lvl < def.requiredLevel) {
      return 'Нужен ${def.requiredLevel}-й уровень «${def.attribute.label}»';
    }
    for (final r in def.requires) {
      if (!s.skills.containsKey(r)) return 'Сначала откройте «${skillById[r]?.title ?? r}»';
    }
    final ach = def.requiredAchievement;
    if (ach != null && !s.achievements.containsKey(ach)) {
      return 'Нужно достижение «${achievementById[ach]?.title ?? ach}»';
    }
    if (sn.skillPoints < def.cost) return 'Нужно ${def.cost} SP, есть ${sn.skillPoints}';
    return null;
  }

  GameResult unlockSkill(GameState s, String skillId) {
    final def = skillById[skillId];
    if (def == null) throw const GameException('Навык не найден');
    final blocker = skillBlocker(s, def);
    if (blocker != null) throw GameException(blocker);
    final d = _Draft(s);
    d.putSkill(UnlockedSkill(skillId: def.id, unlockedAt: clock.instant(), cost: def.cost));
    d.events.add(SkillUnlockedEvent(def));
    return d.finish(this);
  }

  // ───────────────────────────── journal ─────────────────────────────

  String journalIdFor(GameState s, String day) => _v5(s, 'journal:$day');

  GameResult saveJournal(GameState s, JournalEntry e) {
    if (e.rating != null && (e.rating! < 1 || e.rating! > 10)) {
      throw const GameException('Оценка дня от 1 до 10');
    }
    if (daysBetween(e.dayKey, today(s)) < 0) {
      throw const GameException('Нельзя писать о будущем дне');
    }
    final d = _Draft(s);
    d.putJournal(e.copyWith(updatedAt: clock.instant()));
    return d.finish(this);
  }

  GameResult deleteJournal(GameState s, String id) {
    final e = s.journal[id];
    if (e == null) throw const GameException('Запись не найдена');
    final d = _Draft(s);
    d.putJournal(e.copyWith(deleted: true, updatedAt: clock.instant()));
    return d.finish(this);
  }

  // ───────────────────────────── rest & streaks ─────────────────────────────

  static const maxRestDaysPerWeek = 2;

  GameResult toggleRestDay(GameState s, String day) {
    final t = today(s);
    if (daysBetween(t, day) < 0) {
      throw const GameException('День отдыха планируется на сегодня или вперёд');
    }
    final existing = s.dayMarks[day];
    final d = _Draft(s);
    if (existing != null) {
      if (existing.kind != DayMarkKind.rest) {
        throw const GameException('Этот день защищён заморозкой');
      }
      d.removeDayMark(day);
      return d.finish(this);
    }
    final ws = weekStartOf(day, s.settings.firstDayOfWeek);
    final inWeek = s.dayMarks.values
        .where((m) =>
            m.kind == DayMarkKind.rest &&
            weekStartOf(m.dayKey, s.settings.firstDayOfWeek) == ws)
        .length;
    if (inWeek >= maxRestDaysPerWeek) {
      throw const GameException('Не больше 2 дней отдыха в неделю');
    }
    d.putDayMark(DayMark(dayKey: day, kind: DayMarkKind.rest, createdAt: clock.instant()));
    return d.finish(this);
  }

  int freezesUsedThisMonth(GameState s) {
    final month = today(s).substring(0, 7);
    return s.dayMarks.values
        .where((m) => m.kind == DayMarkKind.freeze && m.dayKey.startsWith(month))
        .length;
  }

  /// Protects a past missed day so the streak survives.
  GameResult useStreakFreeze(GameState s, String day) {
    if (!s.settings.streakFreezeEnabled) {
      throw const GameException('Заморозка серии выключена в настройках');
    }
    final t = today(s);
    final diff = daysBetween(day, t);
    if (diff < 1 || diff > 7) {
      throw const GameException('Заморозить можно один из последних 7 дней');
    }
    if (s.dayMarks.containsKey(day)) throw const GameException('День уже отмечен');
    if (freezesUsedThisMonth(s) >= s.settings.streakFreezesPerMonth) {
      throw const GameException('Заморозки на этот месяц закончились');
    }
    final d = _Draft(s);
    d.putDayMark(DayMark(dayKey: day, kind: DayMarkKind.freeze, createdAt: clock.instant()));
    return d.finish(this);
  }

  // ───────────────────────────── penalties ─────────────────────────────

  int excusesUsedThisMonth(GameState s) {
    final month = today(s).substring(0, 7);
    final tz = s.settings.tzOffsetMinutes;
    return s.penalties.values
        .where((p) =>
            p.status == PenaltyStatus.excused &&
            p.resolvedAt != null &&
            GameClock.dayOf(p.resolvedAt!, tz).startsWith(month))
        .length;
  }

  /// Marks a penalty as excused and returns lost Gold/XP.
  GameResult excusePenalty(GameState s, String penaltyId) {
    final p = _penalty(s, penaltyId);
    if (excusesUsedThisMonth(s) >= s.settings.recoveryDaysPerMonth) {
      throw const GameException('Лимит уважительных причин на месяц исчерпан');
    }
    final d = _Draft(s);
    final now = clock.instant();
    final t = today(s);
    d.putPenalty(p.resolve(PenaltyStatus.excused, now));
    if (p.goldLost > 0) {
      d.addGold(GoldTransaction(
        id: _v5(s, 'excuse-gold:${p.id}'),
        amount: p.goldLost,
        source: LedgerSource.penalty,
        sourceId: p.id,
        note: 'Возврат: ${p.title}',
        dayKey: t,
        createdAt: now,
      ));
    }
    if (p.xpLost > 0) {
      d.addXp(XpTransaction(
        id: _v5(s, 'excuse-xp:${p.id}'),
        amount: p.xpLost,
        source: LedgerSource.penalty,
        sourceId: p.id,
        note: 'Возврат: ${p.title}',
        dayKey: t,
        createdAt: now,
      ));
    }
    _closeRecoveryQuest(d, p);
    return d.finish(this);
  }

  /// Moves the missed obligation to a new day.
  GameResult reschedulePenalty(GameState s, String penaltyId, String newDay) {
    final p = _penalty(s, penaltyId);
    final t = today(s);
    if (daysBetween(t, newDay) < 0) throw const GameException('Выберите сегодня или позже');
    final d = _Draft(s);
    final now = clock.instant();
    final q = p.questId == null ? null : s.quests[p.questId!];
    if (q != null) {
      if (q.periodKind == PeriodKind.once) {
        d.putQuest(q.copyWith(
          status: QuestStatus.active,
          dueDay: () => newDay,
          failedAt: () => null,
          updatedAt: now,
        ));
      } else {
        // A missed recurring quest becomes a one-off make-up quest.
        d.putQuest(Quest(
          id: newId(),
          title: 'Перенесено: ${q.title}',
          description: q.description,
          type: QuestType.side,
          attribute: q.attribute,
          difficulty: q.difficulty,
          xpReward: config.defaultXpFor(QuestType.side, q.difficulty),
          startDay: t,
          dueDay: newDay,
          durationMinutes: q.durationMinutes,
          targetAmount: q.usesCheckIns ? 1 : q.targetAmount,
          unit: q.unit,
          createdAt: now,
          updatedAt: now,
        ));
      }
    }
    d.putPenalty(p.resolve(PenaltyStatus.rescheduled, now));
    _closeRecoveryQuest(d, p);
    return d.finish(this);
  }

  void _closeRecoveryQuest(_Draft d, PenaltyRecord p) {
    final rq = p.recoveryQuestId == null ? null : d.peek().quests[p.recoveryQuestId!];
    if (rq != null && rq.isOpen) {
      d.putQuest(rq.copyWith(status: QuestStatus.archived, updatedAt: clock.instant()));
    }
  }

  /// Evaluates every finished day since the last run: marks missed quests,
  /// applies the configured consequences and fails overdue one-off quests.
  /// Safe to call repeatedly; penalty ids are deterministic.
  GameResult evaluateDays(GameState s) {
    final ch = s.character;
    final t = today(s);
    if (ch == null) return GameResult(s, const [], const []);
    final yesterday = addDays(t, -1);
    final tz = s.settings.tzOffsetMinutes;
    final created = GameClock.dayOf(ch.createdAt, tz);
    var from = s.lastEvaluatedDay == null ? created : addDays(s.lastEvaluatedDay!, 1);
    from = maxDay(from, addDays(t, -config.maxBackfillDays));
    from = maxDay(from, created);
    final d = _Draft(s);
    if (s.lastEvaluatedDay != yesterday) d.lastEvaluatedDay = yesterday;
    final settings = s.settings;
    final applyPenalties = settings.penaltiesEnabled && settings.missedQuestPenalty;
    final created_ = <PenaltyRecord>[];

    if (daysBetween(from, yesterday) >= 0) {
      for (final day in dayRange(from, yesterday)) {
        final mark = s.dayMarks[day];
        if (settings.vacationMode && mark == null) {
          d.putDayMark(DayMark(dayKey: day, kind: DayMarkKind.rest, createdAt: clock.instant()));
          continue;
        }
        if (mark != null) continue;
        if (!applyPenalties) continue;
        for (final q in s.liveQuests) {
          if (!q.isOpen || q.isRecovery || q.periodKind != PeriodKind.day) continue;
          // Never penalize the day a quest was created on.
          if (daysBetween(GameClock.dayOf(q.createdAt, tz), day) <= 0) continue;
          if (!q.recurrence.isScheduledOn(day, q.startDay)) continue;
          if (completionFor(s, q.id, 'd:$day') != null) continue;
          final p = _applyPenalty(d, q, 'd:$day', day, PenaltyKind.missedQuest);
          if (p != null) created_.add(p);
        }
        // A week ends on this day?
        final ws = weekStartOf(day, settings.firstDayOfWeek);
        if (addDays(ws, 6) == day) {
          final restInWeek = dayRange(ws, day).where((x) => s.dayMarks.containsKey(x)).length;
          if (restInWeek < 4) {
            for (final q in s.liveQuests) {
              if (!q.isOpen || q.isRecovery || q.periodKind != PeriodKind.week) continue;
              if (daysBetween(GameClock.dayOf(q.createdAt, tz), ws) < 0) continue;
              if (completionFor(s, q.id, 'w:$ws') != null) continue;
              final p = _applyPenalty(d, q, 'w:$ws', day, PenaltyKind.missedQuest);
              if (p != null) created_.add(p);
            }
          }
        }
      }
    }

    // Overdue one-off quests fail regardless of the backfill window.
    for (final q in s.liveQuests.toList()) {
      if (!q.isOpen || q.periodKind != PeriodKind.once || q.dueDay == null) continue;
      if (daysBetween(q.dueDay!, t) <= 0) continue;
      d.putQuest(q.copyWith(
        status: QuestStatus.failed,
        failedAt: () => clock.instant(),
        updatedAt: clock.instant(),
      ));
      if (q.isRecovery || !settings.penaltiesEnabled) continue;
      if (s.dayMarks.containsKey(q.dueDay!)) continue;
      final p = _applyPenalty(
        d,
        q,
        'once',
        q.dueDay!,
        q.type.isMission ? PenaltyKind.missionFailed : PenaltyKind.missedQuest,
      );
      if (p != null) created_.add(p);
    }

    // Optional: a broken streak of 3+ days leaves a light mark.
    if (settings.penaltiesEnabled && settings.streakBreakPenalty) {
      final snap = snapshot(d.peek());
      if (snap.streak.brokenYesterday && snap.streak.previousStreak >= 3) {
        final id = _v5(s, 'streakbreak:$yesterday');
        if (!s.penalties.containsKey(id)) {
          final p = PenaltyRecord(
            id: id,
            kind: PenaltyKind.streakBreak,
            severity: Severity.light,
            title: 'Серия ${snap.streak.previousStreak} ${plural(snap.streak.previousStreak, 'день', 'дня', 'дней')} прервана',
            dayKey: yesterday,
            createdAt: clock.instant(),
            bonusBlockedUntil: t,
          );
          d.putPenalty(p);
          created_.add(p);
        }
      }
    }

    if (created_.isNotEmpty) d.events.add(PenaltyAppliedEvent(created_));
    return d.finish(this);
  }

  PenaltyRecord? _applyPenalty(_Draft d, Quest q, String period, String day, PenaltyKind kind) {
    final s = d.peek();
    final id = _v5(s, 'penalty:${q.id}:$period');
    if (s.penalties.containsKey(id)) return null;
    final base = s.settings.consequenceFor(q.type).severity;
    if (base == null) return null;
    final sev = base.shift(s.settings.strictness.severityShift);
    final t = today(s);
    final now = clock.instant();
    final snap = snapshot(s);

    var goldLost = 0;
    if (sev == Severity.severe && s.settings.goldPenaltyEnabled && snap.gold > 0) {
      goldLost = math.min(config.goldPenaltyMax, (snap.gold * config.goldPenaltyShare).round());
    }
    var xpLost = 0;
    if (s.settings.xpPenaltyEnabled) {
      // Never pushes the player below the start of their current level.
      xpLost = math.min(config.xpPenalty[sev]!, snap.level.xpIntoLevel);
    }

    String? recoveryId;
    final openRecovery = s.liveQuests.where((x) => x.isRecovery && x.isOpen).length;
    if (sev != Severity.light && s.settings.allowRecovery && openRecovery < 3) {
      recoveryId = _v5(s, 'recovery:$id');
      d.putQuest(Quest(
        id: recoveryId,
        title: 'Восстановление: ${q.title}',
        description: 'Небольшой шаг, чтобы вернуться в ритм после пропуска.',
        type: QuestType.side,
        attribute: q.attribute,
        difficulty: Difficulty.easy,
        xpReward: config.defaultXpFor(QuestType.side, Difficulty.easy),
        startDay: t,
        dueDay: addDays(t, 3),
        isRecovery: true,
        penaltyId: id,
        createdAt: now,
        updatedAt: now,
      ));
    }

    final p = PenaltyRecord(
      id: id,
      kind: kind,
      severity: sev,
      title: q.title,
      questId: q.id,
      periodKey: period,
      dayKey: day,
      createdAt: now,
      recoveryQuestId: recoveryId,
      goldLost: goldLost,
      xpLost: xpLost,
      bonusBlockedUntil: addDays(t, sev == Severity.light ? 0 : 2),
    );
    d.putPenalty(p);
    if (goldLost > 0) {
      d.addGold(GoldTransaction(
        id: _v5(s, 'penalty-gold:$id'),
        amount: -goldLost,
        source: LedgerSource.penalty,
        sourceId: id,
        note: q.title,
        dayKey: t,
        createdAt: now,
      ));
    }
    if (xpLost > 0) {
      d.addXp(XpTransaction(
        id: _v5(s, 'penalty-xp:$id'),
        amount: -xpLost,
        source: LedgerSource.penalty,
        sourceId: id,
        note: q.title,
        dayKey: t,
        createdAt: now,
      ));
    }
    return p;
  }

  bool streakBonusBlocked(GameState s) {
    final t = today(s);
    return s.penalties.values.any((p) =>
        p.status == PenaltyStatus.open &&
        p.bonusBlockedUntil != null &&
        daysBetween(t, p.bonusBlockedUntil!) >= 0);
  }

  // ───────────────────────────── internals ─────────────────────────────

  Quest _quest(GameState s, String id) {
    final q = s.quests[id];
    if (q == null || q.deleted) throw const GameException('Задание не найдено');
    return q;
  }

  PenaltyRecord _penalty(GameState s, String id) {
    final p = s.penalties[id];
    if (p == null) throw const GameException('Запись не найдена');
    if (p.status.isResolved) throw const GameException('Нарушение уже закрыто');
    return p;
  }

  void _ensureActionable(GameState s, Quest q) {
    if (q.status == QuestStatus.completed) throw const GameException('Задание уже выполнено');
    if (q.status == QuestStatus.failed) {
      throw const GameException('Задание провалено. Перенесите его на новую дату');
    }
    if (!q.isOpen) throw const GameException('Задание не активно');
    if (!isDueToday(s, q)) throw const GameException('Сегодня это задание не запланировано');
    if (completionFor(s, q.id, currentPeriod(s, q)) != null) {
      throw GameException(q.periodKind == PeriodKind.week
          ? 'На этой неделе уже выполнено'
          : q.periodKind == PeriodKind.day
              ? 'Сегодня уже выполнено'
              : 'Задание уже выполнено');
    }
  }

  void _addProgress(_Draft d, Quest q, String period, int amount) {
    d.putProgress(ProgressLog(
      id: newId(),
      questId: q.id,
      periodKey: period,
      dayKey: today(d.peek()),
      amount: amount,
      unit: q.unit,
      loggedAt: clock.instant(),
    ));
  }

  /// Breakdown of the XP a completion would pay right now.
  XpQuote quote(GameState s, Quest q) {
    final snap = snapshot(s);
    final streakBonus = streakBonusBlocked(s)
        ? 0.0
        : math.min(config.streakBonusMax, snap.streak.current * config.streakBonusPerDay);
    final focus = (s.character?.focus.contains(q.attribute) ?? false) ? config.focusBonus : 0.0;
    final skill = skillBonusFor(s, config, q.attribute);
    final mult = s.settings.xpMultiplier;
    final raw = q.xpReward * mult * (1 + streakBonus + focus + skill);
    // Daily soft cap: the part above the cap is paid at a reduced rate.
    final room = math.max(0, config.dailyXpSoftCap - snap.xpToday);
    final full = math.min(raw, room.toDouble());
    final over = raw - full;
    final xp = math.max(1, (full + over * config.overCapFactor).round());
    final disciplineXp = q.isRecurring && q.attribute != AttributeType.discipline
        ? (xp * config.disciplineShare).round()
        : 0;
    final goldRoom = math.max(0, config.dailyQuestGoldCap - snap.questGoldToday);
    final gold = math.min(goldRoom, (xp * config.goldPerXp).round());
    return XpQuote(
      base: q.xpReward,
      multiplier: mult,
      streakBonus: streakBonus,
      focusBonus: focus,
      skillBonus: skill,
      overCap: over > 0,
      xp: xp,
      disciplineXp: disciplineXp,
      gold: gold,
      goldCapped: goldRoom < (xp * config.goldPerXp).round(),
    );
  }

  void _awardCompletion(_Draft d, Quest q, String period) {
    final s = d.peek();
    if (completionFor(s, q.id, period) != null) {
      throw const GameException('Уже выполнено');
    }
    final t = today(s);
    final now = clock.instant();
    final quote = this.quote(s, q);
    final reverts = s.completions.values
        .where((c) => c.questId == q.id && c.periodKey == period && !c.isActive)
        .length;
    final completionId = _v5(s, 'completion:${q.id}:$period:$reverts');
    d.putCompletion(QuestCompletion(
      id: completionId,
      questId: q.id,
      periodKey: period,
      dayKey: t,
      completedAt: now,
      xp: quote.xp + quote.disciplineXp,
      gold: quote.gold,
      attribute: q.attribute,
      questType: q.type,
      durationMinutes: q.durationMinutes,
    ));
    d.addXp(XpTransaction(
      id: _v5(s, 'xp:$completionId'),
      amount: quote.xp,
      attribute: q.attribute,
      source: LedgerSource.quest,
      sourceId: completionId,
      note: '${q.title} · ${quote.describe()}',
      dayKey: t,
      createdAt: now,
    ));
    if (quote.disciplineXp > 0) {
      d.addXp(XpTransaction(
        id: _v5(s, 'xpd:$completionId'),
        amount: quote.disciplineXp,
        attribute: AttributeType.discipline,
        source: LedgerSource.discipline,
        sourceId: completionId,
        note: q.title,
        dayKey: t,
        createdAt: now,
      ));
    }
    if (quote.gold > 0) {
      d.addGold(GoldTransaction(
        id: _v5(s, 'gold:$completionId'),
        amount: quote.gold,
        source: LedgerSource.quest,
        sourceId: completionId,
        note: q.title,
        dayKey: t,
        createdAt: now,
      ));
    }
    if (q.periodKind == PeriodKind.once) {
      d.putQuest(q.copyWith(
        status: QuestStatus.completed,
        completedAt: () => now,
        updatedAt: now,
      ));
    }
    if (q.isRecovery && q.penaltyId != null) {
      final p = d.peek().penalties[q.penaltyId!];
      if (p != null && !p.status.isResolved) d.putPenalty(p.resolve(PenaltyStatus.recovered, now));
    }
    d.events.add(XpGained(quote.xp + quote.disciplineXp, q.attribute, q.title));
    if (quote.gold > 0) d.events.add(GoldChanged(quote.gold, q.title));
    d.events.add(QuestCompletedEvent(q, quote.xp + quote.disciplineXp, quote.gold));
  }

  /// Runs after every action: level rewards, achievements, daily clear.
  void _postProcess(_Draft d, GameSnapshot before) {
    final t = today(d.base);
    final now = clock.instant();
    // Daily clear bonus: every quest scheduled for today is done (min. 2).
    final st = d.peek();
    final dailies = st.liveQuests
        .where((q) => q.periodKind == PeriodKind.day && !q.isRecovery && isDueToday(st, q))
        .toList();
    final clearPaid = st.xp.values.where((x) => x.sourceId == t && x.source == LedgerSource.dailyClear).length;
    final clearId = _rewardId(st, 'dailyclear:$t', clearPaid);
    if (dailies.length >= 2 &&
        _netXp(st, t, LedgerSource.dailyClear) <= 0 &&
        !st.xp.containsKey(clearId) &&
        dailies.every((q) => completionFor(st, q.id, 'd:$t') != null)) {
      d.addXp(XpTransaction(
        id: clearId,
        amount: config.dailyClearXp,
        source: LedgerSource.dailyClear,
        sourceId: t,
        note: 'Все ежедневные задания выполнены',
        dayKey: t,
        createdAt: now,
      ));
      d.addGold(GoldTransaction(
        id: _rewardId(st, 'dailyclear-gold:$t', clearPaid),
        amount: config.dailyClearGold,
        source: LedgerSource.dailyClear,
        sourceId: t,
        note: 'Все ежедневные задания выполнены',
        dayKey: t,
        createdAt: now,
      ));
      d.events.add(DailyClearEvent(config.dailyClearXp, config.dailyClearGold));
    }

    // Achievements can award XP, which can unlock more — iterate a few times.
    for (var i = 0; i < 4; i++) {
      final snap = snapshot(d.peek());
      var unlocked = false;
      for (final a in achievementCatalog) {
        if (d.peek().achievements.containsKey(a.id) || !a.isMet(snap)) continue;
        unlocked = true;
        final xp = config.rarityXp[a.rarity]!, gold = config.rarityGold[a.rarity]!;
        final paidXp = d.peek().xp.values
            .where((x) => x.sourceId == a.id && x.source == LedgerSource.achievement)
            .length;
        final paidGold = d.peek().gold.values
            .where((x) => x.sourceId == a.id && x.source == LedgerSource.achievement)
            .length;
        d.putAchievement(UnlockedAchievement(achievementId: a.id, unlockedAt: now));
        d.addXp(XpTransaction(
          id: _rewardId(d.peek(), 'achievement-xp:${a.id}', paidXp),
          amount: xp,
          source: LedgerSource.achievement,
          sourceId: a.id,
          note: a.title,
          dayKey: t,
          createdAt: now,
        ));
        d.addGold(GoldTransaction(
          id: _rewardId(d.peek(), 'achievement-gold:${a.id}', paidGold),
          amount: gold,
          source: LedgerSource.achievement,
          sourceId: a.id,
          note: a.title,
          dayKey: t,
          createdAt: now,
        ));
        d.events.add(AchievementUnlockedEvent(a, xp, gold));
      }
      if (!unlocked) break;
    }

    final after = snapshot(d.peek());
    for (var l = before.level.level + 1; l <= after.level.level; l++) {
      if (_netGold(d.peek(), '$l', LedgerSource.levelReward) > 0) continue;
      final paid = d.peek().gold.values
          .where((g) => g.sourceId == '$l' && g.source == LedgerSource.levelReward)
          .length;
      final id = _rewardId(d.peek(), 'level-reward:$l', paid);
      if (d.peek().gold.containsKey(id)) continue;
      final g = config.levelRewardGold(l);
      d.addGold(GoldTransaction(
        id: id,
        amount: g,
        source: LedgerSource.levelReward,
        sourceId: '$l',
        note: 'Уровень $l',
        dayKey: t,
        createdAt: now,
      ));
      d.events.add(LevelUp(l, g));
    }
    for (final a in AttributeType.values) {
      final b = before.attributeLevels[a]!.level, n = after.attributeLevels[a]!.level;
      if (n > b) d.events.add(AttributeLevelUp(a, n));
    }
  }
}

/// Explains how a completion's XP is composed. Shown before and after
/// completing so the player sees exactly what they were paid for.
class XpQuote {
  const XpQuote({
    required this.base,
    required this.multiplier,
    required this.streakBonus,
    required this.focusBonus,
    required this.skillBonus,
    required this.overCap,
    required this.xp,
    required this.disciplineXp,
    required this.gold,
    required this.goldCapped,
  });

  final int base;
  final double multiplier;
  final double streakBonus;
  final double focusBonus;
  final double skillBonus;
  final bool overCap;
  final int xp;
  final int disciplineXp;
  final int gold;
  final bool goldCapped;

  int get totalXp => xp + disciplineXp;

  List<String> parts() => [
        'база $base',
        if (multiplier != 1) '×${multiplier.toStringAsFixed(1)}',
        if (streakBonus > 0) 'серия +${(streakBonus * 100).round()}%',
        if (focusBonus > 0) 'фокус +${(focusBonus * 100).round()}%',
        if (skillBonus > 0) 'навыки +${(skillBonus * 100).round()}%',
        if (overCap) 'дневной лимит ½',
      ];

  String describe() => parts().join(' · ');
}

/// Collects changes for one action; maps are copied lazily on first write.
class _Draft {
  _Draft(this.base);

  final GameState base;
  final changes = <EntityChange>[];
  final events = <GameEvent>[];
  String? lastEvaluatedDay;

  UserSettings? _settings;
  Map<String, Quest>? _quests;
  Map<String, QuestCompletion>? _completions;
  Map<String, ProgressLog>? _progress;
  Map<String, XpTransaction>? _xp;
  Map<String, GoldTransaction>? _gold;
  Map<String, PenaltyRecord>? _penalties;
  Map<String, Reward>? _rewards;
  Map<String, RewardPurchase>? _purchases;
  Map<String, JournalEntry>? _journal;
  Map<String, UnlockedSkill>? _skills;
  Map<String, UnlockedAchievement>? _achievements;
  Map<String, DayMark>? _dayMarks;
  GameState? _cache;

  void change(String table, String id, Map<String, dynamic> data) {
    changes.add(EntityChange(table, id, data));
    _cache = null;
  }

  void putSettings(UserSettings v) {
    _settings = v;
    change(Tables.settings, 'settings', v.toJson());
  }

  void putQuest(Quest v) {
    (_quests ??= {...base.quests})[v.id] = v;
    change(Tables.quests, v.id, v.toJson());
  }

  void putCompletion(QuestCompletion v) {
    (_completions ??= {...base.completions})[v.id] = v;
    change(Tables.completions, v.id, v.toJson());
  }

  void putProgress(ProgressLog v) {
    (_progress ??= {...base.progress})[v.id] = v;
    change(Tables.progress, v.id, v.toJson());
  }

  void addXp(XpTransaction v) {
    final m = _xp ??= {...base.xp};
    if (m.containsKey(v.id)) return; // idempotent
    m[v.id] = v;
    change(Tables.xp, v.id, v.toJson());
  }

  void addGold(GoldTransaction v) {
    final m = _gold ??= {...base.gold};
    if (m.containsKey(v.id)) return;
    m[v.id] = v;
    change(Tables.gold, v.id, v.toJson());
  }

  void putPenalty(PenaltyRecord v) {
    (_penalties ??= {...base.penalties})[v.id] = v;
    change(Tables.penalties, v.id, v.toJson());
  }

  void putReward(Reward v) {
    (_rewards ??= {...base.rewards})[v.id] = v;
    change(Tables.rewards, v.id, v.toJson());
  }

  void putPurchase(RewardPurchase v) {
    (_purchases ??= {...base.purchases})[v.id] = v;
    change(Tables.purchases, v.id, v.toJson());
  }

  void putJournal(JournalEntry v) {
    (_journal ??= {...base.journal})[v.id] = v;
    change(Tables.journal, v.id, v.toJson());
  }

  void putSkill(UnlockedSkill v) {
    (_skills ??= {...base.skills})[v.skillId] = v;
    change(Tables.skills, v.skillId, v.toJson());
  }

  void putAchievement(UnlockedAchievement v) {
    (_achievements ??= {...base.achievements})[v.achievementId] = v;
    change(Tables.achievements, v.achievementId, v.toJson());
  }

  void removeAchievement(String id) {
    (_achievements ??= {...base.achievements}).remove(id);
    change(Tables.achievements, id, {'achievement_id': id, '_deleted': true});
  }

  void putDayMark(DayMark v) {
    (_dayMarks ??= {...base.dayMarks})[v.dayKey] = v;
    change(Tables.dayMarks, v.dayKey, v.toJson());
  }

  void removeDayMark(String day) {
    (_dayMarks ??= {...base.dayMarks}).remove(day);
    change(Tables.dayMarks, day, {'day_key': day, '_deleted': true});
  }

  /// Current state including uncommitted changes.
  GameState peek() => _cache ??= base.copyWith(
        settings: _settings,
        quests: _quests,
        completions: _completions,
        progress: _progress,
        xp: _xp,
        gold: _gold,
        penalties: _penalties,
        rewards: _rewards,
        purchases: _purchases,
        journal: _journal,
        skills: _skills,
        achievements: _achievements,
        dayMarks: _dayMarks,
        lastEvaluatedDay: lastEvaluatedDay,
      );

  GameResult finish(GameEngine engine) {
    if (base.hasCharacter && changes.isNotEmpty) {
      engine._postProcess(this, engine.snapshot(base));
    }
    if (lastEvaluatedDay != null && lastEvaluatedDay != base.lastEvaluatedDay) {
      change(Tables.meta, 'state', {'last_evaluated_day': lastEvaluatedDay});
    }
    return GameResult(peek(), changes, events);
  }
}
