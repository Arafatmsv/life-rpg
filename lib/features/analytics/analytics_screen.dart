import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_theme.dart';
import '../../app/theme/app_tokens.dart';
import '../../core/responsive/responsive.dart';
import '../../core/utils/day.dart';
import '../../core/widgets/buttons.dart';
import '../../core/widgets/rpg_card.dart';
import '../../core/widgets/rpg_icons.dart';
import '../../core/widgets/states.dart';
import '../../data/models/enums.dart';
import '../game/game_controller.dart';
import '../help/glossary.dart';
import 'activity_heatmap.dart';
import 'analytics_data.dart';

class AnalyticsScreen extends ConsumerStatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  ConsumerState<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends ConsumerState<AnalyticsScreen> {
  var _range = AnalyticsRange.week;
  (String, String)? _custom;
  var _table = false;

  Future<void> _pickCustom() async {
    final now = DateTime.now();
    final r = await showDateRangePicker(
      context: context,
      firstDate: now.subtract(const Duration(days: 365 * 5)),
      lastDate: now,
      initialDateRange: DateTimeRange(start: now.subtract(const Duration(days: 29)), end: now),
    );
    if (r == null) return;
    setState(() {
      _custom = (dayKeyOf(r.start), dayKeyOf(r.end));
      _range = AnalyticsRange.custom;
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(gameControllerProvider).valueOrNull;
    final snap = ref.watch(snapshotProvider);
    if (s == null || snap == null) return const Scaffold(body: LoadingView());
    final cfg = ref.watch(engineProvider).config;
    final data = AnalyticsData.compute(s, cfg, range: _range, today: snap.today, custom: _custom);
    final st = snap.stats;

    final filters = Wrap(spacing: 8, runSpacing: 8, children: [
      for (final r in AnalyticsRange.values)
        ChoiceChipX(
          label: r == AnalyticsRange.custom && _custom != null && _range == r
              ? '${humanDay(_custom!.$1)} – ${humanDay(_custom!.$2)}'
              : r.label,
          icon: r == AnalyticsRange.custom ? Icons.date_range_rounded : null,
          selected: _range == r,
          onTap: r == AnalyticsRange.custom ? _pickCustom : () => setState(() => _range = r),
        ),
    ]);

    // One table of facts instead of a grid of boxed tiles.
    final tiles = RpgCard(
      padding: const EdgeInsets.symmetric(horizontal: Gap.md, vertical: Gap.xs),
      child: ResponsiveColumns(
        minItemWidth: 260,
        maxColumns: 2,
        spacing: 0,
        children: [
          _Fact('Опыт за период', '${data.xpInRange} XP', term: Term.xp),
          _Fact('Выполнено за период', '${data.completionsInRange}'),
          _Fact('Всего опыта', '${snap.level.totalXp} XP · уровень ${snap.level.level}', term: Term.level),
          _Fact('Всего выполнено', '${st.totalCompletions} · пропущено ${st.failedCount}', term: Term.penalty),
          _Fact('Миссий и испытаний', '${st.missionsCompleted} · ${st.bossesCompleted}', term: Term.mission),
          _Fact('Время на развитие', _hours(st.minutesSpent)),
          _Fact('Достижения', '${st.achievementsCount}', term: Term.rarity),
          _Fact('Лучшая серия', '${snap.streak.longest} ${plural(snap.streak.longest, 'день', 'дня', 'дней')}',
              term: Term.streak),
        ],
      ),
    );

    final xpChart = RpgCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Expanded(child: Text('Опыт', style: AppText.display(22))),
          IconButton(
            tooltip: _table ? 'Показать график' : 'Показать таблицу',
            onPressed: () => setState(() => _table = !_table),
            icon: Icon(_table ? Icons.bar_chart_rounded : Icons.table_rows_rounded),
          ),
        ]),
        Text('${humanDay(data.from)} – ${humanDay(data.to)} · нажмите на столбец',
            style: AppText.ui(12, color: AppColors.textMuted)),
        const SizedBox(height: Gap.md),
        if (_table) _DataTable(buckets: data.buckets) else _XpBars(buckets: data.buckets),
      ]),
    );

    final heat = RpgCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('Календарь активности', style: AppText.display(22)),
        Text('Выполненные задания по дням за последние полгода', style: AppText.ui(12, color: AppColors.textMuted)),
        const SizedBox(height: Gap.md),
        ActivityHeatmap(counts: data.heat, today: snap.today, firstDayOfWeek: s.settings.firstDayOfWeek, weeks: 26),
      ]),
    );

    final totalByAttr = data.byAttribute.values.fold<int>(0, (a, b) => a + b);
    final maxAttr = data.byAttribute.values.fold<int>(1, (a, b) => b > a ? b : a);
    final distribution = RpgCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('Задания по категориям', style: AppText.display(22)),
        Text('За выбранный период', style: AppText.ui(12, color: AppColors.textMuted)),
        const SizedBox(height: Gap.md),
        if (totalByAttr == 0)
          Text('В этом периоде нет выполненных заданий', style: AppText.ui(13, color: AppColors.textMuted)),
        if (totalByAttr > 0)
          for (final a in AttributeType.values)
            _HBar(
              label: a.label,
              icon: RpgIcons.attribute(a),
              color: AppColors.textSecondary,
              value: data.byAttribute[a]!,
              max: maxAttr,
              trailing: '${data.byAttribute[a]} · ${(data.byAttribute[a]! * 100 / totalByAttr).round()}%',
            ),
      ]),
    );

    final maxLvl = AttributeType.values.map((a) => snap.attributeLevels[a]!.level).fold<int>(1, (a, b) => b > a ? b : a);
    final attrProgress = RpgCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('Прогресс характеристик', style: AppText.display(22)),
        Text('Уровень и опыт за период', style: AppText.ui(12, color: AppColors.textMuted)),
        const SizedBox(height: Gap.md),
        for (final a in AttributeType.values)
          _HBar(
            label: a.label,
            icon: RpgIcons.attribute(a),
            color: AppColors.textSecondary,
            value: snap.attributeLevels[a]!.level,
            max: maxLvl,
            fraction: (snap.attributeLevels[a]!.level - 1 + snap.attributeLevels[a]!.progress) / maxLvl,
            trailing: 'ур. ${snap.attributeLevels[a]!.level} · +${data.xpByAttribute[a]} XP',
          ),
      ]),
    );

    final levels = RpgCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('История уровней', style: AppText.display(22)),
        const SizedBox(height: Gap.md),
        _LevelLine(points: data.levelHistory),
      ]),
    );

    final done = data.completionsInRange, missed = data.failedInRange;
    final ratio = RpgCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('Выполнено и пропущено', style: AppText.display(22)),
        Text('Пропуски видны, чтобы вовремя вернуться в ритм.', style: AppText.ui(12, color: AppColors.textMuted)),
        const SizedBox(height: Gap.md),
        if (done + missed == 0)
          Text('Нет данных за период', style: AppText.ui(13, color: AppColors.textMuted))
        else ...[
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: SizedBox(
              height: 16,
              child: Row(children: [
                if (done > 0) Expanded(flex: done, child: Container(color: AppColors.statusGood)),
                if (done > 0 && missed > 0) Container(width: 2, color: AppColors.surface0),
                if (missed > 0) Expanded(flex: missed, child: Container(color: AppColors.statusCritical)),
              ]),
            ),
          ),
          const SizedBox(height: Gap.sm),
          Wrap(spacing: Gap.lg, runSpacing: 6, children: [
            _Legend(color: AppColors.statusGood, text: 'Выполнено: $done (${(done * 100 / (done + missed)).round()}%)'),
            _Legend(color: AppColors.statusCritical, text: 'Пропущено: $missed (${(missed * 100 / (done + missed)).round()}%)'),
          ]),
        ],
      ]),
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Аналитика')),
      body: AdaptiveBuilder(builder: (context, size, c) {
        final pad = EdgeInsets.fromLTRB(size.gutter, Gap.xs, size.gutter, Gap.xxl + MediaQuery.paddingOf(context).bottom);
        Widget col(List<Widget> w) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              for (var i = 0; i < w.length; i++) ...[if (i > 0) const SizedBox(height: Gap.md), w[i]],
            ]);
        return ListView(padding: pad, children: [
          ContentWidth(
            child: col([
              filters,
              tiles,
              if (size.atLeastExpanded)
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(flex: 3, child: col([xpChart, levels])),
                  const SizedBox(width: Gap.md),
                  Expanded(flex: 2, child: col([distribution, ratio])),
                ])
              else ...[xpChart, distribution, ratio, levels],
              heat,
              attrProgress,
            ]),
          ),
        ]);
      }),
    );
  }

  static String _hours(int minutes) =>
      minutes < 60 ? '$minutes мин' : '${(minutes / 60).toStringAsFixed(minutes < 600 ? 1 : 0)} ч';
}

