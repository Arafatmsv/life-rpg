import '../../core/utils/json.dart';
import 'enums.dart';

class UnlockedSkill {
  const UnlockedSkill({required this.skillId, required this.unlockedAt, required this.cost});

  final String skillId;
  final DateTime unlockedAt;

  /// Skill points spent (stored so catalog rebalancing never refunds or
  /// charges retroactively).
  final int cost;

  Json toJson() => {'skill_id': skillId, 'unlocked_at': iso(unlockedAt), 'cost': cost};

  factory UnlockedSkill.fromJson(Json j) => UnlockedSkill(
        skillId: asString(j['skill_id']),
        unlockedAt: parseDateOr(j['unlocked_at'], DateTime.now()),
        cost: asInt(j['cost'], 1),
      );
}

class UnlockedAchievement {
  const UnlockedAchievement({required this.achievementId, required this.unlockedAt});

  final String achievementId;
  final DateTime unlockedAt;

  Json toJson() => {'achievement_id': achievementId, 'unlocked_at': iso(unlockedAt)};

  factory UnlockedAchievement.fromJson(Json j) => UnlockedAchievement(
        achievementId: asString(j['achievement_id']),
        unlockedAt: parseDateOr(j['unlocked_at'], DateTime.now()),
      );
}

/// A day the player marked as planned rest or protected with a streak freeze.
/// Such days never break a streak and never produce penalties.
class DayMark {
  const DayMark({required this.dayKey, required this.kind, required this.createdAt});

  final String dayKey;
  final DayMarkKind kind;
  final DateTime createdAt;

  Json toJson() => {'day_key': dayKey, 'kind': kind.name, 'created_at': iso(createdAt)};

  factory DayMark.fromJson(Json j) => DayMark(
        dayKey: asString(j['day_key']),
        kind: DayMarkKind.fromName(j['kind'] as String?),
        createdAt: parseDateOr(j['created_at'], DateTime.now()),
      );
}
