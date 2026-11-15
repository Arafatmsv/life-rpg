import '../../core/utils/json.dart';
import 'enums.dart';

class Character {
  const Character({
    required this.id,
    required this.name,
    required this.avatarId,
    required this.avatarColor,
    required this.characterClass,
    required this.focus,
    required this.goals,
    required this.createdAt,
    required this.updatedAt,
    this.gender,
    this.age,
  });

  final String id;
  final String name;

  /// Key of an emblem from the avatar catalog.
  final String avatarId;

  /// Index into the avatar color palette.
  final int avatarColor;
  final String? gender;
  final int? age;
  final CharacterClass characterClass;

  /// Development priorities. Quests in these attributes earn a bonus.
  final List<AttributeType> focus;
  final List<String> goals;
  final DateTime createdAt;
  final DateTime updatedAt;

  Character copyWith({
    String? name,
    String? avatarId,
    int? avatarColor,
    String? Function()? gender,
    int? Function()? age,
    CharacterClass? characterClass,
    List<AttributeType>? focus,
    List<String>? goals,
    DateTime? updatedAt,
  }) =>
      Character(
        id: id,
        name: name ?? this.name,
        avatarId: avatarId ?? this.avatarId,
        avatarColor: avatarColor ?? this.avatarColor,
        gender: gender != null ? gender() : this.gender,
        age: age != null ? age() : this.age,
        characterClass: characterClass ?? this.characterClass,
        focus: focus ?? this.focus,
        goals: goals ?? this.goals,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  Json toJson() => {
        'id': id,
        'name': name,
        'avatar_id': avatarId,
        'avatar_color': avatarColor,
        'gender': gender,
        'age': age,
        'class_id': characterClass.name,
        'focus': focus.map((a) => a.name).toList(),
        'goals': goals,
        'created_at': iso(createdAt),
        'updated_at': iso(updatedAt),
      };

  factory Character.fromJson(Json j) {
    final now = DateTime.now();
    return Character(
      id: asString(j['id']),
      name: asString(j['name'], 'Герой'),
      avatarId: asString(j['avatar_id'], 'sword'),
      avatarColor: asInt(j['avatar_color']),
      gender: j['gender'] as String?,
      age: asIntOrNull(j['age']),
      characterClass: CharacterClass.fromName(j['class_id'] as String?),
      focus: asStringList(j['focus']).map(AttributeType.fromName).toSet().toList(),
      goals: asStringList(j['goals']),
      createdAt: parseDateOr(j['created_at'], now),
      updatedAt: parseDateOr(j['updated_at'], now),
    );
  }
}
