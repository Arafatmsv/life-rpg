import '../utils/day.dart';

class StreakInfo {
  const StreakInfo({
    required this.current,
    required this.longest,
    required this.successfulDays,
    required this.missedDays,
    required this.todayCount,
    required this.todaySuccessful,
    required this.dayCounts,
    required this.neutralDays,
    required this.brokenYesterday,
    required this.previousStreak,
  });

  static const empty = StreakInfo(
    current: 0,
    longest: 0,
    successfulDays: 0,
    missedDays: 0,
    todayCount: 0,
    todaySuccessful: false,
    dayCounts: {},
    neutralDays: {},
    brokenYesterday: false,
    previousStreak: 0,
  );

  final int current;
  final int longest;
  final int successfulDays;
  final int missedDays;
  final int todayCount;
  final bool todaySuccessful;

  /// Completions per game day.
  final Map<String, int> dayCounts;

  /// Rest / freeze days: they keep a streak alive but do not extend it.
  final Set<String> neutralDays;

  /// Yesterday was a miss that ended a streak of [previousStreak] days.
  final bool brokenYesterday;
  final int previousStreak;
}

/// Computes streaks from completion counts per day.
///
/// Rules:
/// * a day with at least [minCount] completions is successful;
/// * rest and freeze days are neutral — they neither break nor extend;
/// * today never breaks a streak while it is still in progress;
/// * history starts at [firstDay], so the days before the player started
///   are not counted as misses.
StreakInfo computeStreak({
  required Map<String, int> dayCounts,
  required Set<String> neutralDays,
  required String today,
  required String firstDay,
  int minCount = 1,
}) {
  if (daysBetween(firstDay, today) < 0) return StreakInfo.empty;
  bool ok(String d) => (dayCounts[d] ?? 0) >= minCount;

  var longest = 0, run = 0, successful = 0, missed = 0;
  for (final d in dayRange(firstDay, today)) {
    if (ok(d)) {
      run++;
      successful++;
      if (run > longest) longest = run;
    } else if (neutralDays.contains(d) || d == today) {
      // keeps the run as is
    } else {
      run = 0;
      missed++;
    }
  }

  var current = 0;
  var cursor = today;
  if (ok(today)) current = 1;
  cursor = addDays(today, -1);
  while (daysBetween(firstDay, cursor) >= 0) {
    if (ok(cursor)) {
      current++;
    } else if (!neutralDays.contains(cursor)) {
      break;
    }
    cursor = addDays(cursor, -1);
  }

  // Was there a streak that yesterday's miss ended?
  final yesterday = addDays(today, -1);
  var previous = 0;
  final yesterdayMissed = daysBetween(firstDay, yesterday) >= 0 &&
      !ok(yesterday) &&
      !neutralDays.contains(yesterday);
  if (yesterdayMissed) {
    var c = addDays(yesterday, -1);
    while (daysBetween(firstDay, c) >= 0) {
      if (ok(c)) {
        previous++;
      } else if (!neutralDays.contains(c)) {
        break;
      }
      c = addDays(c, -1);
    }
  }

  return StreakInfo(
    current: current,
    longest: longest,
    successfulDays: successful,
    missedDays: missed,
    todayCount: dayCounts[today] ?? 0,
    todaySuccessful: ok(today),
    dayCounts: dayCounts,
    neutralDays: neutralDays,
    brokenYesterday: yesterdayMissed && previous > 0,
    previousStreak: previous,
  );
}
