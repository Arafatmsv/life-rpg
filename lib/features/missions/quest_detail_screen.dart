import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_theme.dart';
import '../../app/theme/app_tokens.dart';
import '../../core/game/game_clock.dart';
import '../../core/responsive/responsive.dart';
import '../../core/utils/day.dart';
import '../../core/widgets/buttons.dart';
import '../../core/widgets/feedback.dart';
import '../../core/widgets/progress.dart';
import '../../core/widgets/rpg_card.dart';
import '../../core/widgets/states.dart';
import '../../data/models/enums.dart';
import '../../data/models/quest.dart';
import '../game/game_controller.dart';
import '../help/glossary.dart';
import '../quests/quest_card.dart';
import '../quests/quest_editor.dart';

/// Details of any quest; for main quests and bosses this is the mission
/// screen with subtasks, check-ins and history.
class QuestDetailScreen extends ConsumerWidget {
  const QuestDetailScreen({super.key, required this.questId});
  final String questId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(gameControllerProvider).valueOrNull;
    if (s == null) return const Scaffold(body: LoadingView());
    final q = s.quests[questId];
    if (q == null || q.deleted) {
      return Scaffold(
        appBar: AppBar(),
        body: const EmptyState(
          icon: Icons.search_off_rounded,
          title: 'Задание не найдено',
          message: 'Возможно, оно было удалено на другом устройстве.',
        ),
      );
    }
    final e = ref.watch(engineProvider);
    final tz = s.settings.tzOffsetMinutes;
    final history = s.completions.values.where((c) => c.questId == q.id).toList()
      ..sort((a, b) => b.completedAt.compareTo(a.completedAt));
    final period = e.currentPeriod(s, q);
    final current = e.completionFor(s, q.id, period);
    final quote = e.quote(s, q);
    final penalties = s.penalties.values.where((p) => p.questId == q.id).toList()
      ..sort((a, b) => b.dayKey.compareTo(a.dayKey));
    final canRevert = current != null &&
        DateTime.now().difference(current.completedAt) < e.config.revertWindow;

