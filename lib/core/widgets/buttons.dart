import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_theme.dart';
import '../../app/theme/app_tokens.dart';

enum RpgButtonKind { primary, secondary, ghost, danger }

/// Flat button: solid accent (primary), outline (secondary), text-only
/// (ghost) or red outline (danger). An optional icon uses the text colour.
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
    final (Color fg, Color bg, Color border) = switch (kind) {
      RpgButtonKind.primary => (AppColors.bg, accent, accent),
      RpgButtonKind.secondary => (AppColors.text, Colors.transparent, AppColors.border),
      RpgButtonKind.ghost => (AppColors.textSecondary, Colors.transparent, Colors.transparent),
      RpgButtonKind.danger => (AppColors.danger, Colors.transparent, AppColors.danger.o(0.5)),
    };
    final h = compact ? 38.0 : 48.0;
    final child = loading
        ? SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 1.6, color: fg))
        : Row(mainAxisSize: MainAxisSize.min, children: [
            if (icon != null) ...[
              Icon(icon, size: 18, color: fg),
              if (label.isNotEmpty) const SizedBox(width: 8),
            ],
            if (label.isNotEmpty)
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.ui(compact ? 14 : 15, weight: FontWeight.w500, color: fg),
                ),
              ),
          ]);
    return Opacity(
      opacity: enabled ? 1 : 0.4,
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
              width: expand ? double.infinity : null,
              padding: EdgeInsets.symmetric(horizontal: compact ? Gap.md : Gap.lg),
              decoration: BoxDecoration(
                color: bg,
                borderRadius: Radii.rMd,
                border: Border.all(color: border),
              ),
              child: Center(widthFactor: 1, child: child),
            ),
          ),
        ),
      ),
    );
  }
}

/// Selectable option for enums (difficulty, category…). The selected state
/// is a light border and brighter text, not a colour fill.
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

  /// Kept for API compatibility; options are not colour-coded.
  final Color? color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          borderRadius: Radii.rSm,
          child: Container(
            constraints: const BoxConstraints(minHeight: 38),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: selected ? AppColors.surface2 : Colors.transparent,
              borderRadius: Radii.rSm,
              border: Border.all(color: selected ? accent : AppColors.border),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              if (icon != null) ...[
                Icon(icon, size: 16, color: selected ? AppColors.text : AppColors.textMuted),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: AppText.ui(13,
                    weight: FontWeight.w500, color: selected ? AppColors.text : AppColors.textSecondary),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}
