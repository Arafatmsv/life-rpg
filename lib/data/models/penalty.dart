import '../../core/utils/json.dart';
import 'enums.dart';

enum PenaltyKind {
  missedQuest('Пропущено задание'),
  missionFailed('Провал миссии'),
  streakBreak('Прервана серия');

  const PenaltyKind(this.label);
  final String label;

  static PenaltyKind fromName(String? n) => PenaltyKind.values
      .firstWhere((k) => k.name == n, orElse: () => PenaltyKind.missedQuest);
}

/// A journal mark for a missed obligation and the consequences applied.
class PenaltyRecord {
  const PenaltyRecord({
    required this.id,
    required this.kind,
    required this.severity,
    required this.title,
    required this.dayKey,
    required this.createdAt,
    this.questId,
    this.periodKey,
    this.status = PenaltyStatus.open,
    this.resolvedAt,
    this.recoveryQuestId,
    this.goldLost = 0,
    this.xpLost = 0,
    this.bonusBlockedUntil,
  });

  final String id;
  final PenaltyKind kind;
  final Severity severity;
  final String title;
  final String? questId;
  final String? periodKey;

  /// Game day the obligation was missed.
  final String dayKey;
  final PenaltyStatus status;
  final DateTime createdAt;
  final DateTime? resolvedAt;
  final String? recoveryQuestId;
  final int goldLost;
  final int xpLost;

  /// Streak bonus is suspended through this day (inclusive).
  final String? bonusBlockedUntil;

  PenaltyRecord resolve(PenaltyStatus s, DateTime at) => PenaltyRecord(
        id: id,
        kind: kind,
        severity: severity,
        title: title,
        questId: questId,
        periodKey: periodKey,
        dayKey: dayKey,
        status: s,
        createdAt: createdAt,
        resolvedAt: at,
        recoveryQuestId: recoveryQuestId,
        goldLost: goldLost,
        xpLost: xpLost,
        bonusBlockedUntil: s == PenaltyStatus.excused ? null : bonusBlockedUntil,
      );

  Json toJson() => {
        'id': id,
        'kind': kind.name,
        'severity': severity.name,
        'title': title,
        'quest_id': questId,
        'period_key': periodKey,
        'day_key': dayKey,
        'status': status.name,
        'created_at': iso(createdAt),
        'resolved_at': isoOrNull(resolvedAt),
        'recovery_quest_id': recoveryQuestId,
        'gold_lost': goldLost,
        'xp_lost': xpLost,
        'bonus_blocked_until': bonusBlockedUntil,
      };

  factory PenaltyRecord.fromJson(Json j) => PenaltyRecord(
        id: asString(j['id']),
        kind: PenaltyKind.fromName(j['kind'] as String?),
        severity: Severity.fromName(j['severity'] as String?),
        title: asString(j['title']),
        questId: j['quest_id'] as String?,
        periodKey: j['period_key'] as String?,
        dayKey: asString(j['day_key']),
        status: PenaltyStatus.fromName(j['status'] as String?),
        createdAt: parseDateOr(j['created_at'], DateTime.now()),
        resolvedAt: parseDate(j['resolved_at']),
        recoveryQuestId: j['recovery_quest_id'] as String?,
        goldLost: asInt(j['gold_lost']),
        xpLost: asInt(j['xp_lost']),
        bonusBlockedUntil: j['bonus_blocked_until'] as String?,
      );
}
