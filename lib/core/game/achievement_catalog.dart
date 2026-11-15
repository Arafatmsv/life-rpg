import '../../data/models/enums.dart';
import 'stats.dart';

class AchievementDef {
  const AchievementDef({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.rarity,
    required this.target,
    required this.progress,
    this.hidden = false,
  });

  final String id;
  final String title;
  final String description;

  /// Key in the icon registry (see `rpg_icons.dart`).
  final String icon;
  final Rarity rarity;
  final int target;

  /// Current value towards [target].
  final int Function(GameSnapshot s) progress;
  final bool hidden;

  bool isMet(GameSnapshot s) => progress(s) >= target;
}

final List<AchievementDef> achievementCatalog = [
  AchievementDef(
    id: 'first_step', title: 'First Step', description: 'Выполнено первое задание',
    icon: 'flag', rarity: Rarity.common, target: 1,
    progress: (s) => s.stats.totalCompletions,
  ),
  AchievementDef(
    id: 'streak_7', title: 'Seven Days', description: 'Серия из 7 успешных дней',
    icon: 'flame', rarity: Rarity.rare, target: 7,
    progress: (s) => s.streak.longest,
  ),
  AchievementDef(
    id: 'streak_30', title: 'Discipline Master', description: '30 дней регулярной активности',
    icon: 'crown', rarity: Rarity.epic, target: 30,
    progress: (s) => s.streak.longest,
  ),
  AchievementDef(
    id: 'streak_100', title: 'Unbroken', description: 'Серия из 100 дней',
    icon: 'infinity', rarity: Rarity.legendary, target: 100,
    progress: (s) => s.streak.longest,
  ),
  AchievementDef(
    id: 'bookworm', title: 'Bookworm', description: 'Прочитано 500 страниц',
    icon: 'book', rarity: Rarity.rare, target: 500,
    progress: (s) => s.stats.unitTotals[MetricUnit.pages] ?? 0,
  ),
  AchievementDef(
    id: 'early_bird', title: 'Early Bird', description: '20 заданий выполнено до 9:00',
    icon: 'sunrise', rarity: Rarity.rare, target: 20,
    progress: (s) => s.stats.morningCompletions,
  ),
  AchievementDef(
    id: 'builder', title: 'Builder', description: 'Завершена первая собственная миссия',
    icon: 'hammer', rarity: Rarity.rare, target: 1,
    progress: (s) => s.stats.missionsCompleted,
  ),
  AchievementDef(
    id: 'boss_slayer', title: 'Boss Slayer', description: 'Пройдено первое испытание',
    icon: 'skull', rarity: Rarity.epic, target: 1,
    progress: (s) => s.stats.bossesCompleted,
  ),
  AchievementDef(
    id: 'level_10', title: 'Level 10', description: 'Достигнут 10-й уровень',
    icon: 'star', rarity: Rarity.epic, target: 10,
    progress: (s) => s.level.level,
  ),
  AchievementDef(
    id: 'level_25', title: 'Ascended', description: 'Достигнут 25-й уровень',
    icon: 'gem', rarity: Rarity.legendary, target: 25,
    progress: (s) => s.level.level,
  ),
  AchievementDef(
    id: 'quests_100', title: 'Centurion', description: 'Выполнено 100 заданий',
    icon: 'shield', rarity: Rarity.epic, target: 100,
    progress: (s) => s.stats.totalCompletions,
  ),
  AchievementDef(
    id: 'workout_20', title: 'Iron Will', description: '20 заданий физической формы',
    icon: 'dumbbell', rarity: Rarity.rare, target: 20,
    progress: (s) => s.stats.completionsByAttribute[AttributeType.physique] ?? 0,
  ),
  AchievementDef(
    id: 'steps_100k', title: 'Wanderer', description: 'Пройдено 100 000 шагов',
    icon: 'footprints', rarity: Rarity.rare, target: 100000,
    progress: (s) => s.stats.unitTotals[MetricUnit.steps] ?? 0,
  ),
  AchievementDef(
    id: 'deep_work', title: 'Deep Dive', description: '1000 минут, вложенных в развитие',
    icon: 'hourglass', rarity: Rarity.epic, target: 1000,
    progress: (s) => s.stats.minutesSpent,
  ),
  AchievementDef(
    id: 'journal_7', title: 'Chronicler', description: '7 записей в дневнике',
    icon: 'feather', rarity: Rarity.common, target: 7,
    progress: (s) => s.stats.journalCount,
  ),
  AchievementDef(
    id: 'journal_30', title: 'Keeper of Days', description: '30 записей в дневнике',
    icon: 'scroll', rarity: Rarity.rare, target: 30,
    progress: (s) => s.stats.journalCount,
  ),
  AchievementDef(
    id: 'first_reward', title: 'Well Earned', description: 'Куплена первая награда',
    icon: 'gift', rarity: Rarity.common, target: 1,
    progress: (s) => s.stats.purchasesCount,
  ),
  AchievementDef(
    id: 'skills_5', title: 'Apprentice', description: 'Открыто 5 навыков',
    icon: 'tree', rarity: Rarity.common, target: 5,
    progress: (s) => s.stats.skillsUnlocked,
  ),
  AchievementDef(
    id: 'harmony', title: 'Harmony', description: 'Все характеристики достигли 3-го уровня',
    icon: 'compass', rarity: Rarity.epic, target: 3,
    progress: (s) => s.attributeLevels.values
        .map((l) => l.level)
        .fold<int>(1 << 30, (m, v) => v < m ? v : m),
  ),
  AchievementDef(
    id: 'phoenix', title: 'Phoenix', description: 'Восстановлено 3 нарушения',
    icon: 'phoenix', rarity: Rarity.rare, target: 3,
    progress: (s) => s.stats.recoveredPenalties,
  ),
  AchievementDef(
    id: 'rest_day', title: 'Rest Is Progress', description: 'Запланирован первый день отдыха',
    icon: 'moon', rarity: Rarity.common, target: 1,
    progress: (s) => s.stats.restDays,
  ),
];

final Map<String, AchievementDef> achievementById = {
  for (final a in achievementCatalog) a.id: a,
};
