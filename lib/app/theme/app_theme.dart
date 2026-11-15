import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../data/models/user_settings.dart';
import 'app_colors.dart';
import 'app_tokens.dart';

/// Typography: one family (Onest, Cyrillic) in a few weights. Headings
/// differ by size and weight only. Display sizes were tuned for the old
/// serif face, so they are scaled down here instead of at every call site.
abstract final class AppText {
  static TextStyle display(double size, {FontWeight weight = FontWeight.w600, Color? color}) {
    final s = size * 0.8;
    return GoogleFonts.onest(
      fontSize: s,
      fontWeight: weight == FontWeight.w700 ? FontWeight.w600 : weight,
      color: color ?? AppColors.text,
      height: 1.15,
      letterSpacing: -0.02 * s,
    );
  }

  static TextStyle ui(double size,
          {FontWeight weight = FontWeight.w400, Color? color, double? height, double? spacing}) =>
      GoogleFonts.onest(
        fontSize: size,
        fontWeight: weight,
        color: color ?? AppColors.text,
        height: height,
        letterSpacing: spacing,
      );

  /// Tabular digits for counters.
  static TextStyle number(double size, {FontWeight weight = FontWeight.w600, Color? color}) =>
      ui(size, weight: weight, color: color).copyWith(
        fontFeatures: const [FontFeature.tabularFigures()],
      );

  static TextStyle label({Color? color}) =>
      ui(11, weight: FontWeight.w500, color: color ?? AppColors.textMuted, spacing: 0.6);
}

