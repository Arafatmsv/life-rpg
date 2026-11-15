import '../../app/config/game_config.dart';

/// Snapshot of progress inside the current level.
class LevelInfo {
  const LevelInfo({
    required this.level,
    required this.totalXp,
    required this.xpIntoLevel,
    required this.xpForNext,
  });

  final int level;
  final int totalXp;
  final int xpIntoLevel;
  final int xpForNext;

  double get progress => xpForNext == 0 ? 0 : (xpIntoLevel / xpForNext).clamp(0, 1);
  int get xpRemaining => xpForNext - xpIntoLevel;

  /// Total XP at which the current level started.
  int get levelFloor => totalXp - xpIntoLevel;
}

/// Converts accumulated XP into a level. The total is never reset; the
/// level is always derived from it, so history stays consistent.
LevelInfo levelFromXp(int totalXp, int Function(int level) xpToNext) {
  final xp = totalXp < 0 ? 0 : totalXp;
  var level = 1;
  var remaining = xp;
  // Guard against a misconfigured curve producing an infinite loop.
  while (level < 10000) {
    final need = xpToNext(level);
    if (need <= 0 || remaining < need) break;
    remaining -= need;
    level++;
  }
  return LevelInfo(
    level: level,
    totalXp: xp,
    xpIntoLevel: remaining,
    xpForNext: xpToNext(level),
  );
}

LevelInfo characterLevel(GameConfig c, int totalXp) =>
    levelFromXp(totalXp, c.xpToNextLevel);

LevelInfo attributeLevel(GameConfig c, int xp) =>
    levelFromXp(xp, c.xpToNextAttributeLevel);

/// Total XP needed to reach [level] from zero.
int totalXpForLevel(int level, int Function(int level) xpToNext) {
  var sum = 0;
  for (var l = 1; l < level; l++) {
    sum += xpToNext(l);
  }
  return sum;
}
