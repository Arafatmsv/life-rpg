import '../../app/config/game_config.dart';
import '../../core/game/game_clock.dart';
import '../../core/game/level_math.dart';
import '../../core/utils/day.dart';
import '../../data/models/enums.dart';
import '../../data/models/game_state.dart';
import '../../data/models/penalty.dart';

enum AnalyticsRange {
  day('День'),
  week('Неделя'),
  month('Месяц'),
  year('Год'),
  custom('Период');

  const AnalyticsRange(this.label);
  final String label;
}

class Bucket {
  const Bucket(this.label, this.tooltip, this.xp, this.completions);
  final String label;
  final String tooltip;
  final int xp;
  final int completions;
}

/// Pure aggregation of the ledger for the analytics screen.
class AnalyticsData {
  AnalyticsData._({
    required this.buckets,
    required this.xpInRange,
    required this.completionsInRange,
    required this.failedInRange,
    required this.byAttribute,
    required this.xpByAttribute,
    required this.levelHistory,
    required this.heat,
    required this.from,
    required this.to,
  });

  final List<Bucket> buckets;
  final int xpInRange;
  final int completionsInRange;
  final int failedInRange;
  final Map<AttributeType, int> byAttribute;
  final Map<AttributeType, int> xpByAttribute;

  /// (day, level) at the end of every day with XP changes in range.
  final List<(String, int)> levelHistory;

  /// Completions per day for the heatmap (independent of the range).
  final Map<String, int> heat;
  final String from;
  final String to;

  static (String, String) resolve(AnalyticsRange r, String today, int firstDow, (String, String)? custom) =>
      switch (r) {
        AnalyticsRange.day => (today, today),
        AnalyticsRange.week => (weekStartOf(today, firstDow), addDays(weekStartOf(today, firstDow), 6)),
        AnalyticsRange.month => (addDays(today, -29), today),
        AnalyticsRange.year => (addDays(today, -364), today),
        AnalyticsRange.custom => custom ?? (addDays(today, -29), today),
      };

  factory AnalyticsData.compute(
    GameState s,
    GameConfig cfg, {
    required AnalyticsRange range,
    required String today,
    (String, String)? custom,
  }) {
    final tz = s.settings.tzOffsetMinutes;
    final (from, to) = resolve(range, today, s.settings.firstDayOfWeek, custom);
    bool inRange(String d) => d.compareTo(from) >= 0 && d.compareTo(to) <= 0;

    // Bucket key function.
    final span = daysBetween(from, to) + 1;
    final hourly = range == AnalyticsRange.day;
    final monthly = range == AnalyticsRange.year || (range == AnalyticsRange.custom && span > 92);
    final weekly = !monthly && range == AnalyticsRange.custom && span > 45;

    final keys = <String>[];
    final labels = <String, (String, String)>{};
    if (hourly) {
      for (var h = 0; h < 24; h++) {
        final k = two(h);
        keys.add(k);
        labels[k] = (h % 6 == 0 ? '$h:00' : '', '$h:00–${h + 1}:00');
      }
    } else if (monthly) {
      var cur = '${from.substring(0, 7)}-01';
      while (cur.substring(0, 7).compareTo(to.substring(0, 7)) <= 0) {
        final k = cur.substring(0, 7);
        final m = int.parse(k.substring(5, 7));
        keys.add(k);
        labels[k] = (monthShort[m - 1], '${monthNominative[m - 1]} ${k.substring(0, 4)}');
        final d = parseDayKey(cur);
        cur = dayKeyOf(DateTime.utc(d.year, d.month + 1, 1));
      }
    } else if (weekly) {
      var cur = weekStartOf(from, s.settings.firstDayOfWeek);
      while (cur.compareTo(to) <= 0) {
        keys.add(cur);
        labels[cur] = (humanDay(cur), 'Неделя с ${humanDay(cur)}');
        cur = addDays(cur, 7);
      }
    } else {
      for (final d in dayRange(from, to)) {
        keys.add(d);
        final wd = weekdayOf(d);
        labels[d] = (
          span <= 7 ? weekdayShort[wd - 1] : (parseDayKey(d).day % 5 == 1 ? '${parseDayKey(d).day}' : ''),
          '${weekdayFull[wd - 1]}, ${humanDay(d)}',
        );
      }
    }
    String keyOf(String day, DateTime at) => hourly
        ? two(GameClock.toWall(at, tz).hour)
        : monthly
            ? day.substring(0, 7)
            : weekly
                ? weekStartOf(day, s.settings.firstDayOfWeek)
                : day;

    final xp = {for (final k in keys) k: 0};
    final cnt = {for (final k in keys) k: 0};
    var xpTotal = 0, compTotal = 0;
    final byAttr = {for (final a in AttributeType.values) a: 0};
    final xpByAttr = {for (final a in AttributeType.values) a: 0};
    for (final t in s.xp.values) {
      if (!inRange(t.dayKey)) continue;
      final k = keyOf(t.dayKey, t.createdAt);
      if (xp.containsKey(k)) xp[k] = xp[k]! + t.amount;
      xpTotal += t.amount;
      if (t.attribute != null) xpByAttr[t.attribute!] = xpByAttr[t.attribute!]! + t.amount;
    }
    final heat = <String, int>{};
    for (final c in s.activeCompletions) {
      heat[c.dayKey] = (heat[c.dayKey] ?? 0) + 1;
      if (!inRange(c.dayKey)) continue;
      final k = keyOf(c.dayKey, c.completedAt);
      if (cnt.containsKey(k)) cnt[k] = cnt[k]! + 1;
      compTotal++;
      byAttr[c.attribute] = byAttr[c.attribute]! + 1;
    }
    final failed = s.penalties.values
        .where((p) => p.kind != PenaltyKind.streakBreak && inRange(p.dayKey))
        .length;

    // Level history: cumulative XP by day, all time, then clipped to range.
    final perDay = <String, int>{};
    for (final t in s.xp.values) {
      perDay[t.dayKey] = (perDay[t.dayKey] ?? 0) + t.amount;
    }
    final days = perDay.keys.toList()..sort();
    var cum = 0;
    final history = <(String, int)>[];
    var lastLevel = 1;
    var startLevel = 1;
    for (final d in days) {
      cum += perDay[d]!;
      final lvl = characterLevel(cfg, cum).level;
      if (d.compareTo(from) < 0) {
        startLevel = lvl;
        continue;
      }
      if (d.compareTo(to) > 0) break;
      history.add((d, lvl));
      lastLevel = lvl;
    }
    if (history.isEmpty || history.first.$1 != from) history.insert(0, (from, startLevel));
    if (history.last.$1 != to && to.compareTo(today) <= 0) history.add((to, history.isEmpty ? lastLevel : history.last.$2));

    return AnalyticsData._(
      buckets: [for (final k in keys) Bucket(labels[k]!.$1, labels[k]!.$2, xp[k]!, cnt[k]!)],
      xpInRange: xpTotal,
      completionsInRange: compTotal,
      failedInRange: failed,
      byAttribute: byAttr,
      xpByAttribute: xpByAttr,
      levelHistory: history,
      heat: heat,
      from: from,
      to: to,
    );
  }
}
