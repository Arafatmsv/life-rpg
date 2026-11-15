import '../../core/utils/json.dart';
import 'character.dart';
import 'journal_entry.dart';
import 'ledger.dart';
import 'penalty.dart';
import 'progress_marks.dart';
import 'quest.dart';
import 'reward.dart';
import 'user_settings.dart';

/// Names of persisted collections. They match the Supabase table names.
abstract final class Tables {
  static const characters = 'characters';
  static const settings = 'user_settings';
  static const quests = 'quests';
  static const completions = 'quest_completions';
  static const progress = 'quest_progress';
  static const xp = 'xp_transactions';
  static const gold = 'gold_transactions';
  static const penalties = 'penalties';
  static const rewards = 'rewards';
  static const purchases = 'reward_purchases';
  static const journal = 'journal_entries';
  static const skills = 'user_skills';
  static const achievements = 'user_achievements';
  static const dayMarks = 'streaks';
  static const meta = 'meta';

  static const all = [
    characters, settings, quests, completions, progress, xp, gold, penalties,
    rewards, purchases, journal, skills, achievements, dayMarks, meta,
  ];

  /// Append-only tables that the server writes through validated RPCs.
  static const ledger = {completions, xp, gold, purchases, achievements};
}

/// A single persisted mutation produced by the engine. Used both for local
/// storage and for the sync outbox.
class EntityChange {
  const EntityChange(this.table, this.id, this.data);

  final String table;
  final String id;
  final Json data;

  @override
  String toString() => 'EntityChange($table/$id)';
}

/// The whole game of one player. Immutable; the engine returns new copies.
class GameState {
  const GameState({
    this.character,
    this.settings = const UserSettings(),
    this.quests = const {},
    this.completions = const {},
    this.progress = const {},
    this.xp = const {},
    this.gold = const {},
    this.penalties = const {},
    this.rewards = const {},
    this.purchases = const {},
    this.journal = const {},
    this.skills = const {},
    this.achievements = const {},
    this.dayMarks = const {},
    this.lastEvaluatedDay,
  });

  final Character? character;
  final UserSettings settings;
  final Map<String, Quest> quests;
  final Map<String, QuestCompletion> completions;
  final Map<String, ProgressLog> progress;
  final Map<String, XpTransaction> xp;
  final Map<String, GoldTransaction> gold;
  final Map<String, PenaltyRecord> penalties;
  final Map<String, Reward> rewards;
  final Map<String, RewardPurchase> purchases;
  final Map<String, JournalEntry> journal;
  final Map<String, UnlockedSkill> skills;
  final Map<String, UnlockedAchievement> achievements;
  final Map<String, DayMark> dayMarks;

  /// Last game day whose misses were evaluated.
  final String? lastEvaluatedDay;

  bool get hasCharacter => character != null;

  Iterable<Quest> get liveQuests => quests.values.where((q) => !q.deleted);
  Iterable<QuestCompletion> get activeCompletions =>
      completions.values.where((c) => c.isActive);

  GameState copyWith({
    Character? character,
    UserSettings? settings,
    Map<String, Quest>? quests,
    Map<String, QuestCompletion>? completions,
    Map<String, ProgressLog>? progress,
    Map<String, XpTransaction>? xp,
    Map<String, GoldTransaction>? gold,
    Map<String, PenaltyRecord>? penalties,
    Map<String, Reward>? rewards,
    Map<String, RewardPurchase>? purchases,
    Map<String, JournalEntry>? journal,
    Map<String, UnlockedSkill>? skills,
    Map<String, UnlockedAchievement>? achievements,
    Map<String, DayMark>? dayMarks,
    String? lastEvaluatedDay,
  }) =>
      GameState(
        character: character ?? this.character,
        settings: settings ?? this.settings,
        quests: quests ?? this.quests,
        completions: completions ?? this.completions,
        progress: progress ?? this.progress,
        xp: xp ?? this.xp,
        gold: gold ?? this.gold,
        penalties: penalties ?? this.penalties,
        rewards: rewards ?? this.rewards,
        purchases: purchases ?? this.purchases,
        journal: journal ?? this.journal,
        skills: skills ?? this.skills,
        achievements: achievements ?? this.achievements,
        dayMarks: dayMarks ?? this.dayMarks,
        lastEvaluatedDay: lastEvaluatedDay ?? this.lastEvaluatedDay,
      );

  /// Rebuilds a state from raw table rows (local storage or server pull).
  factory GameState.fromTables(Map<String, Map<String, Json>> t) {
    Map<String, T> read<T>(String table, T Function(Json) f) =>
        {for (final e in (t[table] ?? const {}).entries) e.key: f(e.value)};

    final chars = t[Tables.characters]?.values;
    final settingsRow = t[Tables.settings]?.values;
    final meta = t[Tables.meta]?['state'];
    return GameState(
      character: (chars == null || chars.isEmpty) ? null : Character.fromJson(chars.first),
      settings: (settingsRow == null || settingsRow.isEmpty)
          ? const UserSettings()
          : UserSettings.fromJson(settingsRow.first),
      quests: read(Tables.quests, Quest.fromJson),
      completions: read(Tables.completions, QuestCompletion.fromJson),
      progress: read(Tables.progress, ProgressLog.fromJson),
      xp: read(Tables.xp, XpTransaction.fromJson),
      gold: read(Tables.gold, GoldTransaction.fromJson),
      penalties: read(Tables.penalties, PenaltyRecord.fromJson),
      rewards: read(Tables.rewards, Reward.fromJson),
      purchases: read(Tables.purchases, RewardPurchase.fromJson),
      journal: read(Tables.journal, JournalEntry.fromJson),
      skills: read(Tables.skills, UnlockedSkill.fromJson),
      achievements: read(Tables.achievements, UnlockedAchievement.fromJson),
      dayMarks: read(Tables.dayMarks, DayMark.fromJson),
      lastEvaluatedDay: meta?['last_evaluated_day'] as String?,
    );
  }

  /// Full snapshot as table rows — used for export and initial upload.
  Map<String, Map<String, Json>> toTables() => {
        Tables.characters: {if (character != null) character!.id: character!.toJson()},
        Tables.settings: {'settings': settings.toJson()},
        Tables.quests: quests.map((k, v) => MapEntry(k, v.toJson())),
        Tables.completions: completions.map((k, v) => MapEntry(k, v.toJson())),
        Tables.progress: progress.map((k, v) => MapEntry(k, v.toJson())),
        Tables.xp: xp.map((k, v) => MapEntry(k, v.toJson())),
        Tables.gold: gold.map((k, v) => MapEntry(k, v.toJson())),
        Tables.penalties: penalties.map((k, v) => MapEntry(k, v.toJson())),
        Tables.rewards: rewards.map((k, v) => MapEntry(k, v.toJson())),
        Tables.purchases: purchases.map((k, v) => MapEntry(k, v.toJson())),
        Tables.journal: journal.map((k, v) => MapEntry(k, v.toJson())),
        Tables.skills: skills.map((k, v) => MapEntry(k, v.toJson())),
        Tables.achievements: achievements.map((k, v) => MapEntry(k, v.toJson())),
        Tables.dayMarks: dayMarks.map((k, v) => MapEntry(k, v.toJson())),
        Tables.meta: {
          'state': {'last_evaluated_day': lastEvaluatedDay},
        },
      };
}
