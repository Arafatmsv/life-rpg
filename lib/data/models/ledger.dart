import '../../core/utils/json.dart';
import 'enums.dart';

/// One closed period of a quest (a day, a week or the whole one-off quest).
class QuestCompletion {
  const QuestCompletion({
    required this.id,
    required this.questId,
    required this.periodKey,
    required this.dayKey,
    required this.completedAt,
    required this.xp,
    required this.gold,
    required this.attribute,
    required this.questType,
    this.durationMinutes,
    this.revertedAt,
  });

  final String id;
  final String questId;

  /// `d:2026-11-13`, `w:2026-11-09` or `once`.
  final String periodKey;

  /// Game day the completion happened.
  final String dayKey;
  final DateTime completedAt;
  final int xp;
  final int gold;
  final AttributeType attribute;
  final QuestType questType;
  final int? durationMinutes;
  final DateTime? revertedAt;

  bool get isActive => revertedAt == null;

  QuestCompletion reverted(DateTime at) => QuestCompletion(
        id: id,
        questId: questId,
        periodKey: periodKey,
        dayKey: dayKey,
        completedAt: completedAt,
        xp: xp,
        gold: gold,
        attribute: attribute,
        questType: questType,
        durationMinutes: durationMinutes,
        revertedAt: at,
      );

  Json toJson() => {
        'id': id,
        'quest_id': questId,
        'period_key': periodKey,
        'day_key': dayKey,
        'completed_at': iso(completedAt),
        'xp': xp,
        'gold': gold,
        'attribute': attribute.name,
        'quest_type': questType.name,
        'duration_minutes': durationMinutes,
        'reverted_at': isoOrNull(revertedAt),
      };

  factory QuestCompletion.fromJson(Json j) => QuestCompletion(
        id: asString(j['id']),
        questId: asString(j['quest_id']),
        periodKey: asString(j['period_key']),
        dayKey: asString(j['day_key']),
        completedAt: parseDateOr(j['completed_at'], DateTime.now()),
        xp: asInt(j['xp']),
        gold: asInt(j['gold']),
        attribute: AttributeType.fromName(j['attribute'] as String?),
        questType: QuestType.fromName(j['quest_type'] as String?),
        durationMinutes: asIntOrNull(j['duration_minutes']),
        revertedAt: parseDate(j['reverted_at']),
      );
}

/// Partial progress towards a quest target (pages read, steps, check-ins).
class ProgressLog {
  const ProgressLog({
    required this.id,
    required this.questId,
    required this.periodKey,
    required this.dayKey,
    required this.amount,
    required this.unit,
    required this.loggedAt,
  });

  final String id;
  final String questId;
  final String periodKey;
  final String dayKey;
  final int amount;
  final MetricUnit unit;
  final DateTime loggedAt;

  Json toJson() => {
        'id': id,
        'quest_id': questId,
        'period_key': periodKey,
        'day_key': dayKey,
        'amount': amount,
        'unit': unit.name,
        'logged_at': iso(loggedAt),
      };

  factory ProgressLog.fromJson(Json j) => ProgressLog(
        id: asString(j['id']),
        questId: asString(j['quest_id']),
        periodKey: asString(j['period_key']),
        dayKey: asString(j['day_key']),
        amount: asInt(j['amount']),
        unit: MetricUnit.fromName(j['unit'] as String?),
        loggedAt: parseDateOr(j['logged_at'], DateTime.now()),
      );
}

/// Append-only XP ledger entry. Total XP is the sum of all entries, so XP
/// is never "reset" on level up — the level is derived from the total.
class XpTransaction {
  const XpTransaction({
    required this.id,
    required this.amount,
    required this.source,
    required this.dayKey,
    required this.createdAt,
    this.attribute,
    this.sourceId,
    this.note = '',
  });

  final String id;
  final int amount;

  /// Attribute the XP counts towards; null = character XP only.
  final AttributeType? attribute;
  final LedgerSource source;
  final String? sourceId;
  final String note;
  final String dayKey;
  final DateTime createdAt;

  Json toJson() => {
        'id': id,
        'amount': amount,
        'attribute': attribute?.name,
        'source': source.name,
        'source_id': sourceId,
        'note': note,
        'day_key': dayKey,
        'created_at': iso(createdAt),
      };

  factory XpTransaction.fromJson(Json j) => XpTransaction(
        id: asString(j['id']),
        amount: asInt(j['amount']),
        attribute: j['attribute'] == null
            ? null
            : AttributeType.fromName(j['attribute'] as String?),
        source: LedgerSource.fromName(j['source'] as String?),
        sourceId: j['source_id'] as String?,
        note: asString(j['note']),
        dayKey: asString(j['day_key']),
        createdAt: parseDateOr(j['created_at'], DateTime.now()),
      );
}

class GoldTransaction {
  const GoldTransaction({
    required this.id,
    required this.amount,
    required this.source,
    required this.dayKey,
    required this.createdAt,
    this.sourceId,
    this.note = '',
  });

  final String id;
  final int amount;
  final LedgerSource source;
  final String? sourceId;
  final String note;
  final String dayKey;
  final DateTime createdAt;

  Json toJson() => {
        'id': id,
        'amount': amount,
        'source': source.name,
        'source_id': sourceId,
        'note': note,
        'day_key': dayKey,
        'created_at': iso(createdAt),
      };

  factory GoldTransaction.fromJson(Json j) => GoldTransaction(
        id: asString(j['id']),
        amount: asInt(j['amount']),
        source: LedgerSource.fromName(j['source'] as String?),
        sourceId: j['source_id'] as String?,
        note: asString(j['note']),
        dayKey: asString(j['day_key']),
        createdAt: parseDateOr(j['created_at'], DateTime.now()),
      );
}
