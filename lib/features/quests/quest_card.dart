import '../../core/widgets/rpg_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_theme.dart';
import '../../app/theme/app_tokens.dart';
import '../../core/utils/day.dart';
import '../../core/widgets/feedback.dart';
import '../../core/widgets/motion.dart';
import '../../core/widgets/progress.dart';
import '../../core/widgets/rpg_card.dart';
import '../../data/models/enums.dart';
import '../../data/models/quest.dart';
import '../game/game_controller.dart';
import '../help/glossary.dart';

/// Primary action of a quest from a list: complete, log progress or
/// check in. Shared by the card and the detail screen.
Future<void> performQuestAction(BuildContext context, WidgetRef ref, Quest q) async {
  if (q.usesCheckIns) {
    await runGameAction(context, ref, (e, s) => e.checkInBoss(s, q.id));
    return;
  }
  if (q.usesSubtasks && q.subtasks.any((t) => !t.done)) {
    context.push('/quests/${q.id}');
    return;
  }
  if (q.isMeasured) {
    final n = await askNumber(
      context,
      title: q.title,
      hint: 'Сколько добавить?',
      suffix: q.unit.short,
    );
    if (n == null || !context.mounted) return;
    await runGameAction(context, ref, (e, s) => e.logProgress(s, q.id, n));
    return;
  }
  await runGameAction(context, ref, (e, s) => e.completeQuest(s, q.id));
}

class QuestCard extends ConsumerWidget {
  const QuestCard({super.key, required this.quest, this.dense = false});

  final Quest quest;
  final bool dense;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(gameControllerProvider).valueOrNull;
    if (s == null) return const SizedBox.shrink();
    final e = ref.watch(engineProvider);
    final q = quest;
    final color = AppColors.attribute(q.attribute);
    final period = e.currentPeriod(s, q);
    final done = e.completionFor(s, q.id, period) != null || q.status == QuestStatus.completed;
    final failed = q.status == QuestStatus.failed;
    final dueToday = e.isDueToday(s, q);
    final progress = q.usesCheckIns
        ? e.progressFor(s, q.id, 'once')
        : e.progressFor(s, q.id, period);
    final checkedInToday = q.usesCheckIns &&
        s.progress.values.any((p) => p.questId == q.id && p.dayKey == e.today(s));
    final xp = q.isOpen && !done ? e.quote(s, q).totalXp : q.xpReward;

    double? bar;
    String? barLabel;
    if (q.usesCheckIns) {
      bar = progress / q.targetAmount;
      barLabel = '$progress / ${q.targetAmount} дн.';
    } else if (q.isMeasured) {
      bar = done ? 1 : progress / q.targetAmount;
      barLabel = '${done ? q.targetAmount : progress} / ${q.targetAmount} ${q.unit.short}';
    } else if (q.type == QuestType.main && q.subtasks.isNotEmpty) {
      bar = q.subtaskProgress;
      barLabel = '${q.subtasks.where((t) => t.done).length} / ${q.subtasks.length} подзадач';
    }

