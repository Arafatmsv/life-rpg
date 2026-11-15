import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/config/game_config.dart';
import '../../app/providers.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_theme.dart';
import '../../app/theme/app_tokens.dart';
import '../../core/widgets/feedback.dart';
import '../../data/models/enums.dart';

/// Every game concept the player can long-press to learn about.
enum Term {
  xp,
  level,
  gold,
  sp,
  streak,
  rating,
  attribute,
  focus,
  difficulty,
  daily,
  weekly,
  mission,
  side,
  boss,
  dailyClear,
  dailyCap,
  restDay,
  freeze,
  vacation,
  penalty,
  recovery,
  excuse,
  rarity,
  skillTree,
  shop,
  journal,
  sync,
}

class TermInfo {
  const TermInfo(this.title, this.what, {this.how, this.where});
  final String title;
  final String what;
  final String? how;
  final String? where;
}

TermInfo termInfo(Term t, GameConfig c) => switch (t) {
      Term.xp => TermInfo(
          'Опыт (XP)',
          'Очки за реальные дела. Из суммы опыта складывается уровень персонажа, '
              'а опыт по каждой характеристике растит её уровень.',
          how: 'Выполняйте задания. Простое даёт ${c.difficultyXp[Difficulty.easy]} XP, обычное '
              '${c.difficultyXp[Difficulty.normal]}, сложное ${c.difficultyXp[Difficulty.hard]}, очень сложное '
              '${c.difficultyXp[Difficulty.epic]}. Миссии и испытания дают '
              '${c.missionXp[Difficulty.easy]}–${c.missionXp[Difficulty.epic]}. После ${c.dailyXpSoftCap} XP за день '
              'награда уменьшается вдвое.',
          where: 'Уровень персонажа, уровни характеристик, доступ к ярусам дерева навыков.',
        ),
      Term.level => TermInfo(
          'Уровень',
          'Показатель общего прогресса. Считается из всего накопленного опыта и никогда не обнуляется.',
          how: 'Каждый следующий уровень требует больше опыта: ${c.levelBaseXp} + уровень × ${c.levelXpPerLevel} XP.',
          where: 'За каждый новый уровень: 1 очко навыков и ${c.levelRewardGoldBase} + уровень × '
              '${c.levelRewardGoldPerLevel} Gold.',
        ),
      Term.gold => TermInfo(
          'Gold',
          'Игровая валюта. Её можно обменять на награды, которые вы сами себе назначили.',
          how: 'Задания (четверть от полученного опыта, не больше ${c.dailyQuestGoldCap} в день), новый уровень, '
              'достижения, все задания дня.',
          where: 'Магазин наград в профиле. Покупку можно отменить, Gold вернутся.',
        ),
      Term.sp => const TermInfo(
          'Очки навыков (SP)',
          'Валюта дерева навыков. Открытый навык навсегда добавляет процент опыта к своей характеристике.',
          how: 'Одно очко за каждый новый уровень персонажа.',
          where: 'Дерево навыков. Навык яруса N стоит N очков.',
        ),
      Term.streak => TermInfo(
          'Серия',
          'Сколько дней подряд вы выполняли задания. День засчитывается, если выполнено хотя бы '
              'столько заданий, сколько указано в настройках.',
          how: 'Выполняйте задания каждый день. Дни отдыха и заморозки серию не прерывают.',
          where: 'Каждый день серии добавляет ${(c.streakBonusPerDay * 100).round()}% опыта к заданиям, '
              'максимум ${(c.streakBonusMax * 100).round()}%. Пропуск может временно снять этот бонус.',
        ),
      Term.rating => const TermInfo(
          'Рейтинг развития',
          'Сумма уровней всех семи характеристик. Показывает, насколько широко вы развиваетесь.',
          how: 'Растёт вместе с уровнями характеристик.',
        ),
      Term.attribute => TermInfo(
          'Характеристики',
          'Семь направлений развития: физическая форма, интеллект, дисциплина, карьера, финансы, '
              'социальные навыки и устойчивость. Это игровые показатели, они не оценивают вас как человека.',
          how: 'Опыт за задание идёт в его характеристику. Регулярные задания добавляют '
              '${(c.disciplineShare * 100).round()}% опыта в дисциплину.',
          where: 'Уровень характеристики открывает ярусы её ветки в дереве навыков.',
        ),
      Term.focus => TermInfo(
          'Фокус',
          'Направления, которые вы выбрали приоритетными.',
          how: 'Меняется в редактировании персонажа.',
          where: 'Задания в фокусных характеристиках дают +${(c.focusBonus * 100).round()}% опыта.',
        ),
      Term.difficulty => const TermInfo(
          'Сложность',
          'Определяет награду за задание. Выбирайте честно: чем больше усилий, тем выше сложность.',
          where: 'Своя награда в редакторе задания возможна только в пределах сложности.',
        ),
      Term.daily => const TermInfo(
          'Ежедневное задание',
          'Повторяется каждый день, по выбранным дням недели или раз в несколько дней.',
          where: 'Пропуск фиксируется в журнале последствий на следующий день.',
        ),
      Term.weekly => const TermInfo(
          'Еженедельное задание',
          'Цель на неделю, например 40 000 шагов или три тренировки. Прогресс можно вносить частями.',
          where: 'Неделя начинается с дня, выбранного в настройках.',
        ),
      Term.mission => const TermInfo(
          'Миссия',
          'Большая цель, разбитая на подзадачи: выучить язык, сменить работу, сделать проект.',
          how: 'Каждая подзадача даёт 5 XP. Миссия завершается, когда отмечены все подзадачи.',
          where: 'Если указан дедлайн и он прошёл, миссия считается проваленной. Её можно перенести.',
        ),
      Term.side => const TermInfo(
          'Побочное задание',
          'Небольшая разовая задача сверх обязательного. Пропуск по умолчанию ничем не грозит.',
        ),
      Term.boss => TermInfo(
          'Испытание',
          'Серия усилий на недели: например, 30 дней английского или 20 тренировок.',
          how: 'Одна отметка в день, каждая даёт ${c.bossCheckInXp} XP. Последняя отметка завершает испытание.',
        ),
      Term.dailyClear => TermInfo(
          'Все задания дня',
          'Бонус за выполнение всех ежедневных заданий, запланированных на сегодня (если их хотя бы два).',
          how: '+${c.dailyClearXp} XP и +${c.dailyClearGold} Gold, один раз в день.',
        ),
      Term.dailyCap => TermInfo(
          'Дневной лимит опыта',
          'Защита от «фарма» мелкими заданиями.',
          how: 'После ${c.dailyXpSoftCap} XP за день следующие задания приносят половину опыта. '
              'Gold за задания ограничен ${c.dailyQuestGoldCap} в день.',
        ),
      Term.restDay => const TermInfo(
          'День отдыха',
          'Запланированный выходной. В этот день пропуски не фиксируются, серия сохраняется.',
          how: 'Отметьте сегодня или будущий день. До двух дней отдыха в неделю.',
        ),
      Term.freeze => const TermInfo(
          'Заморозка серии',
          'Защищает уже пропущенный день, чтобы серия не прервалась.',
          how: 'Включается в настройках последствий. Количество в месяц ограничено.',
        ),
      Term.vacation => const TermInfo(
          'Режим отдыха',
          'Для отпуска или болезни. Пока он включён, пропуски не фиксируются, серия заморожена.',
        ),
      Term.penalty => const TermInfo(
          'Последствия',
          'Игровая отметка о невыполненном обязательстве. Накопленный опыт не сгорает.',
          how: 'Лёгкое: отметка и потеря бонуса серии на день. Среднее: бонус серии снят на три дня и '
              'появляется восстановительное задание. Серьёзное: провал миссии; потеря Gold, если вы её включили.',
          where: 'Журнал последствий в профиле. Строгость и правила настраиваются.',
        ),
      Term.recovery => const TermInfo(
          'Восстановительное задание',
          'Небольшой шаг, который закрывает отметку о пропуске.',
          how: 'Появляется после среднего или серьёзного нарушения. Срок три дня.',
        ),
      Term.excuse => const TermInfo(
          'Уважительная причина',
          'Закрывает отметку о пропуске и возвращает потерянные Gold и XP.',
          how: 'Число в месяц задаётся в настройках последствий.',
        ),
      Term.rarity => TermInfo(
          'Редкость достижения',
          'Насколько трудно получить достижение.',
          how: 'Common: +${c.rarityXp[Rarity.common]} XP и ${c.rarityGold[Rarity.common]} Gold. '
              'Rare: +${c.rarityXp[Rarity.rare]} XP и ${c.rarityGold[Rarity.rare]} Gold. '
              'Epic: +${c.rarityXp[Rarity.epic]} XP и ${c.rarityGold[Rarity.epic]} Gold. '
              'Legendary: +${c.rarityXp[Rarity.legendary]} XP и ${c.rarityGold[Rarity.legendary]} Gold.',
        ),
      Term.skillTree => TermInfo(
          'Дерево навыков',
          'Семь веток по пять ярусов. Каждый навык навсегда добавляет 2–4% опыта к своей характеристике, '
              'всего до ${(c.skillBonusMax * 100).round()}% на ветку.',
          how: 'Нужны очки навыков, уровень характеристики и открытые предыдущие навыки. '
              'Некоторым навыкам нужно достижение.',
        ),
      Term.shop => const TermInfo(
          'Магазин наград',
          'Список наград из реальной жизни, которые вы назначаете себе сами: фильм, вечер отдыха, покупка.',
          how: 'Добавьте награду и цену в Gold. Покупка означает, что вы разрешили себе эту награду.',
          where: 'Приложение ничего не покупает и не списывает реальные деньги.',
        ),
      Term.journal => const TermInfo(
          'Дневник',
          'Короткая рефлексия в конце дня и оценка дня от 1 до 10. Записи видите только вы.',
        ),
      Term.sync => const TermInfo(
          'Синхронизация',
          'Без аккаунта всё хранится на этом устройстве. С аккаунтом изменения сохраняются локально и '
              'отправляются на сервер, когда есть интернет.',
          where: 'Значок показывает состояние: только на устройстве, синхронизировано, нет сети, ошибка.',
        ),
    };

