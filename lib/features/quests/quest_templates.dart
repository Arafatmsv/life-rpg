import '../../core/utils/day.dart';
import '../../data/models/enums.dart';
import '../../data/models/quest.dart';

class QuestTemplate {
  const QuestTemplate(
    this.title,
    this.type,
    this.attribute,
    this.difficulty, {
    this.target = 1,
    this.unit = MetricUnit.none,
    this.minutes,
  });

  final String title;
  final QuestType type;
  final AttributeType attribute;
  final Difficulty difficulty;
  final int target;
  final MetricUnit unit;
  final int? minutes;

  Quest build(String id, DateTime now, int xp) => Quest(
        id: id,
        title: title,
        type: type,
        attribute: attribute,
        difficulty: difficulty,
        xpReward: xp,
        recurrence: switch (type) {
          QuestType.daily => const Recurrence.daily(),
          QuestType.weekly => const Recurrence.weekly(),
          _ => const Recurrence(),
        },
        startDay: dayKeyOf(now),
        targetAmount: target,
        unit: unit,
        durationMinutes: minutes,
        createdAt: now,
        updatedAt: now,
      );
}

/// Starter quests offered during onboarding and in the quest editor.
const questTemplates = [
  QuestTemplate('Прочитать 10 страниц', QuestType.daily, AttributeType.intelligence, Difficulty.easy,
      target: 10, unit: MetricUnit.pages, minutes: 15),
  QuestTemplate('Изучать английский 20 минут', QuestType.daily, AttributeType.intelligence,
      Difficulty.normal, minutes: 20),
  QuestTemplate('Пройти 5000 шагов', QuestType.daily, AttributeType.physique, Difficulty.normal,
      target: 5000, unit: MetricUnit.steps),
  QuestTemplate('Растяжка 10 минут', QuestType.daily, AttributeType.physique, Difficulty.easy,
      minutes: 10),
  QuestTemplate('Одна важная рабочая задача', QuestType.daily, AttributeType.career, Difficulty.normal,
      minutes: 60),
  QuestTemplate('Записать расходы за день', QuestType.daily, AttributeType.finance, Difficulty.easy,
      minutes: 5),
  QuestTemplate('Спланировать завтрашний день', QuestType.daily, AttributeType.discipline,
      Difficulty.easy, minutes: 5),
  QuestTemplate('Написать близкому человеку', QuestType.daily, AttributeType.social, Difficulty.easy),
  QuestTemplate('10 минут тишины без телефона', QuestType.daily, AttributeType.mental, Difficulty.easy,
      minutes: 10),
  QuestTemplate('Пройти 40 000 шагов за неделю', QuestType.weekly, AttributeType.physique,
      Difficulty.hard, target: 40000, unit: MetricUnit.steps),
  QuestTemplate('Прочитать 100 страниц за неделю', QuestType.weekly, AttributeType.intelligence,
      Difficulty.hard, target: 100, unit: MetricUnit.pages),
  QuestTemplate('Три тренировки за неделю', QuestType.weekly, AttributeType.physique, Difficulty.hard,
      target: 3, unit: MetricUnit.times),
  QuestTemplate('Встретиться с друзьями', QuestType.weekly, AttributeType.social, Difficulty.normal),
  QuestTemplate('Отложить часть дохода', QuestType.weekly, AttributeType.finance, Difficulty.normal),
];
