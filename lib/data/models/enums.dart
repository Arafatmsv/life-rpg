/// Core enumerations shared by models, engine and UI.
library;

enum AttributeType {
  physique('PHYSIQUE', 'Физическая форма', 'Тренировки, ходьба, бег, растяжка, спорт'),
  intelligence('INTELLIGENCE', 'Интеллект', 'Чтение, языки, курсы, новые технологии'),
  discipline('DISCIPLINE', 'Дисциплина', 'Расписание, регулярность, контроль привычек'),
  career('CAREER', 'Карьера', 'Рабочие задачи, проекты, профессиональный рост'),
  finance('FINANCE', 'Финансы', 'Учёт расходов, сбережения, планирование'),
  social('SOCIAL', 'Социальные навыки', 'Общение, отношения, выступления'),
  mental('MENTAL', 'Устойчивость', 'Рефлексия, отдых, осознанность, стресс');

  const AttributeType(this.code, this.label, this.description);

  final String code;
  final String label;
  final String description;

  static AttributeType fromName(String? name) => AttributeType.values
      .firstWhere((a) => a.name == name, orElse: () => AttributeType.discipline);
}

enum Difficulty {
  easy('Простое'),
  normal('Обычное'),
  hard('Сложное'),
  epic('Очень сложное');

  const Difficulty(this.label);
  final String label;

  static Difficulty fromName(String? name) => Difficulty.values
      .firstWhere((d) => d.name == name, orElse: () => Difficulty.normal);
}

enum QuestType {
  daily('Ежедневное', 'Daily'),
  weekly('Еженедельное', 'Weekly'),
  main('Миссия', 'Main'),
  side('Побочное', 'Side'),
  boss('Испытание', 'Boss');

  const QuestType(this.label, this.tag);
  final String label;
  final String tag;

  bool get isMission => this == QuestType.main || this == QuestType.boss;

  static QuestType fromName(String? name) => QuestType.values
      .firstWhere((t) => t.name == name, orElse: () => QuestType.side);
}

enum QuestStatus {
  active('Активно'),
  completed('Выполнено'),
  failed('Провалено'),
  paused('На паузе'),
  archived('В архиве');

  const QuestStatus(this.label);
  final String label;

  static QuestStatus fromName(String? name) => QuestStatus.values
      .firstWhere((s) => s.name == name, orElse: () => QuestStatus.active);
}

enum RecurrenceKind {
  none('Без повторения'),
  daily('Каждый день'),
  weekdays('По дням недели'),
  interval('Каждые N дней'),
  weekly('Раз в неделю');

  const RecurrenceKind(this.label);
  final String label;

  static RecurrenceKind fromName(String? name) => RecurrenceKind.values
      .firstWhere((k) => k.name == name, orElse: () => RecurrenceKind.none);
}

enum Rarity {
  common('Common', 'Обычное'),
  rare('Rare', 'Редкое'),
  epic('Epic', 'Эпическое'),
  legendary('Legendary', 'Легендарное');

  const Rarity(this.tag, this.label);
  final String tag;
  final String label;
}

enum Severity {
  light('Лёгкое'),
  medium('Среднее'),
  severe('Серьёзное');

  const Severity(this.label);
  final String label;

  Severity shift(int by) {
    final i = (index + by).clamp(0, Severity.values.length - 1);
    return Severity.values[i];
  }

  static Severity fromName(String? name) => Severity.values
      .firstWhere((s) => s.name == name, orElse: () => Severity.light);
}

/// What a quest type costs the player when it is missed.
enum Consequence {
  none('Без последствий'),
  light('Лёгкое'),
  medium('Среднее'),
  severe('Серьёзное');

  const Consequence(this.label);
  final String label;

  Severity? get severity => switch (this) {
        Consequence.none => null,
        Consequence.light => Severity.light,
        Consequence.medium => Severity.medium,
        Consequence.severe => Severity.severe,
      };

  static Consequence fromName(String? name) => Consequence.values
      .firstWhere((c) => c.name == name, orElse: () => Consequence.light);
}

enum Strictness {
  lenient('Мягкая'),
  normal('Обычная'),
  strict('Строгая');

  const Strictness(this.label);
  final String label;

  int get severityShift => switch (this) {
        Strictness.lenient => -1,
        Strictness.normal => 0,
        Strictness.strict => 1,
      };

  static Strictness fromName(String? name) => Strictness.values
      .firstWhere((s) => s.name == name, orElse: () => Strictness.normal);
}

enum PenaltyStatus {
  open('Открыто'),
  recovered('Восстановлено'),
  excused('Уважительная причина'),
  rescheduled('Перенесено');

  const PenaltyStatus(this.label);
  final String label;

  bool get isResolved => this != PenaltyStatus.open;

  static PenaltyStatus fromName(String? name) => PenaltyStatus.values
      .firstWhere((s) => s.name == name, orElse: () => PenaltyStatus.open);
}

enum DayMarkKind {
  rest('День отдыха'),
  freeze('Заморозка серии');

  const DayMarkKind(this.label);
  final String label;

  static DayMarkKind fromName(String? name) => DayMarkKind.values
      .firstWhere((k) => k.name == name, orElse: () => DayMarkKind.rest);
}

/// Why an XP or Gold transaction exists. Shown to the player in history.
enum LedgerSource {
  quest('Задание'),
  discipline('Регулярность'),
  subtask('Подзадача'),
  bossCheckIn('Шаг испытания'),
  dailyClear('Все задания дня'),
  achievement('Достижение'),
  levelReward('Новый уровень'),
  penalty('Последствие'),
  revert('Отмена выполнения'),
  purchase('Покупка награды'),
  refund('Возврат покупки');

  const LedgerSource(this.label);
  final String label;

  static LedgerSource fromName(String? name) => LedgerSource.values
      .firstWhere((s) => s.name == name, orElse: () => LedgerSource.quest);
}

enum CharacterClass {
  warrior('Воин дисциплины', 'Привычки, физическая активность и самоконтроль',
      [AttributeType.physique, AttributeType.discipline]),
  scholar('Учёный', 'Знания, обучение и интеллектуальное развитие',
      [AttributeType.intelligence, AttributeType.mental]),
  entrepreneur('Предприниматель', 'Карьера, финансы и продуктивность',
      [AttributeType.career, AttributeType.finance]),
  creator('Творец', 'Творчество, проекты и самовыражение',
      [AttributeType.career, AttributeType.social]),
  universal('Универсал', 'Сбалансированное развитие всех направлений', []);

  const CharacterClass(this.label, this.description, this.defaultFocus);
  final String label;
  final String description;
  final List<AttributeType> defaultFocus;

  static CharacterClass fromName(String? name) => CharacterClass.values
      .firstWhere((c) => c.name == name, orElse: () => CharacterClass.universal);
}

enum MetricUnit {
  none('', ''),
  pages('страниц', 'стр.'),
  steps('шагов', 'шаг.'),
  minutes('минут', 'мин'),
  km('км', 'км'),
  reps('повторений', 'повт.'),
  times('раз', 'раз'),
  money('₽', '₽');

  const MetricUnit(this.label, this.short);
  final String label;
  final String short;

  static MetricUnit fromName(String? name) => MetricUnit.values
      .firstWhere((u) => u.name == name, orElse: () => MetricUnit.none);
}
