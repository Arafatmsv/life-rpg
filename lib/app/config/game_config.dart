import 'dart:math' as math;

import '../../data/models/enums.dart';

/// All balance numbers of the game live here, so the rules can be tuned
/// without touching the engine or the UI.
class GameConfig {
  const GameConfig({
    this.levelBaseXp = 100,
    this.levelXpPerLevel = 50,
    this.attributeBaseXp = 50,
    this.attributeXpPerLevel = 25,
    this.difficultyXp = const {
      Difficulty.easy: 10,
      Difficulty.normal: 20,
      Difficulty.hard: 40,
      Difficulty.epic: 70,
    },
    this.missionXp = const {
      Difficulty.easy: 100,
      Difficulty.normal: 150,
      Difficulty.hard: 200,
      Difficulty.epic: 250,
    },
    this.customXpMinFactor = 0.5,
    this.customXpMaxFactor = 1.5,
    this.goldPerXp = 0.5,
    this.dailyXpSoftCap = 500,
    this.overCapFactor = 0.5,
    this.dailyQuestGoldCap = 300,
    this.streakBonusPerDay = 0.02,
    this.streakBonusMax = 0.20,
    this.focusBonus = 0.10,
    this.skillBonusMax = 0.15,
    this.disciplineShare = 0.25,
    this.subtaskXp = 5,
    this.bossCheckInXp = 5,
    this.dailyClearXp = 25,
    this.dailyClearGold = 10,
    this.levelRewardGoldBase = 50,
    this.levelRewardGoldPerLevel = 10,
    this.rarityGold = const {
      Rarity.common: 25,
      Rarity.rare: 75,
      Rarity.epic: 200,
      Rarity.legendary: 500,
    },
    this.rarityXp = const {
      Rarity.common: 10,
      Rarity.rare: 30,
      Rarity.epic: 80,
      Rarity.legendary: 150,
    },
    this.goldPenaltyShare = 0.10,
    this.goldPenaltyMax = 200,
    this.xpPenalty = const {
      Severity.light: 5,
      Severity.medium: 15,
      Severity.severe: 30,
    },
    this.maxBackfillDays = 7,
    this.revertWindow = const Duration(hours: 24),
  });

  /// XP required to go from [level] to [level] + 1:
  /// `levelBaseXp + level * levelXpPerLevel` (100 + L × 50 by default).
  final int levelBaseXp;
  final int levelXpPerLevel;

  /// Same curve for attribute levels, but cheaper.
  final int attributeBaseXp;
  final int attributeXpPerLevel;

  /// Default XP per difficulty for regular quests.
  final Map<Difficulty, int> difficultyXp;

  /// Default XP per difficulty for main and boss quests.
  final Map<Difficulty, int> missionXp;

  /// A custom XP reward must stay inside
  /// [customXpMinFactor]..[customXpMaxFactor] × the difficulty default.
  final double customXpMinFactor;
  final double customXpMaxFactor;

  final double goldPerXp;

  /// After this much XP in one day further rewards are multiplied by
  /// [overCapFactor]. Stops endless farming with many tiny quests.
  final int dailyXpSoftCap;
  final double overCapFactor;

  /// Gold from quests per day is capped hard.
  final int dailyQuestGoldCap;

  final double streakBonusPerDay;
  final double streakBonusMax;

  /// Extra XP for quests in the character's focus attributes.
  final double focusBonus;

  /// Upper bound for the summed skill-tree bonus of one attribute.
  final double skillBonusMax;

  /// Share of a recurring quest's XP that also goes to DISCIPLINE.
  final double disciplineShare;

  final int subtaskXp;
  final int bossCheckInXp;
  final int dailyClearXp;
  final int dailyClearGold;

  final int levelRewardGoldBase;
  final int levelRewardGoldPerLevel;

  final Map<Rarity, int> rarityGold;
  final Map<Rarity, int> rarityXp;

  final double goldPenaltyShare;
  final int goldPenaltyMax;
  final Map<Severity, int> xpPenalty;

  /// After a long absence only the last N days are evaluated for misses,
  /// so coming back never produces a wall of failures.
  final int maxBackfillDays;

  /// How long a completion can be undone.
  final Duration revertWindow;

  int xpToNextLevel(int level) => levelBaseXp + level * levelXpPerLevel;

  int xpToNextAttributeLevel(int level) =>
      attributeBaseXp + level * attributeXpPerLevel;

  int defaultXpFor(QuestType type, Difficulty difficulty) => type.isMission
      ? missionXp[difficulty]!
      : difficultyXp[difficulty]!;

  int minCustomXp(QuestType type, Difficulty d) =>
      math.max(1, (defaultXpFor(type, d) * customXpMinFactor).round());

  int maxCustomXp(QuestType type, Difficulty d) =>
      (defaultXpFor(type, d) * customXpMaxFactor).round();

  int levelRewardGold(int level) =>
      levelRewardGoldBase + level * levelRewardGoldPerLevel;
}
