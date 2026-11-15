import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_theme.dart';
import '../../core/utils/day.dart';

/// GitHub-style contribution grid: one column per week, one cell per day.
/// Intensity comes from a single-hue sequential ramp.
class ActivityHeatmap extends StatefulWidget {
  const ActivityHeatmap({
    super.key,
    required this.counts,
    required this.today,
    required this.firstDayOfWeek,
    this.weeks = 26,
    this.marks = const {},
  });

  final Map<String, int> counts;
  final String today;
  final int firstDayOfWeek;
  final int weeks;

  /// Optional per-day outline (rest / freeze days).
  final Map<String, Color> marks;

  @override
  State<ActivityHeatmap> createState() => _ActivityHeatmapState();
}

class _ActivityHeatmapState extends State<ActivityHeatmap> {
  String? _selected;

  static int level(int n) => n <= 0
      ? 0
      : n == 1
          ? 1
          : n == 2
              ? 2
              : n <= 4
                  ? 3
                  : n <= 6
                      ? 4
                      : 5;

  @override
  Widget build(BuildContext context) {
    final start = addDays(weekStartOf(widget.today, widget.firstDayOfWeek), -7 * (widget.weeks - 1));
    return LayoutBuilder(builder: (context, c) {
      const gap = 3.0;
      const labelW = 22.0;
      final cell = ((c.maxWidth - labelW - gap * (widget.weeks - 1)) / widget.weeks).clamp(6.0, 16.0);
      final sel = _selected;
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          reverse: true,
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SizedBox(
              width: labelW,
              child: Column(children: [
                for (var r = 0; r < 7; r++)
                  SizedBox(
                    height: cell + gap,
                    child: r.isEven
                        ? Text(weekdayShort[(widget.firstDayOfWeek - 1 + r) % 7],
                            style: AppText.ui(9, color: AppColors.textMuted))
                        : null,
                  ),
              ]),
            ),
            for (var w = 0; w < widget.weeks; w++)
              Padding(
                padding: EdgeInsets.only(right: w == widget.weeks - 1 ? 0 : gap),
                child: Column(children: [
                  for (var r = 0; r < 7; r++)
                    Builder(builder: (context) {
                      final d = addDays(start, w * 7 + r);
                      final future = daysBetween(widget.today, d) > 0;
                      final n = widget.counts[d] ?? 0;
                      final mark = widget.marks[d];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: gap),
                        child: Semantics(
                          label: '${humanDay(d)}: $n',
                          child: GestureDetector(
                            onTap: future ? null : () => setState(() => _selected = d),
                            child: Container(
                              width: cell,
                              height: cell,
                              decoration: BoxDecoration(
                                color: future ? Colors.transparent : AppColors.heat[level(n)],
                                borderRadius: BorderRadius.circular(3),
                                border: d == sel
                                    ? Border.all(color: AppColors.text, width: 1.5)
                                    : mark != null
                                        ? Border.all(color: mark, width: 1.3)
                                        : d == widget.today
                                            ? Border.all(color: AppColors.textSecondary, width: 1)
                                            : null,
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                ]),
              ),
          ]),
        ),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(
            child: Text(
              sel == null
                  ? 'Нажмите на день, чтобы увидеть детали'
                  : '${humanDayYear(sel)}: ${widget.counts[sel] ?? 0} '
                      '${plural(widget.counts[sel] ?? 0, 'задание', 'задания', 'заданий')}',
              style: AppText.ui(12, color: sel == null ? AppColors.textMuted : AppColors.text),
            ),
          ),
          Text('меньше', style: AppText.ui(10, color: AppColors.textMuted)),
          const SizedBox(width: 4),
          for (final c in AppColors.heat)
            Container(
              width: 10,
              height: 10,
              margin: const EdgeInsets.only(right: 2),
              decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(2)),
            ),
          const SizedBox(width: 2),
          Text('больше', style: AppText.ui(10, color: AppColors.textMuted)),
        ]),
      ]);
    });
  }
}
