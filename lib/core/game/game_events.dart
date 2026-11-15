import '../../data/models/enums.dart';
import '../../data/models/penalty.dart';
import '../../data/models/quest.dart';
import '../../data/models/reward.dart';
import 'achievement_catalog.dart';
import 'skill_catalog.dart';

/// Things that happened during an engine action. The UI turns them into
/// animations and toasts; the notification service into system notices.
sealed class GameEvent {
  const GameEvent();
}

class XpGained extends GameEvent {
  const XpGained(this.amount, this.attribute, this.reason);
  final int amount;
  final AttributeType? attribute;
  final String reason;
}

class GoldChanged extends GameEvent {
  const GoldChanged(this.amount, this.reason);
  final int amount;
  final String reason;
}

class LevelUp extends GameEvent {
  const LevelUp(this.level, this.goldReward);
  final int level;
  final int goldReward;
}

class AttributeLevelUp extends GameEvent {
  const AttributeLevelUp(this.attribute, this.level);
  final AttributeType attribute;
  final int level;
}

class AchievementUnlockedEvent extends GameEvent {
  const AchievementUnlockedEvent(this.def, this.xp, this.gold);
  final AchievementDef def;
  final int xp;
  final int gold;
}

class QuestCompletedEvent extends GameEvent {
  const QuestCompletedEvent(this.quest, this.xp, this.gold);
  final Quest quest;
  final int xp;
  final int gold;
}

class SkillUnlockedEvent extends GameEvent {
  const SkillUnlockedEvent(this.def);
  final SkillDef def;
}

class RewardPurchasedEvent extends GameEvent {
  const RewardPurchasedEvent(this.reward);
  final Reward reward;
}

class PenaltyAppliedEvent extends GameEvent {
  const PenaltyAppliedEvent(this.penalties);
  final List<PenaltyRecord> penalties;
}

class DailyClearEvent extends GameEvent {
  const DailyClearEvent(this.xp, this.gold);
  final int xp;
  final int gold;
}
