import 'package:flutter_test/flutter_test.dart';
import 'package:life_rpg/app/config/game_config.dart';
import 'package:life_rpg/core/errors/game_exception.dart';
import 'package:life_rpg/core/game/game_clock.dart';
import 'package:life_rpg/core/game/game_engine.dart';
import 'package:life_rpg/core/game/game_events.dart';
import 'package:life_rpg/core/game/level_math.dart';
import 'package:life_rpg/core/game/streak.dart';
import 'package:life_rpg/data/models/enums.dart';
import 'package:life_rpg/data/models/game_state.dart';
import 'package:life_rpg/data/models/penalty.dart';
import 'package:life_rpg/data/models/quest.dart';
import 'package:life_rpg/data/models/reward.dart';

void main() {
  late DateTime now;
  late GameEngine engine;
  const config = GameConfig();

  setUp(() {
    now = DateTime.utc(2026, 11, 10, 12); // Tuesday noon UTC
    engine = GameEngine(clock: GameClock(now: () => now));
  });

  /// Fresh character in UTC game time (fixed offset 0 keeps tests stable).
  GameState start({CharacterClass cls = CharacterClass.universal}) {
    final s0 = const GameState().copyWith(
      settings: const GameState().settings.copyWith(tzOffsetMinutes: () => 0),
    );
    return engine
        .createCharacter(
          s0,
          CharacterDraft(
            name: 'Тест',
            avatarId: 'sword',
            avatarColor: 0,
            characterClass: cls,
            focus: const [],
            goals: const [],
          ),
        )
        .state;
  }

  Quest quest(
    String id, {
    QuestType type = QuestType.daily,
    Difficulty difficulty = Difficulty.normal,
    AttributeType attribute = AttributeType.intelligence,
    int target = 1,
    MetricUnit unit = MetricUnit.none,
    String? due,
    List<Subtask> subtasks = const [],
  }) =>
      Quest(
        id: id,
        title: 'Quest $id',
        type: type,
        attribute: attribute,
        difficulty: difficulty,
        xpReward: 0,
        startDay: '2026-11-10',
        dueDay: due,
        targetAmount: target,
        unit: unit,
        subtasks: subtasks,
        createdAt: now,
        updatedAt: now,
      );

  GameState add(GameState s, Quest q) => engine.saveQuest(s, q).state;
  int totalXp(GameState s) => s.xp.values.fold(0, (a, t) => a + t.amount);
  int gold(GameState s) => s.gold.values.fold(0, (a, t) => a + t.amount);

  group('levels', () {
    test('xp to next level follows 100 + L × 50', () {
      expect(config.xpToNextLevel(1), 150);
      expect(config.xpToNextLevel(2), 200);
    });

    test('level is derived from total xp, never reset', () {
      final l = characterLevel(config, 360);
      expect(l.level, 3); // 150 + 200 = 350 → level 3 with 10 xp in
      expect(l.xpIntoLevel, 10);
      expect(l.totalXp, 360);
      expect(totalXpForLevel(3, config.xpToNextLevel), 350);
    });
  });

  group('quest completion', () {
    test('awards difficulty xp, attribute xp and gold', () {
      var s = add(start(), quest('a', type: QuestType.side));
      final r = engine.completeQuest(s, 'a');
      s = r.state;
      final snap = engine.snapshot(s);
      // First Step achievement adds 5 XP on top of the quest's 20.
      expect(snap.attributeXp[AttributeType.intelligence], 20);
      expect(snap.level.totalXp, 25);
      expect(s.quests['a']!.status, QuestStatus.completed);
      expect(r.events.whereType<QuestCompletedEvent>(), hasLength(1));
      expect(r.events.whereType<AchievementUnlockedEvent>().single.def.id, 'first_step');
      expect(gold(s), 5 + 10); // quest gold (20 × 0.25) + achievement gold
    });

    test('cannot complete the same period twice', () {
      var s = add(start(), quest('d'));
      s = engine.completeQuest(s, 'd').state;
      expect(() => engine.completeQuest(s, 'd'), throwsA(isA<GameException>()));
    });

    test('recurring quest also trains discipline', () {
      var s = add(start(), quest('d'));
      s = engine.completeQuest(s, 'd').state;
      final snap = engine.snapshot(s);
      expect(snap.attributeXp[AttributeType.intelligence], 20);
      expect(snap.attributeXp[AttributeType.discipline], 2); // 10% of 20
    });

    test('daily quest can be completed again next day', () {
      var s = add(start(), quest('d'));
      s = engine.completeQuest(s, 'd').state;
      now = now.add(const Duration(days: 1));
      s = engine.evaluateDays(s).state;
      s = engine.completeQuest(s, 'd').state;
      expect(s.activeCompletions.where((c) => c.questId == 'd'), hasLength(2));
    });

    test('editing a completed quest does not pay again', () {
      var s = add(start(), quest('a', type: QuestType.side));
      s = engine.completeQuest(s, 'a').state;
      final before = totalXp(s);
      s = engine.saveQuest(s, s.quests['a']!.copyWith(title: 'Renamed')).state;
      expect(totalXp(s), before);
      expect(s.quests['a']!.status, QuestStatus.completed);
    });

    test('custom xp is clamped to the difficulty range', () {
      var s = start();
      s = engine.saveQuest(s, quest('c', type: QuestType.side).copyWith(xpReward: 9999, customXp: true)).state;
      expect(s.quests['c']!.xpReward, config.maxCustomXp(QuestType.side, Difficulty.normal));
    });

    test('measured quest completes when target reached', () {
      var s = add(start(), quest('r', target: 10, unit: MetricUnit.pages));
      s = engine.logProgress(s, 'r', 4).state;
      expect(engine.isDoneThisPeriod(s, s.quests['r']!), isFalse);
      s = engine.logProgress(s, 'r', 6).state;
      expect(engine.isDoneThisPeriod(s, s.quests['r']!), isTrue);
      expect(engine.snapshot(s).stats.unitTotals[MetricUnit.pages], 10);
    });

    test('revert compensates xp and gold and reopens the quest', () {
      var s = add(start(), quest('a', type: QuestType.side));
      final xp0 = totalXp(s), gold0 = gold(s);
      s = engine.completeQuest(s, 'a').state;
      final c = s.activeCompletions.single;
      s = engine.revertCompletion(s, c.id).state;
      // Achievement reward is kept, quest reward is compensated.
      expect(totalXp(s) - xp0, 5);
      expect(gold(s) - gold0, 10);
      expect(s.quests['a']!.status, QuestStatus.active);
      // Can be completed again, but with a new completion id.
      s = engine.completeQuest(s, 'a').state;
      expect(s.activeCompletions.single.id, isNot(c.id));
    });

    test('daily soft cap halves xp above the limit', () {
      var s = start();
      for (var i = 0; i < 10; i++) {
        s = add(s, quest('m$i', type: QuestType.main, difficulty: Difficulty.epic));
      }
      for (var i = 0; i < 10; i++) {
        s = engine.completeQuest(s, 'm$i').state;
      }
      final questXp = s.xp.values
          .where((t) => t.source == LedgerSource.quest)
          .fold<int>(0, (a, t) => a + t.amount);
      // 10 × 250 = 2500 raw; capped part pays half.
      expect(questXp, lessThan(2500));
      expect(questXp, greaterThanOrEqualTo(500));
    });

    test('daily gold from quests is capped', () {
      var s = start();
      for (var i = 0; i < 10; i++) {
        s = add(s, quest('m$i', type: QuestType.main, difficulty: Difficulty.epic));
        s = engine.completeQuest(s, 'm$i').state;
      }
      final questGold = s.gold.values
          .where((t) => t.source == LedgerSource.quest)
          .fold<int>(0, (a, t) => a + t.amount);
      expect(questGold, config.dailyQuestGoldCap);
    });
  });

  group('missions and bosses', () {
    test('mission needs all subtasks; subtask xp is paid once', () {
      var s = add(
        start(),
        quest('m', type: QuestType.main, subtasks: const [
          Subtask(id: 's1', title: 'one'),
          Subtask(id: 's2', title: 'two'),
        ]),
      );
      expect(() => engine.completeQuest(s, 'm'), throwsA(isA<GameException>()));
      s = engine.toggleSubtask(s, 'm', 's1').state;
      final xpAfterFirst = totalXp(s);
      s = engine.toggleSubtask(s, 'm', 's1').state; // uncheck
      s = engine.toggleSubtask(s, 'm', 's1').state; // check again
      expect(totalXp(s), xpAfterFirst);
      s = engine.toggleSubtask(s, 'm', 's2').state;
      s = engine.completeQuest(s, 'm').state;
      expect(s.quests['m']!.status, QuestStatus.completed);
      expect(s.achievements.containsKey('builder'), isTrue);
    });

    test('boss allows one check-in per day and completes at target', () {
      var s = add(start(), quest('b', type: QuestType.boss, target: 2));
      s = engine.checkInBoss(s, 'b').state;
      expect(() => engine.checkInBoss(s, 'b'), throwsA(isA<GameException>()));
      now = now.add(const Duration(days: 1));
      s = engine.checkInBoss(s, 'b').state;
      expect(s.quests['b']!.status, QuestStatus.completed);
      expect(s.achievements.containsKey('boss_slayer'), isTrue);
    });
  });

  group('level rewards', () {
    test('level up pays gold once and emits event', () {
      var s = start();
      s = add(s, quest('m', type: QuestType.main, difficulty: Difficulty.hard));
      final r = engine.completeQuest(s, 'm');
      expect(r.events.whereType<LevelUp>().map((e) => e.level), contains(2));
      final levelGold = r.state.gold.values.where((g) => g.source == LedgerSource.levelReward);
      expect(levelGold, hasLength(1));
    });
  });

  group('penalties', () {
    test('missed daily quest creates a light mark, no xp loss by default', () {
      var s = add(start(), quest('d'));
      final xp0 = totalXp(s);
      // Day of creation is free; the next day is missed.
      now = now.add(const Duration(days: 2));
      final r = engine.evaluateDays(s);
      s = r.state;
      final p = s.penalties.values.single;
      expect(p.severity, Severity.light);
      expect(p.kind, PenaltyKind.missedQuest);
      expect(totalXp(s), xp0);
      expect(engine.streakBonusBlocked(s), isTrue);
      // Running again does not duplicate.
      expect(engine.evaluateDays(s).state.penalties, hasLength(1));
    });

    test('rest day prevents penalties', () {
      var s = add(start(), quest('d'));
      s = engine.toggleRestDay(s, '2026-11-11').state;
      now = now.add(const Duration(days: 2));
      s = engine.evaluateDays(s).state;
      expect(s.penalties, isEmpty);
    });

    test('penalties can be disabled', () {
      var s = add(start(), quest('d'));
      s = engine.updateSettings(s, (x) => x.copyWith(penaltiesEnabled: false)).state;
      now = now.add(const Duration(days: 2));
      expect(engine.evaluateDays(s).state.penalties, isEmpty);
    });

    test('failed mission is severe, gives recovery quest; gold loss only when enabled', () {
      var s = start();
      s = engine.updateSettings(s, (x) => x.copyWith(goldPenaltyEnabled: true)).state;
      // Earn some gold first.
      s = add(s, quest('x', type: QuestType.side));
      s = engine.completeQuest(s, 'x').state;
      final gold0 = gold(s);
      s = add(s, quest('m', type: QuestType.main, due: '2026-11-10'));
      now = now.add(const Duration(days: 1));
      s = engine.evaluateDays(s).state;
      expect(s.quests['m']!.status, QuestStatus.failed);
      final p = s.penalties.values.single;
      expect(p.severity, Severity.severe);
      expect(p.goldLost, greaterThan(0));
      expect(gold(s), gold0 - p.goldLost);
      final rq = s.quests[p.recoveryQuestId]!;
      expect(rq.isRecovery, isTrue);
      // Completing the recovery quest resolves the mark.
      s = engine.completeQuest(s, rq.id).state;
      expect(s.penalties[p.id]!.status, PenaltyStatus.recovered);
    });

    test('excuse returns lost gold and respects the monthly limit', () {
      var s = start();
      s = engine.updateSettings(s, (x) => x.copyWith(goldPenaltyEnabled: true, recoveryDaysPerMonth: 1)).state;
      s = add(s, quest('x', type: QuestType.side));
      s = engine.completeQuest(s, 'x').state;
      final gold0 = gold(s);
      s = add(s, quest('m1', type: QuestType.main, due: '2026-11-10'));
      s = add(s, quest('m2', type: QuestType.main, due: '2026-11-10'));
      now = now.add(const Duration(days: 1));
      s = engine.evaluateDays(s).state;
      final ps = s.penalties.values.toList();
      s = engine.excusePenalty(s, ps[0].id).state;
      expect(() => engine.excusePenalty(s, ps[1].id), throwsA(isA<GameException>()));
      expect(gold(s), gold0 - ps[1].goldLost);
    });

    test('long absence only evaluates the backfill window', () {
      var s = add(start(), quest('d'));
      now = now.add(const Duration(days: 40));
      s = engine.evaluateDays(s).state;
      expect(s.penalties.length, lessThanOrEqualTo(config.maxBackfillDays));
    });

    test('reschedule turns a failed mission active again', () {
      var s = add(start(), quest('m', type: QuestType.main, due: '2026-11-10'));
      now = now.add(const Duration(days: 1));
      s = engine.evaluateDays(s).state;
      final p = s.penalties.values.single;
      s = engine.reschedulePenalty(s, p.id, '2026-11-20').state;
      expect(s.quests['m']!.status, QuestStatus.active);
      expect(s.quests['m']!.dueDay, '2026-11-20');
      expect(s.penalties[p.id]!.status, PenaltyStatus.rescheduled);
    });
  });

  group('shop', () {
    test('purchase needs balance, refund returns gold', () {
      var s = start();
      final r = Reward(id: 'r', title: 'Фильм', cost: 12, icon: 'film', createdAt: now, updatedAt: now);
      s = engine.saveReward(s, r).state;
      expect(() => engine.purchaseReward(s, 'r'), throwsA(isA<GameException>()));
      s = add(s, quest('x', type: QuestType.side));
      s = engine.completeQuest(s, 'x').state; // 5 + 10 gold
      s = engine.purchaseReward(s, 'r').state;
      // 15 - 12, plus 10 for the "first reward" achievement.
      expect(gold(s), 13);
      s = engine.refundPurchase(s, s.purchases.values.single.id).state;
      expect(gold(s), 25);
    });
  });

  group('economy', () {
    test('skill points come only from character levels', () {
      var s = start();
      // Lots of attribute XP but no character level-up yet: still 0 SP.
      s = add(s, quest('a', type: QuestType.side, difficulty: Difficulty.epic));
      s = engine.completeQuest(s, 'a').state;
      final snap = engine.snapshot(s);
      expect(snap.level.level, 1);
      expect(snap.skillPoints, 0);
    });

    test('one full day of typical quests does not buy a whole skill branch', () {
      var s = start();
      for (var i = 0; i < 5; i++) {
        s = add(s, quest('d$i'));
        s = engine.completeQuest(s, 'd$i').state;
      }
      final snap = engine.snapshot(s);
      // About one level (and one skill point) per day of normal effort.
      expect(snap.skillPoints, lessThanOrEqualTo(1));
      expect(snap.gold, lessThan(100));
    });
  });

  group('skills', () {
    test('unlock requires skill points, level and prerequisites', () {
      var s = start();
      expect(() => engine.unlockSkill(s, 'int_basics'), throwsA(isA<GameException>()));
      s = add(s, quest('m', type: QuestType.main, difficulty: Difficulty.epic));
      s = engine.completeQuest(s, 'm').state; // levels up → SP
      s = engine.unlockSkill(s, 'int_basics').state;
      expect(s.skills.containsKey('int_basics'), isTrue);
      expect(() => engine.unlockSkill(s, 'int_expert'), throwsA(isA<GameException>()));
    });
  });

  group('streaks', () {
    test('rest days keep the streak, today does not break it', () {
      final info = computeStreak(
        dayCounts: {'2026-11-01': 1, '2026-11-02': 2, '2026-11-04': 1},
        neutralDays: {'2026-11-03'},
        today: '2026-11-05',
        firstDay: '2026-11-01',
      );
      expect(info.current, 3);
      expect(info.longest, 3);
      expect(info.missedDays, 0);
    });

    test('a missed day breaks the streak and is reported', () {
      final info = computeStreak(
        dayCounts: {'2026-11-01': 1, '2026-11-02': 1, '2026-11-03': 1},
        neutralDays: const {},
        today: '2026-11-05',
        firstDay: '2026-11-01',
      );
      expect(info.current, 0);
      expect(info.longest, 3);
      expect(info.brokenYesterday, isTrue);
      expect(info.previousStreak, 3);
    });

    test('streak freeze protects a missed day', () {
      var s = start();
      s = engine.updateSettings(s, (x) => x.copyWith(streakFreezeEnabled: true)).state;
      now = now.add(const Duration(days: 2));
      s = engine.useStreakFreeze(s, '2026-11-11').state;
      expect(s.dayMarks['2026-11-11']!.kind, DayMarkKind.freeze);
      expect(() => engine.useStreakFreeze(s, '2026-11-11'), throwsA(isA<GameException>()));
    });
  });

  group('serialization', () {
    test('state round-trips through tables', () {
      var s = add(start(), quest('m', type: QuestType.main, subtasks: const [Subtask(id: 's', title: 't')]));
      s = engine.toggleSubtask(s, 'm', 's').state;
      s = engine.completeQuest(s, 'm').state;
      final back = GameState.fromTables(s.toTables());
      expect(back.quests['m']!.status, QuestStatus.completed);
      expect(back.xp.length, s.xp.length);
      expect(totalXp(back), totalXp(s));
      expect(back.character!.name, 'Тест');
      expect(back.settings.tzOffsetMinutes, 0);
    });
  });
}
