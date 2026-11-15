import '../../core/utils/json.dart';
import 'enums.dart';

enum AccentTheme {
  gold('Золото'),
  violet('Аметист'),
  emerald('Изумруд'),
  crimson('Рубин');

  const AccentTheme(this.label);
  final String label;

  static AccentTheme fromName(String? n) =>
      AccentTheme.values.firstWhere((a) => a.name == n, orElse: () => AccentTheme.gold);
}

class NotificationSettings {
  const NotificationSettings({
    this.enabled = true,
    this.dailyReminder = true,
    this.dailyReminderTime = '09:00',
    this.reflectionReminder = true,
    this.reflectionTime = '21:30',
    this.questReminders = true,
    this.deadlineReminders = true,
    this.levelUp = true,
    this.missionComplete = true,
  });

  final bool enabled;
  final bool dailyReminder;
  final String dailyReminderTime;
  final bool reflectionReminder;
  final String reflectionTime;
  final bool questReminders;
  final bool deadlineReminders;
  final bool levelUp;
  final bool missionComplete;

  NotificationSettings copyWith({
    bool? enabled,
    bool? dailyReminder,
    String? dailyReminderTime,
    bool? reflectionReminder,
    String? reflectionTime,
    bool? questReminders,
    bool? deadlineReminders,
    bool? levelUp,
    bool? missionComplete,
  }) =>
      NotificationSettings(
        enabled: enabled ?? this.enabled,
        dailyReminder: dailyReminder ?? this.dailyReminder,
        dailyReminderTime: dailyReminderTime ?? this.dailyReminderTime,
        reflectionReminder: reflectionReminder ?? this.reflectionReminder,
        reflectionTime: reflectionTime ?? this.reflectionTime,
        questReminders: questReminders ?? this.questReminders,
        deadlineReminders: deadlineReminders ?? this.deadlineReminders,
        levelUp: levelUp ?? this.levelUp,
        missionComplete: missionComplete ?? this.missionComplete,
      );

  Json toJson() => {
        'enabled': enabled,
        'daily_reminder': dailyReminder,
        'daily_reminder_time': dailyReminderTime,
        'reflection_reminder': reflectionReminder,
        'reflection_time': reflectionTime,
        'quest_reminders': questReminders,
        'deadline_reminders': deadlineReminders,
        'level_up': levelUp,
        'mission_complete': missionComplete,
      };

  factory NotificationSettings.fromJson(Object? raw) {
    final j = asJson(raw);
    const d = NotificationSettings();
    return NotificationSettings(
      enabled: asBool(j['enabled'], d.enabled),
      dailyReminder: asBool(j['daily_reminder'], d.dailyReminder),
      dailyReminderTime: asString(j['daily_reminder_time'], d.dailyReminderTime),
      reflectionReminder: asBool(j['reflection_reminder'], d.reflectionReminder),
      reflectionTime: asString(j['reflection_time'], d.reflectionTime),
      questReminders: asBool(j['quest_reminders'], d.questReminders),
      deadlineReminders: asBool(j['deadline_reminders'], d.deadlineReminders),
      levelUp: asBool(j['level_up'], d.levelUp),
      missionComplete: asBool(j['mission_complete'], d.missionComplete),
    );
  }
}

class UserSettings {
  const UserSettings({
    this.penaltiesEnabled = true,
    this.strictness = Strictness.normal,
    this.missedQuestPenalty = true,
    this.streakBreakPenalty = false,
    this.allowRecovery = true,
    this.recoveryDaysPerMonth = 3,
    this.goldPenaltyEnabled = false,
    this.xpPenaltyEnabled = false,
    this.consequences = defaultConsequences,
    this.streakFreezeEnabled = false,
    this.streakFreezesPerMonth = 2,
    this.vacationMode = false,
    this.minCompletionsForStreak = 1,
    this.xpMultiplier = 1.0,
    this.animationsEnabled = true,
    this.accent = AccentTheme.gold,
    this.tzOffsetMinutes,
    this.firstDayOfWeek = DateTime.monday,
    this.notifications = const NotificationSettings(),
    this.updatedAt,
  });

  static const defaultConsequences = {
    QuestType.daily: Consequence.light,
    QuestType.weekly: Consequence.medium,
    QuestType.side: Consequence.none,
    QuestType.main: Consequence.severe,
    QuestType.boss: Consequence.severe,
  };

  final bool penaltiesEnabled;
  final Strictness strictness;
  final bool missedQuestPenalty;
  final bool streakBreakPenalty;
  final bool allowRecovery;

  /// Monthly budget of "excused" marks.
  final int recoveryDaysPerMonth;

  /// Opt-in: severe failures cost part of the Gold balance.
  final bool goldPenaltyEnabled;

  /// Opt-in: failures deduct a little XP (never below the current level).
  final bool xpPenaltyEnabled;
  final Map<QuestType, Consequence> consequences;
  final bool streakFreezeEnabled;
  final int streakFreezesPerMonth;

  /// Rest mode: no penalties, streak is frozen.
  final bool vacationMode;
  final int minCompletionsForStreak;

  /// Player-controlled XP scaling (0.5 … 2.0).
  final double xpMultiplier;
  final bool animationsEnabled;
  final AccentTheme accent;

  /// Fixed UTC offset for game days; null = device time zone.
  final int? tzOffsetMinutes;
  final int firstDayOfWeek;
  final NotificationSettings notifications;
  final DateTime? updatedAt;

  Consequence consequenceFor(QuestType t) =>
      consequences[t] ?? defaultConsequences[t] ?? Consequence.light;

