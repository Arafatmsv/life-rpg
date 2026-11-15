import '../../core/utils/json.dart';

/// Private daily reflection. One entry per game day.
class JournalEntry {
  const JournalEntry({
    required this.id,
    required this.dayKey,
    required this.createdAt,
    required this.updatedAt,
    this.wins = '',
    this.fails = '',
    this.learned = '',
    this.improve = '',
    this.dayNotes = '',
    this.tomorrow = '',
    this.rating,
    this.deleted = false,
  });

  final String id;
  final String dayKey;
  final String wins;
  final String fails;
  final String learned;
  final String improve;
  final String dayNotes;
  final String tomorrow;

  /// 1…10, null when not rated.
  final int? rating;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool deleted;

  bool get isEmpty =>
      [wins, fails, learned, improve, dayNotes, tomorrow].every((s) => s.trim().isEmpty) &&
      rating == null;

  String get searchable =>
      '$wins\n$fails\n$learned\n$improve\n$dayNotes\n$tomorrow'.toLowerCase();

  JournalEntry copyWith({
    String? wins,
    String? fails,
    String? learned,
    String? improve,
    String? dayNotes,
    String? tomorrow,
    int? Function()? rating,
    DateTime? updatedAt,
    bool? deleted,
  }) =>
      JournalEntry(
        id: id,
        dayKey: dayKey,
        wins: wins ?? this.wins,
        fails: fails ?? this.fails,
        learned: learned ?? this.learned,
        improve: improve ?? this.improve,
        dayNotes: dayNotes ?? this.dayNotes,
        tomorrow: tomorrow ?? this.tomorrow,
        rating: rating != null ? rating() : this.rating,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        deleted: deleted ?? this.deleted,
      );

  Json toJson() => {
        'id': id,
        'day_key': dayKey,
        'wins': wins,
        'fails': fails,
        'learned': learned,
        'improve': improve,
        'day_notes': dayNotes,
        'tomorrow': tomorrow,
        'rating': rating,
        'created_at': iso(createdAt),
        'updated_at': iso(updatedAt),
        'deleted': deleted,
      };

  factory JournalEntry.fromJson(Json j) {
    final now = DateTime.now();
    return JournalEntry(
      id: asString(j['id']),
      dayKey: asString(j['day_key']),
      wins: asString(j['wins']),
      fails: asString(j['fails']),
      learned: asString(j['learned']),
      improve: asString(j['improve']),
      dayNotes: asString(j['day_notes']),
      tomorrow: asString(j['tomorrow']),
      rating: asIntOrNull(j['rating'])?.clamp(1, 10),
      createdAt: parseDateOr(j['created_at'], now),
      updatedAt: parseDateOr(j['updated_at'], now),
      deleted: asBool(j['deleted']),
    );
  }
}
