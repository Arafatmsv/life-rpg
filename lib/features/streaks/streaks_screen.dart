import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_theme.dart';
import '../../app/theme/app_tokens.dart';
import '../../core/game/game_engine.dart';
import '../../core/responsive/responsive.dart';
import '../../core/utils/day.dart';
import '../../core/widgets/buttons.dart';
import '../../core/widgets/feedback.dart';
import '../../core/widgets/rpg_card.dart';
import '../../core/widgets/states.dart';
import '../../data/models/enums.dart';
import '../analytics/activity_heatmap.dart';
import '../game/game_controller.dart';

class StreaksScreen extends ConsumerWidget {
  const StreaksScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(gameControllerProvider).valueOrNull;
    final snap = ref.watch(snapshotProvider);
    if (s == null || snap == null) return const Scaffold(body: LoadingView());
    final e = ref.watch(engineProvider);
    final st = snap.streak;
    final today = snap.today;
    final set = s.settings;
    final freezesLeft = set.streakFreezesPerMonth - e.freezesUsedThisMonth(s);
    final missedRecent = [
      for (var i = 1; i <= 7; i++)
        if ((st.dayCounts[addDays(today, -i)] ?? 0) < set.minCompletionsForStreak &&
            !s.dayMarks.containsKey(addDays(today, -i)) &&
            daysBetween(dayKeyOf(s.character!.createdAt), addDays(today, -i)) >= 0)
          addDays(today, -i),
    ];

    final stats = RpgCard(
      child: Column(children: [
        const Icon(Icons.local_fire_department_outlined, size: 28, color: AppColors.textSecondary),
        const SizedBox(height: Gap.xs),
        Text('${st.current}', style: AppText.display(64)),
        Text('${plural(st.current, 'день', 'дня', 'дней')} подряд', style: AppText.ui(14, color: AppColors.textSecondary)),
        const SizedBox(height: Gap.md),
        Wrap(alignment: WrapAlignment.center, spacing: Gap.xl, runSpacing: Gap.sm, children: [
          _Num('${st.longest}', 'рекорд'),
          _Num('${st.successfulDays}', 'успешных дней'),
          _Num('${snap.stats.totalCompletions}', 'выполнено'),
          _Num('${st.missedDays}', 'пропущено дней'),
        ]),
        const SizedBox(height: Gap.md),
        Text(
          st.todaySuccessful
              ? 'Сегодняшний день уже засчитан.'
              : 'Выполните ${set.minCompletionsForStreak} ${plural(set.minCompletionsForStreak, 'задание', 'задания', 'заданий')}, чтобы засчитать сегодня.',
          textAlign: TextAlign.center,
          style: AppText.ui(13, color: AppColors.textMuted),
        ),
      ]),
    );