ThemeData buildTheme(AccentTheme accentTheme) {
  final accent = AppColors.accent(accentTheme);
  final secondary = AppColors.accentSecondary(accentTheme);
  final scheme = ColorScheme(
    brightness: Brightness.dark,
    primary: accent,
    onPrimary: const Color(0xFF1A1408),
    primaryContainer: accent.o(0.18),
    onPrimaryContainer: accent,
    secondary: secondary,
    onSecondary: Colors.white,
    secondaryContainer: secondary.o(0.18),
    onSecondaryContainer: secondary,
    tertiary: AppColors.success,
    onTertiary: Colors.black,
    error: AppColors.danger,
    onError: Colors.white,
    surface: AppColors.surface0,
    onSurface: AppColors.text,
    onSurfaceVariant: AppColors.textSecondary,
    surfaceContainerLowest: AppColors.bg,
    surfaceContainerLow: AppColors.surface0,
    surfaceContainer: AppColors.surface1,
    surfaceContainerHigh: AppColors.surface2,
    surfaceContainerHighest: AppColors.surface3,
    outline: AppColors.border,
    outlineVariant: AppColors.borderSoft,
    shadow: Colors.black,
    inverseSurface: AppColors.text,
    onInverseSurface: AppColors.bg,
  );

  final base = ThemeData(useMaterial3: true, colorScheme: scheme, brightness: Brightness.dark);
  final textTheme = GoogleFonts.onestTextTheme(base.textTheme).apply(
    bodyColor: AppColors.text,
    displayColor: AppColors.text,
  );

  OutlineInputBorder border(Color c, [double w = 1]) => OutlineInputBorder(
        borderRadius: Radii.rMd,
        borderSide: BorderSide(color: c, width: w),
      );

  return base.copyWith(
    // No hover effects; touch feedback stays subtle.
    hoverColor: Colors.transparent,
    highlightColor: AppColors.surface3.o(0.5),
    splashFactory: InkRipple.splashFactory,
    splashColor: AppColors.surface3.o(0.6),
    scaffoldBackgroundColor: AppColors.bg,
    canvasColor: AppColors.bg,
    textTheme: textTheme.copyWith(
      headlineLarge: AppText.display(34),
      headlineMedium: AppText.display(28),
      headlineSmall: AppText.display(24),
      titleLarge: AppText.ui(20, weight: FontWeight.w700),
      titleMedium: AppText.ui(16, weight: FontWeight.w700),
      titleSmall: AppText.ui(14, weight: FontWeight.w700),
      bodyLarge: AppText.ui(16, height: 1.45),
      bodyMedium: AppText.ui(14, height: 1.45, color: AppColors.textSecondary),
      bodySmall: AppText.ui(12, height: 1.4, color: AppColors.textMuted),
      labelLarge: AppText.ui(14, weight: FontWeight.w700),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.bg,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: AppText.display(26),
      systemOverlayStyle: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: AppColors.bgElevated,
      ),
    ),
    dividerTheme: const DividerThemeData(color: AppColors.borderSoft, thickness: 1, space: 1),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surface1,
      contentPadding: const EdgeInsets.symmetric(horizontal: Gap.md, vertical: 14),
      hintStyle: AppText.ui(14, color: AppColors.textMuted),
      labelStyle: AppText.ui(14, color: AppColors.textSecondary),
      floatingLabelStyle: AppText.ui(14, color: accent, weight: FontWeight.w600),
      helperStyle: AppText.ui(12, color: AppColors.textMuted),
      errorStyle: AppText.ui(12, color: AppColors.danger),
      border: border(AppColors.border),
      enabledBorder: border(AppColors.border),
      focusedBorder: border(accent, 1.4),
      errorBorder: border(AppColors.danger),
      focusedErrorBorder: border(AppColors.danger, 1.4),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(kMinTap, 48),
        shape: const RoundedRectangleBorder(borderRadius: Radii.rMd),
        textStyle: AppText.ui(15, weight: FontWeight.w700),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(kMinTap, 48),
        foregroundColor: AppColors.text,
        side: const BorderSide(color: AppColors.border),
        shape: const RoundedRectangleBorder(borderRadius: Radii.rMd),
        textStyle: AppText.ui(15, weight: FontWeight.w700),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: accent,
        minimumSize: const Size(kMinTap, kMinTap),
        textStyle: AppText.ui(14, weight: FontWeight.w700),
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(minimumSize: const Size(kMinTap, kMinTap)),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: AppColors.surface1,
      selectedColor: AppColors.surface2,
      side: const BorderSide(color: AppColors.border),
      labelStyle: AppText.ui(13, weight: FontWeight.w600),
      secondaryLabelStyle: AppText.ui(13, weight: FontWeight.w700, color: accent),
      shape: const RoundedRectangleBorder(borderRadius: Radii.rSm),
      checkmarkColor: accent,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? const Color(0xFF1A1408) : AppColors.textSecondary,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? accent : AppColors.surface3,
      ),
      trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
    ),
    sliderTheme: SliderThemeData(
      activeTrackColor: accent,
      inactiveTrackColor: AppColors.surface3,
      thumbColor: accent,
      overlayColor: accent.o(0.12),
      valueIndicatorColor: AppColors.surface3,
      valueIndicatorTextStyle: AppText.ui(13, weight: FontWeight.w700),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: AppColors.surface0,
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
      dragHandleColor: AppColors.border,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(Radii.xl))),
      elevation: 0,
    ),
    dialogTheme: DialogTheme(
      backgroundColor: AppColors.surface1,
      surfaceTintColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: Radii.rLg,
        side: BorderSide(color: AppColors.border),
      ),
      titleTextStyle: AppText.display(24),
      contentTextStyle: AppText.ui(14, color: AppColors.textSecondary, height: 1.45),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: AppColors.surface3,
      contentTextStyle: AppText.ui(14, weight: FontWeight.w600),
      behavior: SnackBarBehavior.floating,
      shape: const RoundedRectangleBorder(borderRadius: Radii.rMd),
      actionTextColor: accent,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: AppColors.bgElevated,
      surfaceTintColor: Colors.transparent,
      indicatorColor: AppColors.surface2,
      indicatorShape: const RoundedRectangleBorder(borderRadius: Radii.rMd),
      height: 64,
      labelTextStyle: WidgetStateProperty.resolveWith(
        (s) => AppText.ui(11.5,
            weight: FontWeight.w700,
            color: s.contains(WidgetState.selected) ? accent : AppColors.textMuted),
      ),
      iconTheme: WidgetStateProperty.resolveWith(
        (s) => IconThemeData(
            color: s.contains(WidgetState.selected) ? accent : AppColors.textMuted, size: 24),
      ),
    ),
    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: AppColors.bgElevated,
      indicatorColor: AppColors.surface2,
      indicatorShape: const RoundedRectangleBorder(borderRadius: Radii.rMd),
      selectedIconTheme: IconThemeData(color: accent),
      unselectedIconTheme: const IconThemeData(color: AppColors.textMuted),
      selectedLabelTextStyle: AppText.ui(12.5, weight: FontWeight.w700, color: accent),
      unselectedLabelTextStyle: AppText.ui(12.5, weight: FontWeight.w600, color: AppColors.textMuted),
    ),
    tabBarTheme: TabBarTheme(
      labelColor: accent,
      unselectedLabelColor: AppColors.textMuted,
      indicatorColor: accent,
      dividerColor: AppColors.borderSoft,
      labelStyle: AppText.ui(14, weight: FontWeight.w700),
      unselectedLabelStyle: AppText.ui(14, weight: FontWeight.w600),
      tabAlignment: TabAlignment.start,
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(color: accent),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: accent,
      foregroundColor: AppColors.bg,
      elevation: 0,
      focusElevation: 0,
      hoverElevation: 0,
      highlightElevation: 0,
      shape: const RoundedRectangleBorder(borderRadius: Radii.rLg),
      extendedTextStyle: AppText.ui(14, weight: FontWeight.w500),
    ),
    listTileTheme: ListTileThemeData(
      iconColor: AppColors.textSecondary,
      titleTextStyle: AppText.ui(15, weight: FontWeight.w600),
      subtitleTextStyle: AppText.ui(13, color: AppColors.textMuted),
      contentPadding: const EdgeInsets.symmetric(horizontal: Gap.md),
    ),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
        color: AppColors.surface3,
        borderRadius: Radii.rSm,
        border: Border.all(color: AppColors.border),
      ),
      textStyle: AppText.ui(12, weight: FontWeight.w600),
    ),
    pageTransitionsTheme: const PageTransitionsTheme(builders: {
      TargetPlatform.android: FadeForwardsPageTransitionsBuilderCompat(),
      TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      TargetPlatform.windows: FadeForwardsPageTransitionsBuilderCompat(),
      TargetPlatform.linux: FadeForwardsPageTransitionsBuilderCompat(),
      TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
    }),
  );
}

/// Soft fade + slight upward slide; light on low-end devices.
class FadeForwardsPageTransitionsBuilderCompat extends PageTransitionsBuilder {
  const FadeForwardsPageTransitionsBuilderCompat();

  @override
  Widget buildTransitions<T>(PageRoute<T> route, BuildContext context,
      Animation<double> animation, Animation<double> secondaryAnimation, Widget child) {
    final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: Tween(begin: const Offset(0, 0.03), end: Offset.zero).animate(curved),
        child: child,
      ),
    );
  }
}