    final main = <Widget>[
      RpgCard(
        padding: const EdgeInsets.all(Gap.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(q.type.label.toUpperCase(), style: AppText.label(color: AppColors.questType(q.type))),
                  const SizedBox(height: 2),
                  Text(q.title, style: AppText.display(26)),
                ]),
              ),
            ]),
            if (q.description.isNotEmpty) ...[
              const SizedBox(height: Gap.md),
              Text(q.description, style: AppText.ui(14.5, color: AppColors.textSecondary, height: 1.5)),
            ],
            const SizedBox(height: Gap.md),
            Wrap(spacing: 6, runSpacing: 6, children: [
              Pill(q.status.label,
                  color: q.status == QuestStatus.failed ? AppColors.danger : AppColors.textSecondary),
            ]),
            const SizedBox(height: Gap.sm),
            Explain(
              info: questTypeInfo(q.type, e.config),
              child: Text(
                [
                  q.attribute.label,
                  q.difficulty.label,
                  if (q.isRecurring) q.recurrence.describe(),
                  if (q.dueDay != null) 'срок ${humanDayYear(q.dueDay!)}',
                  if (q.reminderTime != null) 'напоминание ${q.reminderTime}',
                  if (q.durationMinutes != null) '${q.durationMinutes} мин',
                ].join(' · '),
                style: AppText.ui(13, color: AppColors.textSecondary),
              ),
            ),
            Wrap(spacing: 6, runSpacing: 6, children: [
            ]),
          ],
        ),
      ),
      if (q.usesCheckIns) _BossProgress(quest: q),
      if (q.isMeasured) _MeasuredProgress(quest: q, period: period),
      if (q.type == QuestType.main) _Subtasks(quest: q),
    ];

    final side = <Widget>[
      RpgCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('НАГРАДА', style: AppText.label()),
            const SizedBox(height: Gap.xs),
            Row(children: [
              Explain(term: Term.xp, child: Text('+${quote.totalXp} XP', style: AppText.number(24, color: AppColors.text))),
              const SizedBox(width: Gap.md),
              Explain(term: Term.gold, child: Text('+${quote.gold} Gold', style: AppText.number(16, color: AppColors.textSecondary))),
            ]),
            const SizedBox(height: 6),
            Text(quote.describe(), style: AppText.ui(12.5, color: AppColors.textMuted)),
            if (quote.disciplineXp > 0)
              Text('включая +${quote.disciplineXp} XP к дисциплине за регулярность',
                  style: AppText.ui(12.5, color: AppColors.textMuted)),
            if (quote.goldCapped)
              Explain(term: Term.dailyCap, child: Text('Дневной лимит Gold за задания достигнут', style: AppText.ui(12.5, color: AppColors.textSecondary))),
            if (q.usesCheckIns)
              Text('+${e.config.bossCheckInXp} XP за каждую ежедневную отметку',
                  style: AppText.ui(12.5, color: AppColors.textMuted)),
            const SizedBox(height: Gap.md),
            if (q.isOpen && current == null && e.isDueToday(s, q))
              RpgButton(
                label: q.usesCheckIns
                    ? 'Отметить сегодняшний день'
                    : q.isMeasured
                        ? 'Добавить прогресс'
                        : q.type == QuestType.main
                            ? 'Завершить миссию'
                            : 'Выполнить',
                icon: Icons.check_rounded,
                expand: true,
                onPressed: () => performQuestAction(context, ref, q),
              )
            else if (current != null || q.status == QuestStatus.completed)
              Row(children: [
                Expanded(
                  child: Text(
                    q.isRecurring ? 'Выполнено в этом периоде' : 'Выполнено',
                    style: AppText.ui(14, weight: FontWeight.w500, color: AppColors.textSecondary),
                  ),
                ),
              ])
            else if (q.isOpen)
              Text('Сегодня не запланировано', style: AppText.ui(13, color: AppColors.textMuted)),
            if (canRevert) ...[
              const SizedBox(height: Gap.sm),
              RpgButton(
                label: 'Отменить выполнение',
                icon: Icons.undo_rounded,
                kind: RpgButtonKind.ghost,
                expand: true,
                onPressed: () async {
                  final ok = await confirm(context,
                      title: 'Отменить выполнение?',
                      message: 'Начисленные ${current.xp} XP и ${current.gold} Gold будут списаны. '
                          'Отменить можно в течение 24 часов.');
                  if (ok && context.mounted) {
                    await runGameAction(context, ref, (e, s) => e.revertCompletion(s, current.id),
                        success: 'Выполнение отменено');
                  }
                },
              ),
            ],
          ],
        ),
      ),
      RpgCard(
        padding: const EdgeInsets.symmetric(vertical: Gap.xs),
        child: Column(children: [
          ListTile(
            leading: const Icon(Icons.edit_rounded),
            title: const Text('Редактировать'),
            onTap: () => openQuestEditor(context, quest: q),
          ),
          if (q.status == QuestStatus.active)
            ListTile(
              leading: const Icon(Icons.pause_circle_outline_rounded),
              title: const Text('Поставить на паузу'),
              subtitle: const Text('Пропуски на паузе не считаются'),
              onTap: () => runGameAction(context, ref, (e, s) => e.setQuestStatus(s, q.id, QuestStatus.paused),
                  success: 'Задание на паузе'),
            ),
          if (q.status == QuestStatus.paused || q.status == QuestStatus.archived)
            ListTile(
              leading: const Icon(Icons.play_circle_outline_rounded),
              title: const Text('Возобновить'),
              onTap: () => runGameAction(context, ref, (e, s) => e.setQuestStatus(s, q.id, QuestStatus.active),
                  success: 'Задание снова активно'),
            ),
          if (q.status == QuestStatus.failed)
            ListTile(
              leading: const Icon(Icons.event_repeat_rounded),
              title: const Text('Перенести на новую дату'),
              onTap: () => openQuestEditor(context, quest: q),
            ),
          if (q.status != QuestStatus.archived)
            ListTile(
              leading: const Icon(Icons.inventory_2_outlined),
              title: const Text('В архив'),
              onTap: () => runGameAction(context, ref, (e, s) => e.setQuestStatus(s, q.id, QuestStatus.archived),
                  success: 'Перемещено в архив'),
            ),
          ListTile(
            leading: const Icon(Icons.delete_outline_rounded, color: AppColors.danger),
            title: Text('Удалить', style: AppText.ui(15, weight: FontWeight.w600, color: AppColors.danger)),
            subtitle: const Text('Полученный опыт сохранится'),
            onTap: () async {
              final ok = await confirm(context,
                  title: 'Удалить задание?',
                  message: '«${q.title}» исчезнет из списка. Уже полученные XP и Gold останутся.',
                  confirmLabel: 'Удалить',
                  destructive: true);
              if (ok && context.mounted) {
                final done = await runGameAction(context, ref, (e, s) => e.deleteQuest(s, q.id),
                    success: 'Задание удалено');
                if (done && context.mounted) context.pop();
              }
            },
          ),
        ]),
      ),
      RpgCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('ИСТОРИЯ', style: AppText.label()),
            const SizedBox(height: Gap.xs),
            if (history.isEmpty && penalties.isEmpty)
              Text('Пока нет записей', style: AppText.ui(13, color: AppColors.textMuted)),
            for (final c in history.take(30))
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Row(children: [
                  Icon(c.isActive ? Icons.check_circle_rounded : Icons.undo_rounded,
                      size: 16, color: c.isActive ? AppColors.textSecondary : AppColors.textMuted),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${humanDay(GameClock.dayOf(c.completedAt, tz))}, '
                      '${two(GameClock.toWall(c.completedAt, tz).hour)}:${two(GameClock.toWall(c.completedAt, tz).minute)}'
                      '${c.isActive ? '' : ' · отменено'}',
                      style: AppText.ui(13, color: AppColors.textSecondary),
                    ),
                  ),
                  Text('+${c.xp} XP',
                      style: AppText.number(12.5, color: c.isActive ? AppColors.text : AppColors.textMuted)),
                ]),
              ),
            for (final p in penalties.take(10))
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Row(children: [
                  Icon(Icons.flag_outlined, size: 16, color: AppColors.severity(p.severity)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text('${humanDay(p.dayKey)} · пропуск · ${p.status.label.toLowerCase()}',
                        style: AppText.ui(13, color: AppColors.textSecondary)),
                  ),
                ]),
              ),
          ],
        ),
      ),
    ];

    return Scaffold(
      appBar: AppBar(title: Text(q.type.isMission ? 'Миссия' : 'Задание')),
      body: AdaptiveBuilder(builder: (context, size, c) {
        final pad = EdgeInsets.fromLTRB(size.gutter, Gap.sm, size.gutter, Gap.xxl);
        if (size.atLeastExpanded) {
          return SingleChildScrollView(
            padding: pad,
            child: ContentWidth(
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(flex: 3, child: _stack(main)),
                const SizedBox(width: Gap.lg),
                Expanded(flex: 2, child: _stack(side)),
              ]),
            ),
          );
        }
        return ListView(padding: pad, children: [ContentWidth(maxWidth: 720, child: _stack([...main, ...side]))]);
      }),
    );
  }

  Widget _stack(List<Widget> children) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const SizedBox(height: Gap.md),
            children[i],
          ],
        ],
      );
}

