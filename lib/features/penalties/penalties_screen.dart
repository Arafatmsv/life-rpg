import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_theme.dart';
import '../../app/theme/app_tokens.dart';
import '../../core/responsive/responsive.dart';
import '../../core/utils/day.dart';
import '../../core/widgets/feedback.dart';
import '../../core/widgets/rpg_card.dart';
import '../../core/widgets/states.dart';
import '../../data/models/enums.dart';
import '../../data/models/penalty.dart';
import '../game/game_controller.dart';

/// The log of missed obligations and the ways back.
class PenaltiesScreen extends ConsumerWidget {
  const PenaltiesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(gameControllerProvider).valueOrNull;
    if (s == null) return const Scaffold(body: LoadingView());
    final e = ref.watch(engineProvider);
    final all = s.penalties.values.toList()..sort((a, b) => b.dayKey.compareTo(a.dayKey));
    final open = all.where((p) => !p.status.isResolved).toList();
    final closed = all.where((p) => p.status.isResolved).toList();
    final excusesLeft = s.settings.recoveryDaysPerMonth - e.excusesUsedThisMonth(s);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Журнал последствий'),
        actions: [
          IconButton(
            tooltip: 'Настройки последствий',
            onPressed: () => context.push('/profile/settings/penalties'),
            icon: const Icon(Icons.tune_rounded),
          ),
        ],
      ),
      body: AdaptiveBuilder(builder: (context, size, c) => ListView(
            padding: EdgeInsets.fromLTRB(size.gutter, Gap.xs, size.gutter, Gap.xxl),
            children: [
              ContentWidth(
                maxWidth: 820,
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  RpgCard(
                    child: Row(children: [
                      const IconTile(Icons.healing_rounded, color: AppColors.success, size: 46),
                      const SizedBox(width: Gap.md),
                      Expanded(
                        child: Text(
                          s.settings.penaltiesEnabled
                              ? 'Пропуск не стирает прогресс. Выполните восстановительное задание, '
                                  'перенесите дело или отметьте уважительную причину '
                                  '(осталось в этом месяце: $excusesLeft).'
                              : 'Последствия выключены в настройках — пропуски не фиксируются.',
                          style: AppText.ui(13.5, color: AppColors.textSecondary, height: 1.45),
                        ),
                      ),
                    ]),
                  ),
                  const SizedBox(height: Gap.lg),
                  SectionHeader('Открытые', subtitle: open.isEmpty ? null : '${open.length}'),
                  if (open.isEmpty)
                    const EmptyState(
                      compact: true,
                      icon: Icons.verified_rounded,
                      title: 'Всё чисто',
                      message: 'Нет открытых нарушений. Так держать.',
                    ),
                  for (final p in open) ...[
                    _PenaltyCard(p: p, excusesLeft: excusesLeft),
                    const SizedBox(height: Gap.xs),
                  ],
                  if (closed.isNotEmpty) ...[
                    const SizedBox(height: Gap.lg),
                    const SectionHeader('История'),
                    for (final p in closed.take(50)) ...[
                      _PenaltyCard(p: p, excusesLeft: excusesLeft),
                      const SizedBox(height: Gap.xs),
                    ],
                  ],
                ]),
              ),
            ],
          )),
    );
  }
}

class _PenaltyCard extends ConsumerWidget {
  const _PenaltyCard({required this.p, required this.excusesLeft});
  final PenaltyRecord p;
  final int excusesLeft;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(gameControllerProvider).valueOrNull!;
    final c = AppColors.severity(p.severity);
    final recovery = p.recoveryQuestId == null ? null : s.quests[p.recoveryQuestId!];
    final resolved = p.status.isResolved;
    final consequences = [
      if (p.severity == Severity.light) 'без бонуса серии сегодня',
      if (p.severity != Severity.light) 'без бонуса серии 3 дня',
      if (recovery != null) 'восстановительное задание',
      if (p.goldLost > 0) '−${p.goldLost} Gold',
      if (p.xpLost > 0) '−${p.xpLost} XP',
    ];
    return Opacity(
      opacity: resolved ? 0.65 : 1,
      child: RpgCard(
        borderColor: resolved ? null : c.o(0.35),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Icon(p.kind == PenaltyKind.missionFailed ? Icons.flag_rounded : Icons.event_busy_rounded, color: c),
            const SizedBox(width: Gap.sm),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(p.title, style: AppText.ui(15, weight: FontWeight.w700)),
                Text('${p.kind.label} · ${humanDayYear(p.dayKey)}', style: AppText.ui(12, color: AppColors.textMuted)),
              ]),
            ),
            Pill(resolved ? p.status.label : p.severity.label, color: resolved ? AppColors.success : c),
          ]),
          if (consequences.isNotEmpty) ...[
            const SizedBox(height: Gap.xs),
            Text('Последствия: ${consequences.join(' · ')}', style: AppText.ui(12.5, color: AppColors.textSecondary)),
          ],
          if (!resolved) ...[
            const SizedBox(height: Gap.sm),
            Wrap(spacing: 8, runSpacing: 8, children: [
              if (recovery != null && recovery.isOpen)
                ActionChip(
                  avatar: const Icon(Icons.healing_rounded, size: 16, color: AppColors.success),
                  label: Text('Восстановить: ${recovery.title.replaceFirst('Восстановление: ', '')}'),
                  onPressed: () => context.push('/quests/${recovery.id}'),
                ),
              if (p.questId != null && s.quests[p.questId!] != null && !s.quests[p.questId!]!.deleted)
                ActionChip(
                  avatar: const Icon(Icons.event_repeat_rounded, size: 16),
                  label: const Text('Перенести'),
                  onPressed: () async {
                    final now = DateTime.now();
                    final d = await showDatePicker(
                      context: context,
                      initialDate: now,
                      firstDate: now,
                      lastDate: now.add(const Duration(days: 365)),
                      helpText: 'Новая дата',
                    );
                    if (d != null && context.mounted) {
                      await runGameAction(context, ref, (e, st) => e.reschedulePenalty(st, p.id, dayKeyOf(d)),
                          success: 'Перенесено на ${humanDay(dayKeyOf(d))}');
                    }
                  },
                ),
              ActionChip(
                avatar: const Icon(Icons.volunteer_activism_rounded, size: 16),
                label: Text('Уважительная причина ($excusesLeft)'),
                onPressed: excusesLeft <= 0
                    ? null
                    : () async {
                        final ok = await confirm(context,
                            title: 'Уважительная причина?',
                            message: 'Нарушение будет закрыто, потерянные Gold и XP вернутся. '
                                'Осталось в этом месяце: ${excusesLeft - 1}.');
                        if (ok && context.mounted) {
                          await runGameAction(context, ref, (e, st) => e.excusePenalty(st, p.id),
                              success: 'Нарушение закрыто');
                        }
                      },
              ),
            ]),
          ],
        ]),
      ),
    );
  }
}