TermInfo attributeInfo(AttributeType a, GameConfig c) => TermInfo(
      a.label,
      a.description,
      how: 'Выполняйте задания этой характеристики. Уровень растёт от её опыта: '
          '${c.attributeBaseXp} + уровень × ${c.attributeXpPerLevel} XP на каждый следующий.',
      where: 'Уровни 1, 3, 5, 8 и 12 открывают ярусы её ветки в дереве навыков.',
    );

TermInfo questTypeInfo(QuestType t, GameConfig c) => termInfo(
      switch (t) {
        QuestType.daily => Term.daily,
        QuestType.weekly => Term.weekly,
        QuestType.main => Term.mission,
        QuestType.side => Term.side,
        QuestType.boss => Term.boss,
      },
      c,
    );

/// Shows the explanation card.
Future<void> showTermInfo(BuildContext context, TermInfo info) {
  HapticFeedback.selectionClick();
  return showRpgSheet(context, builder: (_) => _TermSheet(info: info));
}

class _TermSheet extends StatelessWidget {
  const _TermSheet({required this.info});
  final TermInfo info;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(Gap.lg, 0, Gap.lg, Gap.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(info.title, style: AppText.ui(20, weight: FontWeight.w600)),
            const SizedBox(height: Gap.sm),
            Text(info.what, style: AppText.ui(15, height: 1.5)),
            if (info.how != null) _Section('Как получить', info.how!),
            if (info.where != null) _Section('Где используется', info.where!),
          ],
        ),
      );
}