    final calendar = RpgCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('Календарь активности', style: AppText.display(22)),
        const SizedBox(height: Gap.md),
        ActivityHeatmap(
          counts: st.dayCounts,
          today: today,
          firstDayOfWeek: set.firstDayOfWeek,
          weeks: 20,
          marks: {
            for (final m in s.dayMarks.values)
              m.dayKey: m.kind == DayMarkKind.rest ? AppColors.text : AppColors.textMuted,
          },
        ),
        const SizedBox(height: Gap.xs),
        Wrap(spacing: Gap.md, children: [
          _MarkLegend(AppColors.text, 'день отдыха'),
          _MarkLegend(AppColors.textMuted, 'заморозка'),
        ]),
      ]),
    );

    final rest = RpgCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('Дни отдыха', style: AppText.display(22)),
        Text('Запланированный день отдыха не прерывает серию и не даёт штрафов '
            '(до ${GameEngine.maxRestDaysPerWeek} в неделю).',
            style: AppText.ui(12.5, color: AppColors.textMuted)),
        const SizedBox(height: Gap.md),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (var i = 0; i < 7; i++)
            Builder(builder: (context) {
              final d = addDays(today, i);
              final marked = s.dayMarks[d]?.kind == DayMarkKind.rest;
              return ChoiceChipX(
                label: i == 0 ? 'Сегодня' : '${weekdayShort[weekdayOf(d) - 1]} ${parseDayKey(d).day}',
                icon: marked ? Icons.bedtime_rounded : null,
                selected: marked,
                onTap: () => runGameAction(context, ref, (e, st) => e.toggleRestDay(st, d)),
              );
            }),
        ]),
        const SizedBox(height: Gap.md),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Режим отдыха (отпуск, болезнь)'),
          subtitle: const Text('Пока включён, пропуски не фиксируются и серия заморожена'),
          value: set.vacationMode,
          onChanged: (v) => runGameAction(context, ref, (e, st) => e.updateSettings(st, (x) => x.copyWith(vacationMode: v)),
              success: v ? 'Режим отдыха включён. Восстанавливайтесь.' : 'С возвращением!'),
        ),
      ]),
    );

    final freeze = RpgCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('Восстановление серии', style: AppText.display(22)),
        const SizedBox(height: Gap.xs),
        if (!set.streakFreezeEnabled) ...[
          Text('Заморозка позволяет защитить пропущенный день и сохранить серию. Ресурс ограничен.',
              style: AppText.ui(13, color: AppColors.textSecondary)),
          const SizedBox(height: Gap.sm),
          RpgButton(
            label: 'Включить заморозки',
            kind: RpgButtonKind.secondary,
            icon: Icons.ac_unit_rounded,
            onPressed: () => runGameAction(context, ref,
                (e, st) => e.updateSettings(st, (x) => x.copyWith(streakFreezeEnabled: true))),
          ),
        ] else ...[
          Text('Осталось в этом месяце: $freezesLeft из ${set.streakFreezesPerMonth}',
              style: AppText.ui(13.5, weight: FontWeight.w700)),
          const SizedBox(height: Gap.sm),
          if (missedRecent.isEmpty)
            Text('За последнюю неделю пропусков нет.', style: AppText.ui(13, color: AppColors.textMuted))
          else
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final d in missedRecent)
                ActionChip(
                  label: Text('Заморозить ${humanDay(d)}'),
                  onPressed: freezesLeft <= 0
                      ? null
                      : () async {
                          final ok = await confirm(context,
                              title: 'Заморозить ${humanDay(d)}?',
                              message: 'День будет защищён, и серия не прервётся. '
                                  'Останется заморозок: ${freezesLeft - 1}.');
                          if (ok && context.mounted) {
                            await runGameAction(context, ref, (e, st) => e.useStreakFreeze(st, d),
                                success: 'День защищён');
                          }
                        },
                ),
            ]),
        ],
      ]),
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Серии и отдых')),
      body: AdaptiveBuilder(builder: (context, size, c) {
        Widget col(List<Widget> w) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              for (var i = 0; i < w.length; i++) ...[if (i > 0) const SizedBox(height: Gap.md), w[i]],
            ]);
        return ListView(
          padding: EdgeInsets.fromLTRB(size.gutter, Gap.xs, size.gutter, Gap.xxl + MediaQuery.paddingOf(context).bottom),
          children: [
            ContentWidth(
              child: size.atLeastExpanded
                  ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Expanded(child: col([stats, freeze])),
                      const SizedBox(width: Gap.md),
                      Expanded(child: col([calendar, rest])),
                    ])
                  : col([stats, calendar, rest, freeze]),
            ),
          ],
        );
      }),
    );
  }
}

class _Num extends StatelessWidget {
  const _Num(this.v, this.l);
  final String v;
  final String l;

  @override
  Widget build(BuildContext context) => Column(children: [
        Text(v, style: AppText.number(20)),
        Text(l, style: AppText.ui(11.5, color: AppColors.textMuted)),
      ]);
}

class _MarkLegend extends StatelessWidget {
  const _MarkLegend(this.color, this.text);
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(2), border: Border.all(color: color, width: 1.3)),
        ),
        const SizedBox(width: 4),
        Text(text, style: AppText.ui(11, color: AppColors.textMuted)),
      ]);
}
