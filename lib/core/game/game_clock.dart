import '../utils/day.dart';

/// Source of "now" in game time. Game days follow either the device time
/// zone or a fixed UTC offset the player picked in settings.
class GameClock {
  GameClock({DateTime Function()? now}) : _now = now ?? DateTime.now;

  final DateTime Function() _now;

  /// Real instant, for timestamps.
  DateTime instant() => _now();

  /// Wall-clock time in the game time zone. The returned value's fields
  /// (year, hour…) are what the player sees on their clock.
  DateTime wallTime(int? tzOffsetMinutes) => toWall(_now(), tzOffsetMinutes);

  String today(int? tzOffsetMinutes) => dayKeyOf(wallTime(tzOffsetMinutes));

  static DateTime toWall(DateTime instant, int? tzOffsetMinutes) =>
      tzOffsetMinutes == null
          ? instant.toLocal()
          : instant.toUtc().add(Duration(minutes: tzOffsetMinutes));

  static String dayOf(DateTime instant, int? tzOffsetMinutes) =>
      dayKeyOf(toWall(instant, tzOffsetMinutes));
}