  UserSettings copyWith({
    bool? penaltiesEnabled,
    Strictness? strictness,
    bool? missedQuestPenalty,
    bool? streakBreakPenalty,
    bool? allowRecovery,
    int? recoveryDaysPerMonth,
    bool? goldPenaltyEnabled,
    bool? xpPenaltyEnabled,
    Map<QuestType, Consequence>? consequences,
    bool? streakFreezeEnabled,
    int? streakFreezesPerMonth,
    bool? vacationMode,
    int? minCompletionsForStreak,
    double? xpMultiplier,
    bool? animationsEnabled,
    AccentTheme? accent,
    int? Function()? tzOffsetMinutes,
    int? firstDayOfWeek,
    NotificationSettings? notifications,
    DateTime? updatedAt,
  }) =>
      UserSettings(
        penaltiesEnabled: penaltiesEnabled ?? this.penaltiesEnabled,
        strictness: strictness ?? this.strictness,
        missedQuestPenalty: missedQuestPenalty ?? this.missedQuestPenalty,
        streakBreakPenalty: streakBreakPenalty ?? this.streakBreakPenalty,
        allowRecovery: allowRecovery ?? this.allowRecovery,
        recoveryDaysPerMonth: recoveryDaysPerMonth ?? this.recoveryDaysPerMonth,
        goldPenaltyEnabled: goldPenaltyEnabled ?? this.goldPenaltyEnabled,
        xpPenaltyEnabled: xpPenaltyEnabled ?? this.xpPenaltyEnabled,
        consequences: consequences ?? this.consequences,
        streakFreezeEnabled: streakFreezeEnabled ?? this.streakFreezeEnabled,
        streakFreezesPerMonth: streakFreezesPerMonth ?? this.streakFreezesPerMonth,
        vacationMode: vacationMode ?? this.vacationMode,
        minCompletionsForStreak: minCompletionsForStreak ?? this.minCompletionsForStreak,
        xpMultiplier: xpMultiplier ?? this.xpMultiplier,
        animationsEnabled: animationsEnabled ?? this.animationsEnabled,
        accent: accent ?? this.accent,
        tzOffsetMinutes: tzOffsetMinutes != null ? tzOffsetMinutes() : this.tzOffsetMinutes,
        firstDayOfWeek: firstDayOfWeek ?? this.firstDayOfWeek,
        notifications: notifications ?? this.notifications,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  Json toJson() => {
        'penalties_enabled': penaltiesEnabled,
        'strictness': strictness.name,
        'missed_quest_penalty': missedQuestPenalty,
        'streak_break_penalty': streakBreakPenalty,
        'allow_recovery': allowRecovery,
        'recovery_days_per_month': recoveryDaysPerMonth,
        'gold_penalty_enabled': goldPenaltyEnabled,
        'xp_penalty_enabled': xpPenaltyEnabled,
        'consequences': consequences.map((k, v) => MapEntry(k.name, v.name)),
        'streak_freeze_enabled': streakFreezeEnabled,
        'streak_freezes_per_month': streakFreezesPerMonth,
        'vacation_mode': vacationMode,
        'min_completions_for_streak': minCompletionsForStreak,
        'xp_multiplier': xpMultiplier,
        'animations_enabled': animationsEnabled,
        'accent': accent.name,
        'tz_offset_minutes': tzOffsetMinutes,
        'first_day_of_week': firstDayOfWeek,
        'notifications': notifications.toJson(),
        'updated_at': isoOrNull(updatedAt),
      };

  factory UserSettings.fromJson(Object? raw) {
    final j = asJson(raw);
    const d = UserSettings();
    final cons = asJson(j['consequences']);
    return UserSettings(
      penaltiesEnabled: asBool(j['penalties_enabled'], d.penaltiesEnabled),
      strictness: Strictness.fromName(j['strictness'] as String?),
      missedQuestPenalty: asBool(j['missed_quest_penalty'], d.missedQuestPenalty),
      streakBreakPenalty: asBool(j['streak_break_penalty'], d.streakBreakPenalty),
      allowRecovery: asBool(j['allow_recovery'], d.allowRecovery),
      recoveryDaysPerMonth: asInt(j['recovery_days_per_month'], d.recoveryDaysPerMonth).clamp(0, 31),
      goldPenaltyEnabled: asBool(j['gold_penalty_enabled']),
      xpPenaltyEnabled: asBool(j['xp_penalty_enabled']),
      consequences: {
        for (final t in QuestType.values)
          t: cons.containsKey(t.name)
              ? Consequence.fromName(cons[t.name] as String?)
              : defaultConsequences[t]!,
      },
      streakFreezeEnabled: asBool(j['streak_freeze_enabled']),
      streakFreezesPerMonth: asInt(j['streak_freezes_per_month'], d.streakFreezesPerMonth).clamp(0, 10),
      vacationMode: asBool(j['vacation_mode']),
      minCompletionsForStreak: asInt(j['min_completions_for_streak'], 1).clamp(1, 20),
      xpMultiplier: asDouble(j['xp_multiplier'], 1).clamp(0.5, 2.0),
      animationsEnabled: asBool(j['animations_enabled'], true),
      accent: AccentTheme.fromName(j['accent'] as String?),
      tzOffsetMinutes: asIntOrNull(j['tz_offset_minutes']),
      firstDayOfWeek: asInt(j['first_day_of_week'], DateTime.monday).clamp(1, 7),
      notifications: NotificationSettings.fromJson(j['notifications']),
      updatedAt: parseDate(j['updated_at']),
    );
  }
}
