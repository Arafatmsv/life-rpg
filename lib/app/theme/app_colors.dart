import 'package:flutter/material.dart';

import '../../data/models/enums.dart';
import '../../data/models/user_settings.dart';

/// Dark Fantasy palette: graphite surfaces, gold and amethyst accents.
abstract final class AppColors {
  static const bg = Color(0xFF0B0C10);
  static const bgElevated = Color(0xFF0F1116);
  static const surface0 = Color(0xFF12141A);
  static const surface1 = Color(0xFF171A21);
  static const surface2 = Color(0xFF1E222B);
  static const surface3 = Color(0xFF262B36);
  static const border = Color(0xFF2A2F3A);
  static const borderSoft = Color(0xFF1F232C);

  static const text = Color(0xFFECE8DF);
  static const textSecondary = Color(0xFFA6A9B3);
  static const textMuted = Color(0xFF6E7383);

  static const gold = Color(0xFFE3B55B);
  static const goldBright = Color(0xFFF6D88C);
  static const goldDeep = Color(0xFF9E6F28);
  static const violet = Color(0xFF8C6CF0);
  static const violetBright = Color(0xFFB9A2FF);
  static const violetDeep = Color(0xFF4B3591);

  static const success = Color(0xFF46C98B);
  static const danger = Color(0xFFE5604F);
  static const warning = Color(0xFFF0A040);
  static const info = Color(0xFF5AA2F0);

  static const xpStart = Color(0xFF8C6CF0);
  static const xpEnd = Color(0xFFE3B55B);

  /// Categorical attribute colors. Validated as a set on the dark surface
  /// (lightness band, CVD separation of adjacent pairs, contrast ≥ 3:1) —
  /// the order follows [AttributeType]; do not swap single entries.
  static Color attribute(AttributeType a) => switch (a) {
        AttributeType.physique => const Color(0xFFE66767),
        AttributeType.intelligence => const Color(0xFF3987E5),
        AttributeType.discipline => const Color(0xFFD55181),
        AttributeType.career => const Color(0xFFC98500),
        AttributeType.finance => const Color(0xFF008300),
        AttributeType.social => const Color(0xFF9085E9),
        AttributeType.mental => const Color(0xFF199E70),
      };

  /// Sequential ramp (one hue, dark → light on the dark surface) for the
  /// activity heatmap. Index 0 = no activity.
  static const heat = [
    Color(0xFF1E222B),
    Color(0xFF104281),
    Color(0xFF1C5CAB),
    Color(0xFF2A78D6),
    Color(0xFF5598E7),
    Color(0xFF86B6EF),
  ];

  /// Status colors — reserved for good / critical, always shown with a label.
  static const statusGood = Color(0xFF0CA30C);
  static const statusCritical = Color(0xFFD03B3B);

  static Color rarity(Rarity r) => switch (r) {
        Rarity.common => const Color(0xFF9CA3AF),
        Rarity.rare => const Color(0xFF5AA2F0),
        Rarity.epic => const Color(0xFFA685FA),
        Rarity.legendary => const Color(0xFFF2B84B),
      };

  static Color difficulty(Difficulty d) => switch (d) {
        Difficulty.easy => const Color(0xFF46C98B),
        Difficulty.normal => const Color(0xFF5AA2F0),
        Difficulty.hard => const Color(0xFFF0A040),
        Difficulty.epic => const Color(0xFFE5604F),
      };

  static Color severity(Severity s) => switch (s) {
        Severity.light => const Color(0xFFF0C040),
        Severity.medium => const Color(0xFFF0A040),
        Severity.severe => const Color(0xFFE5604F),
      };

  static Color questType(QuestType t) => switch (t) {
        QuestType.daily => const Color(0xFF5AA2F0),
        QuestType.weekly => const Color(0xFF3CCFC0),
        QuestType.main => const Color(0xFFE3B55B),
        QuestType.side => const Color(0xFF9CA3AF),
        QuestType.boss => const Color(0xFFE5604F),
      };

  /// Primary accent chosen by the player.
  static Color accent(AccentTheme a) => switch (a) {
        AccentTheme.gold => gold,
        AccentTheme.violet => violetBright,
        AccentTheme.emerald => const Color(0xFF4CD6A2),
        AccentTheme.crimson => const Color(0xFFEF6B7B),
      };

  static Color accentSecondary(AccentTheme a) => switch (a) {
        AccentTheme.gold => violet,
        AccentTheme.violet => gold,
        AccentTheme.emerald => const Color(0xFF5AA2F0),
        AccentTheme.crimson => gold,
      };

  /// Avatar frame colors to pick from.
  static const avatarPalette = [
    Color(0xFFE3B55B),
    Color(0xFF8C6CF0),
    Color(0xFF5AA2F0),
    Color(0xFF46C98B),
    Color(0xFFEF6F5E),
    Color(0xFFF07AB8),
    Color(0xFF3CCFC0),
    Color(0xFFC9CDD6),
  ];
}

extension ColorAlpha on Color {
  Color o(double opacity) => withValues(alpha: opacity);
}