class _Subtasks extends ConsumerWidget {
  const _Subtasks({required this.quest});
  final Quest quest;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final q = quest;
    final done = q.subtasks.where((t) => t.done).length;
    return RpgCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(child: Text('ПОДЗАДАЧИ', style: AppText.label())),
            Text('$done / ${q.subtasks.length}', style: AppText.number(13, color: AppColors.textSecondary)),
          ]),
          const SizedBox(height: Gap.sm),
          XpBar(value: q.subtaskProgress, height: 8),
          const SizedBox(height: Gap.sm),
          if (q.subtasks.isEmpty)
            Text('Разбейте миссию на шаги: каждый даёт +5 XP. Без подзадач миссию можно завершить целиком.',
                style: AppText.ui(13, color: AppColors.textMuted)),
          for (final st in q.subtasks)
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              value: st.done,
              onChanged: q.isOpen
                  ? (_) => runGameAction(context, ref, (e, s) => e.toggleSubtask(s, q.id, st.id))
                  : null,
              title: Text(st.title,
                  style: AppText.ui(14.5).copyWith(
                    decoration: st.done ? TextDecoration.lineThrough : null,
                    color: st.done ? AppColors.textMuted : AppColors.text,
                  )),
              secondary: st.rewarded
                  ? Text('+5', style: AppText.number(12, color: AppColors.textMuted))
                  : null,
            ),
          TextButton.icon(
            onPressed: () => openQuestEditor(context, quest: q),
            icon: const Icon(Icons.add_rounded),
            label: const Text('Добавить подзадачи'),
          ),
        ],
      ),
    );
  }
}