    final canAct = q.isOpen && !done && dueToday && !checkedInToday;
    return Opacity(
      opacity: failed || (!dueToday && !done && q.isRecurring) ? 0.6 : 1,
      child: RpgCard(
        padding: EdgeInsets.all(dense ? Gap.sm : Gap.md),
        onTap: () => context.push('/quests/${q.id}'),

        semanticLabel: '${q.title}, ${done ? 'выполнено' : 'не выполнено'}',
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _CheckButton(
              done: done || checkedInToday,
              enabled: canAct,
              color: color,
              icon: q.usesCheckIns
                  ? Icons.whatshot_rounded
                  : q.isMeasured
                      ? Icons.add_rounded
                      : Icons.check_rounded,
              tooltip: q.usesCheckIns
                  ? 'Отметить день испытания'
                  : q.isMeasured
                      ? 'Добавить прогресс'
                      : 'Выполнить',
              onTap: () => performQuestAction(context, ref, q),
            ),
            const SizedBox(width: Gap.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          q.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.ui(15, weight: FontWeight.w500).copyWith(
                            decoration: done && !q.isRecurring ? TextDecoration.lineThrough : null,
                            decorationColor: AppColors.textMuted,
                            color: done ? AppColors.textSecondary : AppColors.text,
                          ),
                        ),
                      ),
                      const SizedBox(width: Gap.xs),
                      Explain(
                        term: Term.xp,
                        child: Text('+$xp XP',
                            style: AppText.number(13, color: done ? AppColors.textMuted : AppColors.textSecondary)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  // One quiet meta line instead of a row of coloured tags.
                  Explain(
                    info: questTypeInfo(q.type, e.config),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 1, right: 6),
                        child: Icon(RpgIcons.questType(q.type), size: 14, color: AppColors.textMuted),
                      ),
                      Expanded(child: Text(
                      [
                        q.type.label,
                        q.attribute.label,
                        if (!dense) q.difficulty.label,
                        if (q.recurrence.kind == RecurrenceKind.weekdays ||
                            q.recurrence.kind == RecurrenceKind.interval)
                          q.recurrence.describe(),
                        if (q.durationMinutes != null && !dense) '${q.durationMinutes} мин',
                        if (q.isRecurring && !dueToday && !done) 'не сегодня',
                      ].join(' · '),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.ui(12.5, color: AppColors.textMuted),
                    )),
                    ]),
                  ),
                  if (q.isRecovery || failed || (q.dueDay != null && q.periodKind == PeriodKind.once && !done)) ...[
                    const SizedBox(height: 6),
                    Wrap(spacing: 6, runSpacing: 4, children: [
                      if (q.isRecovery) const Explain(term: Term.recovery, child: Pill('Восстановление')),
                      if (failed) const Pill('Провалено', color: AppColors.danger, filled: true),
                      if (q.dueDay != null && q.periodKind == PeriodKind.once && !done)
                        _DuePill(q.dueDay!, e.today(s)),
                    ]),
                  ],
                  if (bar != null) ...[
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(child: XpBar(value: bar, height: 3)),
                        const SizedBox(width: Gap.xs),
                        Text(barLabel!, style: AppText.number(11.5, color: AppColors.textMuted)),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DuePill extends StatelessWidget {
  const _DuePill(this.due, this.today);
  final String due;
  final String today;

  @override
  Widget build(BuildContext context) {
    final left = daysBetween(today, due);
    final (text, color) = left < 0
        ? ('Просрочено', AppColors.danger)
        : left == 0
            ? ('Срок сегодня', AppColors.text)
            : left == 1
                ? ('Срок завтра', AppColors.textSecondary)
                : ('До ${humanDay(due)}', AppColors.textSecondary);
    return Pill(text, color: color);
  }
}

class _CheckButton extends StatefulWidget {
  const _CheckButton({
    required this.done,
    required this.enabled,
    required this.color,
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final bool done;
  final bool enabled;
  final Color color;
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  State<_CheckButton> createState() => _CheckButtonState();
}

class _CheckButtonState extends State<_CheckButton> with SingleTickerProviderStateMixin {
  late final _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 450));

  @override
  void didUpdateWidget(_CheckButton old) {
    super.didUpdateWidget(old);
    if (!old.done && widget.done && Motion.enabled(context)) _pulse.forward(from: 0);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.done ? Theme.of(context).colorScheme.primary : AppColors.textSecondary;
    return Tooltip(
      message: widget.done ? 'Выполнено' : widget.tooltip,
      child: Semantics(
        button: true,
        enabled: widget.enabled,
        label: widget.done ? 'Выполнено' : widget.tooltip,
        child: InkResponse(
          onTap: widget.enabled ? widget.onTap : null,
          radius: 28,
          child: SizedBox(
            width: kMinTap,
            height: kMinTap,
            child: Center(
              child: AnimatedBuilder(
                animation: _pulse,
                builder: (context, child) => Transform.scale(
                  scale: 1 + Curves.easeOut.transform(1 - (_pulse.value - 0.5).abs() * 2) * 0.18 * (_pulse.isAnimating ? 1 : 0),
                  child: child,
                ),
                child: AnimatedContainer(
                  duration: Durations2.medium,
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: widget.done ? c : Colors.transparent,
                    border: Border.all(color: widget.done ? c : (widget.enabled ? AppColors.textSecondary : AppColors.border), width: 1.4),
                  ),
                  child: AnimatedSwitcher(
                    duration: Durations2.fast,
                    transitionBuilder: (child, a) => ScaleTransition(scale: a, child: child),
                    child: Icon(
                      widget.done ? Icons.check_rounded : widget.icon,
                      key: ValueKey(widget.done),
                      size: 18,
                      color: widget.done ? AppColors.bg : (widget.enabled ? AppColors.text : AppColors.textMuted),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