class _Section extends StatelessWidget {
  const _Section(this.label, this.text);
  final String label;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: Gap.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label.toUpperCase(), style: AppText.label()),
            const SizedBox(height: 6),
            Text(text, style: AppText.ui(14.5, color: AppColors.textSecondary, height: 1.5)),
          ],
        ),
      );
}

/// Wraps any badge or value: long-press opens its explanation.
class Explain extends ConsumerWidget {
  const Explain({super.key, this.term, this.info, required this.child})
      : assert(term != null || info != null);

  final Term? term;
  final TermInfo? info;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cfg = ref.watch(engineProvider).config;
    final i = info ?? termInfo(term!, cfg);
    return Semantics(
      onLongPressHint: 'подробнее: ${i.title}',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onLongPress: () => showTermInfo(context, i),
        child: child,
      ),
    );
  }
}

/// One-time hint on the home screen about long-press explanations.
class LongPressHint extends ConsumerStatefulWidget {
  const LongPressHint({super.key});

  @override
  ConsumerState<LongPressHint> createState() => _LongPressHintState();
}

class _LongPressHintState extends ConsumerState<LongPressHint> {
  static const _key = 'hint_long_press_seen';

  @override
  Widget build(BuildContext context) {
    final prefs = ref.watch(appPrefsProvider);
    if (prefs.get(_key) == '1') return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.fromLTRB(Gap.md, Gap.xs, Gap.xs, Gap.xs),
      decoration: BoxDecoration(
        borderRadius: Radii.rLg,
        border: Border.all(color: AppColors.border),
      ),
      child: Row(children: [
        Expanded(
          child: Text('Зажмите любой значок или число, чтобы узнать, что оно значит.',
              style: AppText.ui(13.5, color: AppColors.textSecondary)),
        ),
        IconButton(
          tooltip: 'Понятно',
          onPressed: () async {
            await prefs.put(_key, '1');
            if (mounted) setState(() {});
          },
          icon: const Icon(Icons.close_rounded, size: 18, color: AppColors.textMuted),
        ),
      ]),
    );
  }
}
