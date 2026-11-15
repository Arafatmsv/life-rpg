import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_theme.dart';
import '../../app/theme/app_tokens.dart';
import '../../core/game/achievement_catalog.dart';
import '../../core/responsive/responsive.dart';
import '../../core/utils/day.dart';
import '../../core/widgets/rpg_scaffold.dart';
import '../../core/widgets/feedback.dart';
import '../../core/widgets/progress.dart';
import '../../core/widgets/rpg_card.dart';
import '../../core/widgets/rpg_icons.dart';
import '../../core/widgets/states.dart';
import '../../data/models/enums.dart';
import '../../data/models/quest.dart';
import '../character/character_widgets.dart';
import '../game/game_controller.dart';
import '../quests/quest_card.dart';
import '../quests/quest_editor.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(gameControllerProvider).valueOrNull;
    final snap = ref.watch(snapshotProvider);
    if (s == null || snap == null || s.character == null) {
      return const Scaffold(body: LoadingView());
    }
    final e = ref.watch(engineProvider);
    final ch = s.character!;
    final today = snap.today;

    final dueToday = s.liveQuests
        .where((q) => q.isOpen && q.periodKind == PeriodKind.day && e.isDueToday(s, q))
        .toList();
    final doneToday = dueToday.where((q) => e.isDoneThisPeriod(s, q)).length;
    final pending = s.liveQuests
        .where((q) =>
            q.isOpen &&
            !e.isDoneThisPeriod(s, q) &&
            (q.periodKind == PeriodKind.day
                ? e.isDueToday(s, q)
                : q.periodKind == PeriodKind.week || q.isRecovery || q.type == QuestType.side))
        .toList()
      ..sort((a, b) => a.type.index - b.type.index);
    final missions = s.liveQuests
        .where((q) => q.isOpen && q.type.isMission)
        .toList()
      ..sort((a, b) => (a.dueDay ?? '9999').compareTo(b.dueDay ?? '9999'));
    final recentAch = s.achievements.values.toList()..sort((a, b) => b.unlockedAt.compareTo(a.unlockedAt));
    final openPenalties = s.penalties.values.where((p) => !p.status.isResolved).length;
    final isRest = s.dayMarks[today]?.kind == DayMarkKind.rest || s.settings.vacationMode;

    final header = CharacterHeader(character: ch, snap: snap, large: context.windowSize.atLeastExpanded);

    final daily = RpgCard(
      child: Row(
        children: [
          ProgressRing(
            value: dueToday.isEmpty ? 0 : doneToday / dueToday.length,
            color: AppColors.success,
            size: 72,
            stroke: 6,
            child: Text('$doneToday/${dueToday.length}', style: AppText.number(15)),
          ),
          const SizedBox(width: Gap.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Прогресс дня', style: AppText.ui(15, weight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(
                  isRest
                      ? 'Сегодня день отдыха — серия под защитой'
                      : dueToday.isEmpty
                          ? 'Ежедневных заданий нет'
                          : doneToday == dueToday.length
                              ? 'Все ежедневные задания выполнены!'
                              : 'Осталось ${dueToday.length - doneToday} '
                                  '${plural(dueToday.length - doneToday, 'задание', 'задания', 'заданий')}',
                  style: AppText.ui(13, color: AppColors.textSecondary),
                ),
                const SizedBox(height: Gap.xs),
                Wrap(spacing: 6, runSpacing: 4, children: [
                  Pill('+${snap.xpToday} XP сегодня', color: AppColors.violetBright, icon: Icons.auto_awesome_rounded),
                  if (snap.xpToday >= e.config.dailyXpSoftCap)
                    const Pill('Дневной лимит XP', color: AppColors.warning),
                ]),
              ],
            ),
          ),
        ],
      ),
    );

    final attrs = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader('Характеристики', action: 'Подробнее', onAction: () => context.go('/character')),
        LayoutBuilder(builder: (context, c) {
          final cols = c.maxWidth > 520 ? 3 : 2;
          final w = (c.maxWidth - Gap.xs * (cols - 1)) / cols;
          return Wrap(
            spacing: Gap.xs,
            runSpacing: Gap.xs,
            children: [
              for (final a in AttributeType.values)
                SizedBox(
                  width: w,
                  child: AttributeTile(
                    attribute: a,
                    level: snap.attributeLevels[a]!,
                    focus: ch.focus.contains(a),
                  ),
                ),
            ],
          );
        }),
      ],
    );

    final quests = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader('Активные задания',
            subtitle: humanDay(today), action: 'Все', onAction: () => context.go('/quests')),
        if (openPenalties > 0) ...[
          RpgCard(
            padding: const EdgeInsets.all(Gap.sm),
            borderColor: AppColors.warning.o(0.4),
            onTap: () => context.push('/profile/penalties'),
            child: Row(children: [
              const Icon(Icons.healing_rounded, color: AppColors.warning),
              const SizedBox(width: Gap.sm),
              Expanded(
                child: Text(
                  'Есть $openPenalties ${plural(openPenalties, 'пропуск', 'пропуска', 'пропусков')} — '
                  'их можно восстановить или перенести',
                  style: AppText.ui(13, color: AppColors.textSecondary),
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
            ]),
          ),
          const SizedBox(height: Gap.xs),
        ],
        if (pending.isEmpty)
          RpgCard(
            child: EmptyState(
              compact: true,
              icon: Icons.done_all_rounded,
              title: dueToday.isEmpty ? 'Чистый лист' : 'Всё сделано',
              message: dueToday.isEmpty
                  ? 'Создайте первое задание — опыт начнёт копиться.'
                  : 'Отличная работа. Можно отдохнуть или взять побочное задание.',
              actionLabel: 'Новое задание',
              onAction: () => openQuestEditor(context),
            ),
          )
        else
          for (final q in pending.take(6)) ...[
            QuestCard(quest: q, dense: true),
            const SizedBox(height: Gap.xs),
          ],
      ],
    );

    final missionsBlock = missions.isEmpty
        ? null
        : Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SectionHeader('Миссии и испытания', action: 'Все', onAction: () => context.go('/quests')),
              for (final q in missions.take(4)) ...[
                _MissionTile(quest: q),
                const SizedBox(height: Gap.xs),
              ],
            ],
          );

    final streak = RpgCard(
      onTap: () => context.push('/profile/streaks'),
      child: Row(children: [
        IconTile(Icons.local_fire_department_rounded, color: AppColors.warning, size: 48),
        const SizedBox(width: Gap.md),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${snap.streak.current} ${plural(snap.streak.current, 'день', 'дня', 'дней')} подряд',
                style: AppText.ui(16, weight: FontWeight.w700)),
            Text('Рекорд: ${snap.streak.longest} · успешных дней: ${snap.streak.successfulDays}',
                style: AppText.ui(12.5, color: AppColors.textMuted)),
          ]),
        ),
        TextButton(
          onPressed: s.settings.vacationMode
              ? null
              : () => runGameAction(context, ref, (e, st) => e.toggleRestDay(st, today),
                  success: isRest ? 'День отдыха отменён' : 'Сегодня — день отдыха. Серия под защитой'),
          child: Text(isRest ? 'Отменить отдых' : 'День отдыха'),
        ),
      ]),
    );

    final achievements = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader('Последние достижения',
            action: 'Коллекция', onAction: () => context.push('/profile/achievements')),
        if (recentAch.isEmpty)
          RpgCard(
            child: Text('Выполните первое задание, чтобы получить «First Step».',
                style: AppText.ui(13, color: AppColors.textSecondary)),
          )
        else
          SizedBox(
            height: 104,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: recentAch.length.clamp(0, 8),
              separatorBuilder: (_, __) => const SizedBox(width: Gap.xs),
              itemBuilder: (_, i) {
                final def = achievementById[recentAch[i].achievementId];
                if (def == null) return const SizedBox.shrink();
                final c = AppColors.rarity(def.rarity);
                return SizedBox(
                  width: 132,
                  child: RpgCard(
                    padding: const EdgeInsets.all(Gap.sm),
                    glow: c,
                    onTap: () => context.push('/profile/achievements'),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Icon(RpgIcons.byKey(def.icon), color: c),
                      const Spacer(),
                      Text(def.title,
                          maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.ui(13, weight: FontWeight.w700)),
                      Text(def.rarity.tag, style: AppText.ui(11, color: c, weight: FontWeight.w700)),
                    ]),
                  ),
                );
              },
            ),
          ),
      ],
    );

    return RpgScaffold(
      floatingActionButton: FloatingActionButton(
        tooltip: 'Новое задание',
        onPressed: () => openQuestEditor(context),
        child: const Icon(Icons.add_rounded),
      ),
      body: SafeArea(
        bottom: false,
        child: AdaptiveBuilder(builder: (context, size, c) {
          final pad = EdgeInsets.fromLTRB(size.gutter, Gap.md, size.gutter, 96);
          if (size.atLeastExpanded) {
            return SingleChildScrollView(
              padding: pad,
              child: ContentWidth(
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(
                    flex: 5,
                    child: _col([header, daily, streak, attrs, achievements]),
                  ),
                  const SizedBox(width: Gap.xl),
                  Expanded(flex: 6, child: _col([quests, if (missionsBlock != null) missionsBlock])),
                ]),
              ),
            );
          }
          if (size == WindowSize.medium) {
            return SingleChildScrollView(
              padding: pad,
              child: _col([
                header,
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(child: daily),
                  const SizedBox(width: Gap.md),
                  Expanded(child: streak),
                ]),
                quests,
                if (missionsBlock != null) missionsBlock,
                attrs,
                achievements,
              ]),
            );
          }
          return ListView(
            padding: pad,
            children: [
              _col([header, daily, quests, if (missionsBlock != null) missionsBlock, attrs, streak, achievements]),
            ],
          );
        }),
      ),
    );
  }

  Widget _col(List<Widget> children) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const SizedBox(height: Gap.lg),
            children[i],
          ],
        ],
      );
}

