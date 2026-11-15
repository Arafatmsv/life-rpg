import '../../data/models/enums.dart';

/// A node of the skill tree. Unlocking costs skill points (SP) and gives a
/// permanent XP bonus to the node's attribute.
class SkillDef {
  const SkillDef({
    required this.id,
    required this.attribute,
    required this.tier,
    required this.column,
    required this.title,
    required this.description,
    required this.perk,
    this.requires = const [],
    this.requiredAchievement,
  });

  final String id;
  final AttributeType attribute;

  /// 1…5, also the row in the tree.
  final int tier;

  /// Horizontal slot inside the row: -1 left, 0 center, 1 right.
  final int column;
  final String title;
  final String description;
  final String perk;
  final List<String> requires;
  final String? requiredAchievement;

  int get cost => tier;

  /// Minimum attribute level to unlock this tier.
  int get requiredLevel => const [1, 1, 3, 5, 8, 12][tier];

  double get xpBonus => const [0.0, 0.02, 0.02, 0.03, 0.03, 0.04][tier];
}

List<SkillDef> _branch(
  AttributeType a,
  List<(String id, int tier, int col, String title, String desc, String perk, List<String> req, String? ach)> nodes,
) =>
    [
      for (final n in nodes)
        SkillDef(
          id: n.$1,
          attribute: a,
          tier: n.$2,
          column: n.$3,
          title: n.$4,
          description: n.$5,
          perk: n.$6,
          requires: n.$7,
          requiredAchievement: n.$8,
        ),
    ];

