import 'package:flutter/material.dart';

import '../../data/models/enums.dart';

/// Central icon registry so models can store icon keys as strings.
abstract final class RpgIcons {
  static IconData attribute(AttributeType a) => switch (a) {
        AttributeType.physique => Icons.fitness_center_rounded,
        AttributeType.intelligence => Icons.auto_stories_rounded,
        AttributeType.discipline => Icons.shield_moon_rounded,
        AttributeType.career => Icons.work_rounded,
        AttributeType.finance => Icons.savings_rounded,
        AttributeType.social => Icons.forum_rounded,
        AttributeType.mental => Icons.self_improvement_rounded,
      };

  static IconData questType(QuestType t) => switch (t) {
        QuestType.daily => Icons.wb_sunny_rounded,
        QuestType.weekly => Icons.date_range_rounded,
        QuestType.main => Icons.flag_rounded,
        QuestType.side => Icons.explore_rounded,
        QuestType.boss => Icons.whatshot_rounded,
      };

  static IconData characterClass(CharacterClass c) => switch (c) {
        CharacterClass.warrior => Icons.shield_rounded,
        CharacterClass.scholar => Icons.menu_book_rounded,
        CharacterClass.entrepreneur => Icons.trending_up_rounded,
        CharacterClass.creator => Icons.palette_rounded,
        CharacterClass.universal => Icons.all_inclusive_rounded,
      };

  static const _byKey = <String, IconData>{
    'flag': Icons.flag_rounded,
    'flame': Icons.local_fire_department_rounded,
    'crown': Icons.workspace_premium_rounded,
    'infinity': Icons.all_inclusive_rounded,
    'book': Icons.menu_book_rounded,
    'sunrise': Icons.wb_twilight_rounded,
    'hammer': Icons.construction_rounded,
    'skull': Icons.whatshot_rounded,
    'star': Icons.star_rounded,
    'gem': Icons.diamond_rounded,
    'shield': Icons.shield_rounded,
    'dumbbell': Icons.fitness_center_rounded,
    'footprints': Icons.directions_walk_rounded,
    'hourglass': Icons.hourglass_bottom_rounded,
    'feather': Icons.edit_note_rounded,
    'scroll': Icons.history_edu_rounded,
    'gift': Icons.card_giftcard_rounded,
    'tree': Icons.account_tree_rounded,
    'compass': Icons.explore_rounded,
    'phoenix': Icons.autorenew_rounded,
    'moon': Icons.bedtime_rounded,
    // rewards
    'film': Icons.movie_rounded,
    'game': Icons.sports_esports_rounded,
    'coffee': Icons.local_cafe_rounded,
    'food': Icons.restaurant_rounded,
    'shopping': Icons.shopping_bag_rounded,
    'travel': Icons.flight_rounded,
    'music': Icons.headphones_rounded,
    'spa': Icons.spa_rounded,
    'sleep': Icons.hotel_rounded,
    'book2': Icons.local_library_rounded,
    // avatars
    'sword': Icons.gavel_rounded,
    'owl': Icons.visibility_rounded,
    'bolt': Icons.bolt_rounded,
    'leaf': Icons.eco_rounded,
    'mountain': Icons.landscape_rounded,
    'wave': Icons.waves_rounded,
    'rocket': Icons.rocket_launch_rounded,
    'brush': Icons.brush_rounded,
    'chess': Icons.extension_rounded,
    'sun': Icons.wb_sunny_rounded,
    'heart': Icons.favorite_rounded,
  };

  static IconData byKey(String key) => _byKey[key] ?? Icons.auto_awesome_rounded;

  static const avatarKeys = [
    'sword', 'shield', 'owl', 'bolt', 'flame', 'leaf', 'mountain',
    'wave', 'rocket', 'brush', 'chess', 'sun', 'moon', 'heart', 'crown', 'gem',
  ];

  static const rewardKeys = [
    'gift', 'film', 'game', 'coffee', 'food', 'shopping',
    'travel', 'music', 'spa', 'sleep', 'book2', 'star',
  ];
}