class _MissionTile extends ConsumerWidget {
  const _MissionTile({required this.quest});
  final Quest quest;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(gameControllerProvider).valueOrNull!;
    final e = ref.watch(engineProvider);
    final q = quest;
    final boss = q.type == QuestType.boss;
    final value = boss
        ? e.progressFor(s, q.id, 'once') / q.targetAmount
        : (q.subtasks.isEmpty ? 0.0 : q.subtaskProgress);
    final color = boss ? AppColors.danger : AppColors.gold;
    return RpgCard(
      padding: const EdgeInsets.all(Gap.sm),
      onTap: () => context.push('/quests/${q.id}'),
      child: Row(children: [
        ProgressRing(
          value: value,
          color: color,
          size: 46,
          stroke: 4,
          child: Icon(RpgIcons.questType(q.type), size: 18, color: color),
        ),
        const SizedBox(width: Gap.sm),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(q.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.ui(14.5, weight: FontWeight.w700)),
            Text(
              [
                q.type.label,
                '${(value * 100).round()}%',
                if (q.dueDay != null) 'до ${humanDay(q.dueDay!)}',
              ].join(' · '),
              style: AppText.ui(12, color: AppColors.textMuted),
            ),
          ]),
        ),
        Text('+${q.xpReward}', style: AppText.number(13, color: AppColors.violetBright)),
      ]),
    );
  }
}
