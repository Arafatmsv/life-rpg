import '../../app/config/game_config.dart';
import '../../data/models/enums.dart';
import '../../data/models/game_state.dart';
import '../../data/models/penalty.dart';
import '../utils/day.dart';
import 'game_clock.dart';
import 'level_math.dart';
import 'skill_catalog.dart';
import 'streak.dart';

/// Aggregated counters used by achievements and analytics.
class GameStats {
  const GameStats({
    required this.totalCompletions,
    required this.completionsByAttribute,
    required this.completionsByType,
    required this.failedCount,
    required this.missionsCompleted,
    required this.bossesCompleted,
    required this.unitTotals,
    required this.morningCompletions,
    required this.journalCount,
    required this.purchasesCount,
    required this.skillsUnlocked,
    required this.recoveredPenalties,
    required this.restDays,
    required this.minutesSpent,
    required this.achievementsCount,
  });

  final int totalCompletions;
  final Map<AttributeType, int> completionsByAttribute;
  final Map<QuestType, int> completionsByType;
  final int failedCount;
  final int missionsCompleted;
  final int bossesCompleted;
  final Map<MetricUnit, int> unitTotals;
  final int morningCompletions;
  final int journalCount;
  final int purchasesCount;
  final int skillsUnlocked;
  final int recoveredPenalties;
  final int restDays;
  final int minutesSpent;
  final int achievementsCount;
}

/// Everything derived from the ledger. Computed once per state change.
class GameSnapshot {
  const GameSnapshot({
    required this.today,
    required this.level,
    required this.attributeXp,
    required this.attributeLevels,
    required this.gold,
    required this.streak,
    required this.skillPointsEarned,
    required this.skillPointsSpent,
    required this.stats,
    required this.xpToday,
    required this.questGoldToday,
  });

  final String today;
  final LevelInfo level;
  final Map<AttributeType, int> attributeXp;
  final Map<AttributeType, LevelInfo> attributeLevels;
  final int gold;
  final StreakInfo streak;
  final int skillPointsEarned;
  final int skillPointsSpent;
  final GameStats stats;
  final int xpToday;
  final int questGoldToday;

  int get skillPoints => skillPointsEarned - skillPointsSpent;

  /// Simple overall development rating: sum of attribute levels.
  int get rating => attributeLevels.values.fold(0, (s, l) => s + l.level);
}

GameSnapshot buildSnapshot(GameState s, GameConfig c, String today) {
  final tz = s.settings.tzOffsetMinutes;
  var totalXp = 0, xpToday = 0;
  final attrXp = {for (final a in AttributeType.values) a: 0};
  for (final t in s.xp.values) {
    totalXp += t.amount;
    if (t.attribute != null) attrXp[t.attribute!] = attrXp[t.attribute!]! + t.amount;
    if (t.dayKey == today && t.amount > 0 && t.source != LedgerSource.revert) {
      xpToday += t.amount;
    }
  }
  // Reverts on the same day give the daily budget back.
  for (final t in s.xp.values) {
    if (t.dayKey == today && t.source == LedgerSource.revert) xpToday += t.amount;
  }

  var gold = 0, questGoldToday = 0;
  for (final g in s.gold.values) {
    gold += g.amount;
    if (g.dayKey == today &&
        (g.source == LedgerSource.quest || g.source == LedgerSource.revert)) {
      questGoldToday += g.amount;
    }
  }

  final attrLevels = {
    for (final a in AttributeType.values) a: attributeLevel(c, attrXp[a]!.clamp(0, 1 << 31)),
  };
  final level = characterLevel(c, totalXp);

  // Streak from completions per game day.
  final dayCounts = <String, int>{};
  var morning = 0, minutes = 0, missions = 0, bosses = 0;
  final byAttr = {for (final a in AttributeType.values) a: 0};
  final byType = {for (final t in QuestType.values) t: 0};
  var total = 0;
  for (final comp in s.activeCompletions) {
    total++;
    dayCounts[comp.dayKey] = (dayCounts[comp.dayKey] ?? 0) + 1;
    byAttr[comp.attribute] = byAttr[comp.attribute]! + 1;
    byType[comp.questType] = byType[comp.questType]! + 1;
    if (GameClock.toWall(comp.completedAt, tz).hour < 9) morning++;
    minutes += comp.durationMinutes ?? 0;
    if (comp.questType == QuestType.main) missions++;
    if (comp.questType == QuestType.boss) bosses++;
  }
  final units = {for (final u in MetricUnit.values) u: 0};
  for (final p in s.progress.values) {
    units[p.unit] = units[p.unit]! + p.amount;
  }
  minutes += units[MetricUnit.minutes]!;

  final neutral = <String>{
    for (final m in s.dayMarks.values) m.dayKey,
    if (s.settings.vacationMode) today,
  };
  final firstDay = s.character == null
      ? today
      : GameClock.dayOf(s.character!.createdAt, tz);
  final streak = computeStreak(
    dayCounts: dayCounts,
    neutralDays: neutral,
    today: today,
    firstDay: minDay(firstDay, today),
    minCount: s.settings.minCompletionsForStreak,
  );

  final earned = (level.level - 1) +
      attrLevels.values.fold<int>(0, (sum, l) => sum + (l.level - 1));
  final spent = s.skills.values.fold<int>(0, (sum, u) => sum + u.cost);

  final failed = s.penalties.values
      .where((p) => p.kind != PenaltyKind.streakBreak)
      .length;

  return GameSnapshot(
    today: today,
    level: level,
    attributeXp: attrXp,
    attributeLevels: attrLevels,
    gold: gold,
    streak: streak,
    skillPointsEarned: earned,
    skillPointsSpent: spent,
    xpToday: xpToday,
    questGoldToday: questGoldToday,
    stats: GameStats(
      totalCompletions: total,
      completionsByAttribute: byAttr,
      completionsByType: byType,
      failedCount: failed,
      missionsCompleted: missions,
      bossesCompleted: bosses,
      unitTotals: units,
      morningCompletions: morning,
      journalCount: s.journal.values.where((j) => !j.deleted && !j.isEmpty).length,
      purchasesCount: s.purchases.values.where((p) => !p.isRefunded).length,
      skillsUnlocked: s.skills.length,
      recoveredPenalties: s.penalties.values
          .where((p) => p.status == PenaltyStatus.recovered)
          .length,
      restDays: s.dayMarks.values.where((m) => m.kind == DayMarkKind.rest).length,
      minutesSpent: minutes,
      achievementsCount: s.achievements.length,
    ),
  );
}

/// Summed skill-tree XP bonus for an attribute, capped by config.
double skillBonusFor(GameState s, GameConfig c, AttributeType a) {
  var b = 0.0;
  for (final u in s.skills.values) {
    final def = skillById[u.skillId];
    if (def != null && def.attribute == a) b += def.xpBonus;
  }
  return b > c.skillBonusMax ? c.skillBonusMax : b;
}
