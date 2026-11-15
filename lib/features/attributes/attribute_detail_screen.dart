import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_theme.dart';
import '../../app/theme/app_tokens.dart';
import '../../core/game/skill_catalog.dart';
import '../../core/game/stats.dart';
import '../../core/responsive/responsive.dart';
import '../../core/utils/day.dart';
import '../../core/widgets/progress.dart';
import '../../core/widgets/rpg_card.dart';
import '../../core/widgets/rpg_icons.dart';
import '../../core/widgets/states.dart';
import '../../data/models/enums.dart';
import '../../app/providers.dart';
import '../character/character_screen.dart';
import '../game/game_controller.dart';
import '../quests/quest_card.dart';
import '../quests/quest_editor.dart';

class AttributeDetailScreen extends ConsumerWidget {
  const AttributeDetailScreen({super.key, required this.attribute});
  final AttributeType attribute;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(gameControllerProvider).valueOrNull;
    final snap = ref.watch(snapshotProvider);
    if (s == null || snap == null) return const Scaffold(body: LoadingView());
    final e = ref.watch(engineProvider);
    final a = attribute;
    final c = AppColors.attribute(a);
    final l = snap.attributeLevels[a]!;
    final txs = s.xp.values.where((t) => t.attribute == a).toList()
      ..sort((x, y) => y.createdAt.compareTo(x.createdAt));
    final quests = s.liveQuests.where((q) => q.attribute == a && q.isOpen).toList();
    final skills = skillsOf(a);
    final unlocked = skills.where((sk) => s.skills.containsKey(sk.id)).length;
    final bonus = skillBonusFor(s, e.config, a);

    // XP of this attribute over the last 30 days.
    final today = snap.today;
    final days = [for (var i = 29; i >= 0; i--) addDays(today, -i)];
    final perDay = {for (final d in days) d: 0};
    for (final t in txs) {
      if (perDay.containsKey(t.dayKey)) perDay[t.dayKey] = perDay[t.dayKey]! + t.amount;
    }
    final maxY = perDay.values.fold<int>(10, (m, v) => v > m ? v : m).toDouble();

    final head = RpgCard(
      glow: c,
      padding: const EdgeInsets.all(Gap.lg),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          IconTile(RpgIcons.attribute(a), color: c, size: 56),
          const SizedBox(width: Gap.md),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(a.code, style: AppText.label(color: c)),
              Text(a.label, style: AppText.display(28)),
            ]),
          ),
          Column(children: [
            Text('${l.level}', style: AppText.display(44, color: c)),
            Text('уровень', style: AppText.ui(11, color: AppColors.textMuted)),
          ]),
        ]),
        const SizedBox(height: Gap.md),
        Text(a.description, style: AppText.ui(13.5, color: AppColors.textSecondary)),
        const SizedBox(height: Gap.md),
        XpBar(value: l.progress, height: 10, colors: [c.o(0.6), c]),
        const SizedBox(height: 6),
        Text('${l.xpIntoLevel} / ${l.xpForNext} XP до уровня ${l.level + 1} · всего ${snap.attributeXp[a]} XP',
            style: AppText.ui(12, color: AppColors.textMuted)),
        const SizedBox(height: Gap.md),
        Wrap(spacing: 6, runSpacing: 6, children: [
          Pill('Навыки $unlocked/${skills.length}', color: c, icon: Icons.account_tree_rounded),
          if (bonus > 0) Pill('Бонус навыков +${(bonus * 100).round()}% XP', color: AppColors.violetBright),
          if (s.character!.focus.contains(a)) Pill('Фокус +10% XP', color: AppColors.gold, icon: Icons.star_rounded),
        ]),
        const SizedBox(height: Gap.md),
        OutlinedButton.icon(
          onPressed: () => context.go('/skills?a=${a.name}'),
          icon: const Icon(Icons.account_tree_rounded, size: 18),
          label: const Text('Ветка навыков'),
        ),
      ]),
    );

    final chart = RpgCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Опыт за 30 дней', style: AppText.display(22)),
        const SizedBox(height: Gap.md),
        SizedBox(
          height: 160,
          child: BarChart(BarChartData(
            maxY: maxY * 1.15,
            minY: 0,
            borderData: FlBorderData(show: false),
            gridData: FlGridData(
              drawVerticalLine: false,
              horizontalInterval: (maxY / 3).clamp(1, double.infinity),
              getDrawingHorizontalLine: (_) => const FlLine(color: AppColors.borderSoft, strokeWidth: 1),
            ),
            titlesData: FlTitlesData(
              topTitles: const AxisTitles(),
              rightTitles: const AxisTitles(),
              leftTitles: const AxisTitles(),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 22,
                  getTitlesWidget: (v, meta) {
                    final i = v.toInt();
                    if (i % 7 != 0 && i != 29) return const SizedBox.shrink();
                    return Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(humanDay(days[i]), style: AppText.ui(10, color: AppColors.textMuted)),
                    );
                  },
                ),
              ),
            ),
            barTouchData: BarTouchData(
              touchTooltipData: BarTouchTooltipData(
                getTooltipColor: (_) => AppColors.surface3,
                getTooltipItem: (g, _, rod, __) => BarTooltipItem(
                  '${humanDay(days[g.x])}\n${rod.toY.round()} XP',
                  AppText.ui(12, weight: FontWeight.w700),
                ),
              ),
            ),
            barGroups: [
              for (var i = 0; i < days.length; i++)
                BarChartGroupData(x: i, barRods: [
                  BarChartRodData(
                    toY: perDay[days[i]]!.clamp(0, 1 << 30).toDouble(),
                    width: 6,
                    color: c,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ]),
            ],
          )),
        ),
      ]),
    );

    final related = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      SectionHeader('Связанные задания', action: 'Добавить', onAction: () => openQuestEditor(context)),
      if (quests.isEmpty)
        RpgCard(child: Text('Нет активных заданий в этой характеристике.', style: AppText.ui(13, color: AppColors.textMuted))),
      for (final q in quests) ...[QuestCard(quest: q, dense: true), const SizedBox(height: Gap.xs)],
    ]);

    final history = RpgCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('История изменений', style: AppText.display(22)),
        const SizedBox(height: Gap.xs),
        if (txs.isEmpty) Text('Пока нет опыта в этой характеристике', style: AppText.ui(13, color: AppColors.textMuted)),
        for (final t in txs.take(25)) XpHistoryRow(tx: t, tz: s.settings.tzOffsetMinutes),
      ]),
    );

    return Scaffold(
      appBar: AppBar(title: Text(a.label)),
      body: AdaptiveBuilder(builder: (context, size, cons) {
        final pad = EdgeInsets.fromLTRB(size.gutter, Gap.xs, size.gutter, Gap.xxl);
        Widget col(List<Widget> w) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              for (var i = 0; i < w.length; i++) ...[if (i > 0) const SizedBox(height: Gap.md), w[i]],
            ]);
        if (size.atLeastExpanded) {
          return SingleChildScrollView(
            padding: pad,
            child: ContentWidth(
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(child: col([head, chart])),
                const SizedBox(width: Gap.lg),
                Expanded(child: col([related, history])),
              ]),
            ),
          );
        }
        return ListView(padding: pad, children: [ContentWidth(maxWidth: 720, child: col([head, chart, related, history]))]);
      }),
    );
  }
}
