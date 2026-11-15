import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_theme.dart';
import '../../app/theme/app_tokens.dart';

enum RpgButtonKind { primary, secondary, ghost, danger }

/// Primary call-to-action with a metallic accent gradient.
class RpgButton extends StatelessWidget {
  const RpgButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.kind = RpgButtonKind.primary,
    this.loading = false,
    this.expand = false,
    this.compact = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final RpgButtonKind kind;
  final bool loading;
  final bool expand;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    final enabled = onPressed != null && !loading;
    final (Color fg, Gradient? gradient, Color? bg, Color border) = switch (kind) {
      RpgButtonKind.primary => (
          const Color(0xFF1A1408),
          LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color.lerp(accent, Colors.white, 0.25)!, accent, Color.lerp(accent, Colors.black, 0.2)!],
          ),
          null,
          accent.o(0.6),
        ),
      RpgButtonKind.secondary => (AppColors.text, null, AppColors.surface2, AppColors.border),
      RpgButtonKind.ghost => (accent, null, Colors.transparent, Colors.transparent),
      RpgButtonKind.danger => (AppColors.danger, null, AppColors.danger.o(0.08), AppColors.danger.o(0.4)),
    };
    final h = compact ? 40.0 : 50.0;
    final child = Row(
      mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (loading)
          SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2, color: fg),
          )
        else if (icon != null)
          Icon(icon, size: 19, color: fg),
        if ((loading || icon != null) && label.isNotEmpty) const SizedBox(width: Gap.xs),
        if (label.isNotEmpty)
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.ui(compact ? 14 : 15, weight: FontWeight.w700, color: fg),
            ),
          ),
      ],
    );
    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: Semantics(
        button: true,
        enabled: enabled,
        label: label,
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: enabled ? onPressed : null,
            borderRadius: Radii.rMd,
            child: Ink(
              height: h,
              padding: EdgeInsets.symmetric(horizontal: compact ? Gap.md : Gap.lg),
              decoration: BoxDecoration(
                gradient: gradient,
                color: bg,
                borderRadius: Radii.rMd,
                border: Border.all(color: border),
                boxShadow: kind == RpgButtonKind.primary && enabled
                    ? [BoxShadow(color: accent.o(0.28), blurRadius: 18, spreadRadius: -6, offset: const Offset(0, 6))]
                    : null,
              ),
              child: Center(widthFactor: 1, child: child),
            ),
          ),
        ),
      ),
    );
  }
}

/// Selectable chip used for enums (difficulty, category…).
class ChoiceChipX extends StatelessWidget {
  const ChoiceChipX({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.color,
    this.icon,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color? color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final c = color ?? Theme.of(context).colorScheme.primary;
    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          borderRadius: Radii.rSm,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            constraints: const BoxConstraints(minHeight: 40),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: selected ? c.o(0.16) : AppColors.surface1,
              borderRadius: Radii.rSm,
              border: Border.all(color: selected ? c.o(0.7) : AppColors.border),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 16, color: selected ? c : AppColors.textSecondary),
                  const SizedBox(width: 6),
                ],
                Text(
                  label,
                  style: AppText.ui(13,
                      weight: selected ? FontWeight.w700 : FontWeight.w600,
                      color: selected ? c : AppColors.textSecondary),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