class _Fact extends StatelessWidget {
  const _Fact(this.label, this.value, {this.term});
  final String label;
  final String value;
  final Term? term;

  @override
  Widget build(BuildContext context) {
    final row = Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(children: [
        Expanded(child: Text(label, style: AppText.ui(13.5, color: AppColors.textSecondary))),
        const SizedBox(width: Gap.sm),
        Text(value, style: AppText.number(14, weight: FontWeight.w500)),
      ]),
    );
    return term == null ? row : Explain(term: term, child: row);
  }
}

/// Legend key: a small square swatch next to the label.
class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.text});
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 10, height: 10, color: color),
        const SizedBox(width: 6),
        Text(text, style: AppText.ui(13, color: AppColors.textSecondary)),
      ]);
}

class _HBar extends StatelessWidget {
  const _HBar({
    required this.label,
    required this.icon,
    required this.color,
    required this.value,
    required this.max,
    required this.trailing,
    this.fraction,
  });

  final String label;
  final IconData icon;
  final Color color;
  final int value;
  final int max;
  final String trailing;
  final double? fraction;

  @override
  Widget build(BuildContext context) {
    final f = (fraction ?? (max == 0 ? 0 : value / max)).clamp(0.0, 1.0);
    return Tooltip(
      message: '$label: $trailing',
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 6),
            Expanded(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.ui(13, weight: FontWeight.w600))),
            Text(trailing, style: AppText.number(12.5, weight: FontWeight.w600, color: AppColors.textSecondary)),
          ]),
          const SizedBox(height: 5),
          LayoutBuilder(
            builder: (context, c) => Stack(children: [
              Container(height: 8, decoration: BoxDecoration(color: AppColors.surface3, borderRadius: BorderRadius.circular(4))),
              AnimatedContainer(
                duration: const Duration(milliseconds: 500),
                curve: Curves.easeOutCubic,
                height: 8,
                width: value == 0 && fraction == null ? 0 : (c.maxWidth * f).clamp(4.0, c.maxWidth),
                decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4)),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _XpBars extends StatelessWidget {
  const _XpBars({required this.buckets});
  final List<Bucket> buckets;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    final maxY = buckets.fold<int>(10, (m, b) => b.xp > m ? b.xp : m).toDouble();
    final w = buckets.length <= 7 ? 18.0 : buckets.length <= 14 ? 12.0 : buckets.length <= 31 ? 7.0 : 5.0;
    return SizedBox(
      height: 200,
      child: BarChart(BarChartData(
        maxY: maxY * 1.15,
        minY: 0,
        alignment: BarChartAlignment.spaceAround,
        borderData: FlBorderData(show: false),
        gridData: FlGridData(
          drawVerticalLine: false,
          horizontalInterval: (maxY / 4).clamp(1, double.infinity),
          getDrawingHorizontalLine: (_) => const FlLine(color: AppColors.borderSoft, strokeWidth: 1),
        ),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(),
          rightTitles: const AxisTitles(),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 34,
              interval: (maxY / 4).clamp(1, double.infinity),
              getTitlesWidget: (v, meta) => v == meta.max
                  ? const SizedBox.shrink()
                  : Text(v.round().toString(), style: AppText.ui(10, color: AppColors.textMuted)),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 22,
              getTitlesWidget: (v, meta) {
                final i = v.toInt();
                if (i < 0 || i >= buckets.length) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(buckets[i].label, style: AppText.ui(10, color: AppColors.textMuted)),
                );
              },
            ),
          ),
        ),
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (_) => AppColors.surface3,
            fitInsideHorizontally: true,
            fitInsideVertically: true,
            getTooltipItem: (g, _, rod, __) {
              final b = buckets[g.x];
              return BarTooltipItem(
                '${b.tooltip}\n',
                AppText.ui(12, color: AppColors.textSecondary),
                children: [
                  TextSpan(text: '${b.xp} XP', style: AppText.ui(13, weight: FontWeight.w700)),
                  TextSpan(text: ' · ${b.completions} ${plural(b.completions, 'задание', 'задания', 'заданий')}',
                      style: AppText.ui(12, color: AppColors.textSecondary)),
                ],
              );
            },
          ),
        ),
        barGroups: [
          for (var i = 0; i < buckets.length; i++)
            BarChartGroupData(x: i, barRods: [
              BarChartRodData(
                toY: buckets[i].xp.clamp(0, 1 << 30).toDouble(),
                width: w,
                color: accent,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
              ),
            ]),
        ],
      )),
    );
  }
}