final List<SkillDef> skillCatalog = [
  ..._branch(AttributeType.intelligence, [
    ('int_basics', 1, 0, 'Основы обучения', 'Вы учитесь понемногу, но каждый день.', 'Учёба становится привычкой', [], null),
    ('int_reading', 2, -1, 'Регулярное чтение', 'Книги — постоянная часть недели.', 'Задания на чтение ценнее', ['int_basics'], null),
    ('int_focus', 2, 1, 'Концентрация', 'Вы удерживаете внимание на одной задаче.', 'Глубокая работа без отвлечений', ['int_basics'], null),
    ('int_languages', 3, -1, 'Иностранные языки', 'Системное изучение нового языка.', 'Новый язык — новые возможности', ['int_reading'], null),
    ('int_systems', 3, 1, 'Системное мышление', 'Вы видите связи и структуру.', 'Сложное раскладывается на простое', ['int_focus'], null),
    ('int_profession', 4, -1, 'Глубокое изучение профессии', 'Знания уровня практика.', 'Профессиональная глубина', ['int_languages', 'int_systems'], null),
    ('int_research', 4, 1, 'Самостоятельное исследование', 'Вы сами находите ответы.', 'Исследователь', ['int_systems'], null),
    ('int_expert', 5, 0, 'Экспертность', 'Вы создаёте собственные образовательные проекты.', 'Учите других', ['int_profession', 'int_research'], 'bookworm'),
  ]),
  ..._branch(AttributeType.physique, [
    ('phy_active', 1, 0, 'Регулярная активность', 'Движение каждый день.', 'Тело просыпается', [], null),
    ('phy_walk', 2, -1, 'Ежедневная ходьба', 'Шаги — ваш базовый ритуал.', 'Прогулки дают больше', ['phy_active'], null),
    ('phy_stretch', 2, 1, 'Базовая растяжка', 'Гибкость и восстановление.', 'Мягкое тело — ясная голова', ['phy_active'], null),
    ('phy_strength', 3, -1, 'Силовые тренировки', 'Работа с весом и собственным телом.', 'Сила', ['phy_walk'], null),
    ('phy_endurance', 3, 1, 'Выносливость', 'Кардио и длительная нагрузка.', 'Дыхание не сбивается', ['phy_stretch'], null),
    ('phy_advanced', 4, -1, 'Продвинутые тренировки', 'Программы с прогрессией нагрузки.', 'Атлет', ['phy_strength', 'phy_endurance'], null),
    ('phy_sport', 4, 1, 'Спортивная дисциплина', 'Тренировки по плану, без пропусков.', 'Режим', ['phy_endurance'], null),
    ('phy_program', 5, 0, 'Индивидуальная программа', 'Вы сами проектируете своё развитие.', 'Мастер тела', ['phy_advanced', 'phy_sport'], 'workout_20'),
  ]),
  ..._branch(AttributeType.discipline, [
    ('dis_plan', 1, 0, 'План на день', 'Вы знаете, что делать сегодня.', 'Ясность', [], null),
    ('dis_routine', 2, -1, 'Утренний ритуал', 'День начинается одинаково хорошо.', 'Ритм', ['dis_plan'], null),
    ('dis_nopro', 2, 1, 'Анти-прокрастинация', 'Сложное — первым.', 'Сначала главное', ['dis_plan'], null),
    ('dis_habits', 3, -1, 'Контроль привычек', 'Привычки работают на вас.', 'Автопилот', ['dis_routine'], null),
    ('dis_time', 3, 1, 'Тайм-менеджмент', 'Время распределено осознанно.', 'Каждый час на месте', ['dis_nopro'], null),
    ('dis_consistency', 4, -1, 'Постоянство', 'Регулярность важнее интенсивности.', 'Не ломается', ['dis_habits', 'dis_time'], null),
    ('dis_will', 4, 1, 'Сила воли', 'Вы держите слово, данное себе.', 'Обещания выполняются', ['dis_time'], null),
    ('dis_master', 5, 0, 'Мастер дисциплины', 'Система, которая работает годами.', 'Железный режим', ['dis_consistency', 'dis_will'], 'streak_30'),
  ]),
  ..._branch(AttributeType.career, [
    ('car_tasks', 1, 0, 'Рабочий фокус', 'Одна важная задача в день.', 'Результат', [], null),
    ('car_tools', 2, -1, 'Новые инструменты', 'Вы осваиваете новое в профессии.', 'Инструментарий', ['car_tasks'], null),
    ('car_projects', 2, 1, 'Свои проекты', 'Делаете что-то своё.', 'Создатель', ['car_tasks'], null),
    ('car_skills', 3, -1, 'Профессиональные навыки', 'Целенаправленный рост.', 'Мастерство', ['car_tools'], null),
    ('car_portfolio', 3, 1, 'Портфолио', 'Работы, которые можно показать.', 'Витрина', ['car_projects'], null),
    ('car_lead', 4, -1, 'Ответственность', 'Вы ведёте задачи от начала до конца.', 'Лидер', ['car_skills', 'car_portfolio'], null),
    ('car_network', 4, 1, 'Профессиональные связи', 'Вас знают в профессии.', 'Репутация', ['car_portfolio'], null),
    ('car_master', 5, 0, 'Признанный профессионал', 'Достижения, которыми гордитесь.', 'Карьерный пик', ['car_lead', 'car_network'], 'builder'),
  ]),
  ..._branch(AttributeType.finance, [
    ('fin_track', 1, 0, 'Учёт расходов', 'Вы знаете, куда уходят деньги.', 'Прозрачность', [], null),
    ('fin_budget', 2, -1, 'Бюджет', 'Деньги распределены заранее.', 'План', ['fin_track'], null),
    ('fin_save', 2, 1, 'Сбережения', 'Часть дохода откладывается.', 'Подушка', ['fin_track'], null),
    ('fin_literacy', 3, -1, 'Финансовая грамотность', 'Вы понимаете, как работают деньги.', 'Знание', ['fin_budget'], null),
    ('fin_side', 3, 1, 'Дополнительный доход', 'Ещё один источник дохода.', 'Второй поток', ['fin_save'], null),
    ('fin_plan', 4, -1, 'Финансовое планирование', 'Цели на годы вперёд.', 'Горизонт', ['fin_literacy', 'fin_side'], null),
    ('fin_reserve', 4, 1, 'Резервный фонд', 'Спокойствие при любых событиях.', 'Устойчивость', ['fin_side'], null),
    ('fin_master', 5, 0, 'Финансовая свобода', 'Деньги работают на ваши цели.', 'Независимость', ['fin_plan', 'fin_reserve'], null),
  ]),
  ..._branch(AttributeType.social, [
    ('soc_talk', 1, 0, 'Открытость', 'Вы начинаете разговор первым.', 'Контакт', [], null),
    ('soc_listen', 2, -1, 'Активное слушание', 'Слышите, а не ждёте своей очереди.', 'Понимание', ['soc_talk'], null),
    ('soc_meet', 2, 1, 'Новые знакомства', 'Круг общения растёт.', 'Связи', ['soc_talk'], null),
    ('soc_bonds', 3, -1, 'Крепкие отношения', 'Время для близких людей.', 'Опора', ['soc_listen'], null),
    ('soc_speak', 3, 1, 'Публичные выступления', 'Вы говорите перед людьми.', 'Голос', ['soc_meet'], null),
    ('soc_empathy', 4, -1, 'Эмпатия', 'Вы чувствуете других.', 'Тепло', ['soc_bonds', 'soc_speak'], null),
    ('soc_influence', 4, 1, 'Убеждение', 'Ваши идеи поддерживают.', 'Влияние', ['soc_speak'], null),
    ('soc_master', 5, 0, 'Мастер коммуникации', 'Люди тянутся к вам.', 'Харизма', ['soc_empathy', 'soc_influence'], null),
  ]),
  ..._branch(AttributeType.mental, [
    ('men_rest', 1, 0, 'Право на отдых', 'Отдых — часть прогресса.', 'Восстановление', [], null),
    ('men_reflect', 2, -1, 'Рефлексия', 'Вы разбираете свой день.', 'Ясный взгляд', ['men_rest'], null),
    ('men_mindful', 2, 1, 'Осознанность', 'Присутствие в моменте.', 'Тишина', ['men_rest'], null),
    ('men_stress', 3, -1, 'Управление стрессом', 'Давление не выбивает из колеи.', 'Спокойствие', ['men_reflect'], null),
    ('men_sleep', 3, 1, 'Режим сна', 'Стабильный сон.', 'Свежая голова', ['men_mindful'], null),
    ('men_balance', 4, -1, 'Эмоциональный баланс', 'Вы понимаете свои эмоции.', 'Равновесие', ['men_stress', 'men_sleep'], null),
    ('men_resilience', 4, 1, 'Устойчивость', 'После неудачи вы возвращаетесь.', 'Феникс', ['men_sleep'], null),
    ('men_master', 5, 0, 'Внутренняя опора', 'Устойчивость, на которую можно опереться.', 'Стержень', ['men_balance', 'men_resilience'], 'journal_30'),
  ]),
];

final Map<String, SkillDef> skillById = {for (final s in skillCatalog) s.id: s};

List<SkillDef> skillsOf(AttributeType a) =>
    skillCatalog.where((s) => s.attribute == a).toList();
