import 'package:flutter/material.dart';

import '../../data/models/enums.dart';
import '../../data/models/user_settings.dart';

/// Restrained palette: warm graphite neutrals and one accent (brass).
///
/// Colour is reserved for meaning, not decoration: the accent marks progress
/// and the primary action, red marks problems, everything else is greyscale.
/// No gradients, glows or per-category rainbow colours.
abstract final class AppColors {
  // Surfaces
  static const bg = Color(0xFF0E0E0F);
  static const bgElevated = Color(0xFF121213);
  static const surface0 = Color(0xFF151516);
  static const surface1 = Color(0xFF19191B);
  static const surface2 = Color(0xFF202022);
  static const surface3 = Color(0xFF2A2A2D);
  static const border = Color(0xFF2E2E31);
  static const borderSoft = Color(0xFF232325);

  // Text
  static const text = Color(0xFFEDEBE6);
  static const textSecondary = Color(0xFFA3A19B);
  static const textMuted = Color(0xFF6F6D68);

  // Accent (brass). Names kept from the first palette for compatibility.
  static const gold = Color(0xFFC2A26B);
  static const goldBright = Color(0xFFD3B988);
  static const goldDeep = Color(0xFF8C744B);

  // Former violet tones are neutral now; they only map to secondary ink.
  static const violet = Color(0xFF8E8C87);
  static const violetBright = Color(0xFFCFCCC5);
  static const violetDeep = surface2;

  // States: muted, always paired with text.
  static const success = Color(0xFF8BA383);
  static const danger = Color(0xFFC4675C);
  static const warning = Color(0xFFC79558);
  static const info = Color(0xFF8E9BA6);

  static const xpStart = gold;
  static const xpEnd = gold;

  /// Attributes are told apart by name and icon, not by colour.
  static Color attribute(AttributeType a) => const Color(0xFFBDBAB3);

  /// One-hue sequential ramp (graphite → brass) for the activity calendar.
  /// Index 0 = no activity.
  static const heat = [
    Color(0xFF222224),
    Color(0xFF3A3428),
    Color(0xFF574A33),
    Color(0xFF7A6643),
    Color(0xFFA08756),
    Color(0xFFC9AA6F),
  ];

  static const statusGood = success;
  static const statusCritical = danger;

  /// Rarity reads as a greyscale step; only legendary gets the accent.
  static Color rarity(Rarity r) => switch (r) {
        Rarity.common => textMuted,
        Rarity.rare => textSecondary,
        Rarity.epic => text,
        Rarity.legendary => gold,
      };

  static Color difficulty(Difficulty d) => textSecondary;

  static Color severity(Severity s) => switch (s) {
        Severity.light => textSecondary,
        Severity.medium => warning,
        Severity.severe => danger,
      };

  static Color questType(QuestType t) => textSecondary;

  /// Accent options the player can choose. All muted metals/earth tones.
  static Color accent(AccentTheme a) => switch (a) {
        AccentTheme.gold => gold,
        AccentTheme.violet => const Color(0xFFB4B2AC),
        AccentTheme.emerald => const Color(0xFF93A48C),
        AccentTheme.crimson => const Color(0xFFB87E62),
      };

  static Color accentSecondary(AccentTheme a) => textSecondary;

  /// Avatar frame tones: metals only.
  static const avatarPalette = [
    Color(0xFFC2A26B), // brass
    Color(0xFFB4B2AC), // silver
    Color(0xFFA97E5A), // bronze
    Color(0xFF7D7B76), // graphite
  ];
}

extension ColorAlpha on Color {
  Color o(double opacity) => withValues(alpha: opacity);
}