class _BossProgress extends ConsumerWidget {
  const _BossProgress({required this.quest});
  final Quest quest;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(gameControllerProvider).valueOrNull!;
    final e = ref.watch(engineProvider);
    final days = s.progress.values.where((p) => p.questId == quest.id).map((p) => p.dayKey).toSet();
    final n = days.length;
    final today = e.today(s);
    // Last 5 weeks of check-ins.
    final from = addDays(today, -34);
    return RpgCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(child: Explain(term: Term.boss, child: Text('ХОД ИСПЫТАНИЯ', style: AppText.label()))),
            Text('$n / ${quest.targetAmount}', style: AppText.number(16, color: AppColors.text)),
          ]),
          const SizedBox(height: Gap.sm),
          XpBar(value: n / quest.targetAmount, height: 4),
          const SizedBox(height: Gap.md),
          Wrap(spacing: 4, runSpacing: 4, children: [
            for (final d in dayRange(from, today))
              Tooltip(
                message: humanDay(d),
                child: Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    color: days.contains(d) ? Theme.of(context).colorScheme.primary : AppColors.surface3,
                    borderRadius: BorderRadius.circular(4),
                    border: d == today ? Border.all(color: AppColors.text, width: 1.2) : null,
                  ),
                ),
              ),
          ]),
          const SizedBox(height: Gap.xs),
          Text('Последние 5 недель. Одна отметка в день.', style: AppText.ui(12, color: AppColors.textMuted)),
        ],
      ),
    );
  }
}

class _MeasuredProgress extends ConsumerWidget {
  const _MeasuredProgress({required this.quest, required this.period});
  final Quest quest;
  final String period;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(gameControllerProvider).valueOrNull!;
    final e = ref.watch(engineProvider);
    final value = e.progressFor(s, quest.id, period);
    final logs = s.progress.values.where((p) => p.questId == quest.id && p.periodKey == period).toList()
      ..sort((a, b) => b.loggedAt.compareTo(a.loggedAt));
    final color = AppColors.attribute(quest.attribute);
    return RpgCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(quest.periodKind == PeriodKind.week ? 'ПРОГРЕСС НЕДЕЛИ' : 'ПРОГРЕСС', style: AppText.label()),
          const SizedBox(height: Gap.xs),
          Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('$value', style: AppText.number(30, color: color)),
            const SizedBox(width: 6),
            Padding(
              padding: const EdgeInsets.only(bottom: 5),
              child: Text('/ ${quest.targetAmount} ${quest.unit.label}',
                  style: AppText.ui(14, color: AppColors.textSecondary)),
            ),
          ]),
          const SizedBox(height: Gap.sm),
          XpBar(value: value / quest.targetAmount, colors: [color.o(0.6), color]),
          if (logs.isNotEmpty) ...[
            const SizedBox(height: Gap.sm),
            for (final l in logs.take(8))
              StatLine(
                '${humanDay(l.dayKey)}, ${two(l.loggedAt.hour)}:${two(l.loggedAt.minute)}',
                '${l.amount > 0 ? '+' : ''}${l.amount} ${quest.unit.short}',
                color: l.amount > 0 ? AppColors.text : AppColors.textMuted,
              ),
          ],
        ],
      ),
    );
  }
}