class _DataTable extends StatelessWidget {
  const _DataTable({required this.buckets});
  final List<Bucket> buckets;

  @override
  Widget build(BuildContext context) {
    final rows = buckets.where((b) => b.xp != 0 || b.completions != 0).toList();
    if (rows.isEmpty) return Text('Нет данных', style: AppText.ui(13, color: AppColors.textMuted));
    return Column(children: [
      Row(children: [
        Expanded(child: Text('Период', style: AppText.label())),
        SizedBox(width: 70, child: Text('XP', textAlign: TextAlign.right, style: AppText.label())),
        SizedBox(width: 80, child: Text('Задания', textAlign: TextAlign.right, style: AppText.label())),
      ]),
      const Divider(height: 16),
      for (final b in rows)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(children: [
            Expanded(child: Text(b.tooltip, style: AppText.ui(13, color: AppColors.textSecondary))),
            SizedBox(width: 70, child: Text('${b.xp}', textAlign: TextAlign.right, style: AppText.number(13))),
            SizedBox(width: 80, child: Text('${b.completions}', textAlign: TextAlign.right, style: AppText.number(13))),
          ]),
        ),
    ]);
  }
}

class _LevelLine extends StatelessWidget {
  const _LevelLine({required this.points});
  final List<(String, int)> points;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    if (points.length < 2) {
      return Text('Данных пока мало', style: AppText.ui(13, color: AppColors.textMuted));
    }
    final base = points.first.$1;
    final spots = [for (final p in points) FlSpot(daysBetween(base, p.$1).toDouble(), p.$2.toDouble())];
    final maxY = points.map((p) => p.$2).fold<int>(1, (a, b) => b > a ? b : a) + 1.0;
    final maxX = spots.last.x;
    return SizedBox(
      height: 180,
      child: LineChart(LineChartData(
        minY: 0,
        maxY: maxY,
        minX: 0,
        maxX: maxX == 0 ? 1 : maxX,
        borderData: FlBorderData(show: false),
        gridData: FlGridData(
          drawVerticalLine: false,
          horizontalInterval: (maxY / 4).ceilToDouble().clamp(1, double.infinity),
          getDrawingHorizontalLine: (_) => const FlLine(color: AppColors.borderSoft, strokeWidth: 1),
        ),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(),
          rightTitles: const AxisTitles(),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              interval: (maxY / 4).ceilToDouble().clamp(1, double.infinity),
              getTitlesWidget: (v, meta) => v == meta.max || v == 0
                  ? const SizedBox.shrink()
                  : Text(v.round().toString(), style: AppText.ui(10, color: AppColors.textMuted)),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 22,
              interval: (maxX / 3).clamp(1, double.infinity),
              getTitlesWidget: (v, meta) => Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(humanDay(addDays(base, v.round())), style: AppText.ui(10, color: AppColors.textMuted)),
              ),
            ),
          ),
        ),
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => AppColors.surface3,
            fitInsideHorizontally: true,
            getTooltipItems: (spots) => [
              for (final s in spots)
                LineTooltipItem(
                  '${humanDay(addDays(base, s.x.round()))}\nУровень ${s.y.round()}',
                  AppText.ui(12, weight: FontWeight.w700),
                ),
            ],
          ),
          getTouchedSpotIndicator: (bar, idx) => [
            for (final _ in idx)
              TouchedSpotIndicatorData(
                const FlLine(color: AppColors.textMuted, strokeWidth: 1),
                FlDotData(
                  getDotPainter: (s, p, b, i) => FlDotCirclePainter(
                    radius: 4,
                    color: accent,
                    strokeColor: AppColors.surface0,
                    strokeWidth: 2,
                  ),
                ),
              ),
          ],
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isStepLineChart: true,
            color: accent,
            barWidth: 2,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(show: true, color: accent.o(0.08)),
          ),
        ],
      )),
    );
  }
}
