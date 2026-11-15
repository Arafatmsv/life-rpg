import '../../core/utils/json.dart';

/// A real-life reward the player defines and buys with Gold.
class Reward {
  const Reward({
    required this.id,
    required this.title,
    required this.cost,
    required this.icon,
    required this.createdAt,
    required this.updatedAt,
    this.description = '',
    this.deleted = false,
  });

  final String id;
  final String title;
  final String description;
  final int cost;
  final String icon;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool deleted;

  Reward copyWith({
    String? title,
    String? description,
    int? cost,
    String? icon,
    DateTime? updatedAt,
    bool? deleted,
  }) =>
      Reward(
        id: id,
        title: title ?? this.title,
        description: description ?? this.description,
        cost: cost ?? this.cost,
        icon: icon ?? this.icon,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        deleted: deleted ?? this.deleted,
      );

  Json toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'cost': cost,
        'icon': icon,
        'created_at': iso(createdAt),
        'updated_at': iso(updatedAt),
        'deleted': deleted,
      };

  factory Reward.fromJson(Json j) {
    final now = DateTime.now();
    return Reward(
      id: asString(j['id']),
      title: asString(j['title']),
      description: asString(j['description']),
      cost: asInt(j['cost'], 100),
      icon: asString(j['icon'], 'gift'),
      createdAt: parseDateOr(j['created_at'], now),
      updatedAt: parseDateOr(j['updated_at'], now),
      deleted: asBool(j['deleted']),
    );
  }
}

class RewardPurchase {
  const RewardPurchase({
    required this.id,
    required this.rewardId,
    required this.rewardTitle,
    required this.cost,
    required this.purchasedAt,
    this.refundedAt,
  });

  final String id;
  final String rewardId;
  final String rewardTitle;
  final int cost;
  final DateTime purchasedAt;
  final DateTime? refundedAt;

  bool get isRefunded => refundedAt != null;

  RewardPurchase refunded(DateTime at) => RewardPurchase(
        id: id,
        rewardId: rewardId,
        rewardTitle: rewardTitle,
        cost: cost,
        purchasedAt: purchasedAt,
        refundedAt: at,
      );

  Json toJson() => {
        'id': id,
        'reward_id': rewardId,
        'reward_title': rewardTitle,
        'cost': cost,
        'purchased_at': iso(purchasedAt),
        'refunded_at': isoOrNull(refundedAt),
      };

  factory RewardPurchase.fromJson(Json j) => RewardPurchase(
        id: asString(j['id']),
        rewardId: asString(j['reward_id']),
        rewardTitle: asString(j['reward_title']),
        cost: asInt(j['cost']),
        purchasedAt: parseDateOr(j['purchased_at'], DateTime.now()),
        refundedAt: parseDate(j['refunded_at']),
      );
}
