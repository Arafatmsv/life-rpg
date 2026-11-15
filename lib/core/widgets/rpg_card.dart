import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_theme.dart';
import '../../app/theme/app_tokens.dart';

/// The base surface of the design system: graphite panel with a hairline
/// border and an optional accent glow.
class RpgCard extends StatelessWidget {
  const RpgCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(Gap.md),
    this.onTap,
    this.onLongPress,
    this.glow,
    this.borderColor,
    this.gradient,
    this.radius = Radii.lg,
    this.semanticLabel,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final Color? glow;
  final Color? borderColor;
  final Gradient? gradient;
  final double radius;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final br = BorderRadius.circular(radius);
    // Flat surface with a hairline border. `glow` and `gradient` are kept in
    // the API for callers but intentionally not rendered.
    final content = Ink(
      decoration: BoxDecoration(
        borderRadius: br,
        color: AppColors.surface0,
        border: Border.all(color: borderColor ?? AppColors.borderSoft),
      ),
      child: Padding(padding: padding, child: child),
    );
    return Semantics(
      label: semanticLabel,
      button: onTap != null,
      child: Material(
        type: MaterialType.transparency,
        child: onTap == null && onLongPress == null
            ? content
            : InkWell(
                borderRadius: br,
                onTap: onTap,
                onLongPress: onLongPress,
                child: content,
              ),
      ),
    );
  }
}

/// Section title with an optional trailing action.
class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {super.key, this.action, this.onAction, this.subtitle});

  final String title;
  final String? subtitle;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: Gap.sm, top: Gap.xs),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppText.display(22)),
                  if (subtitle != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(subtitle!, style: AppText.ui(12.5, color: AppColors.textMuted)),
                    ),
                ],
              ),
            ),
            if (action != null)
              TextButton(onPressed: onAction, child: Text(action!)),
          ],
        ),
      );
}

/// Small rounded tag.
class Pill extends StatelessWidget {
  const Pill(this.text, {super.key, this.color = AppColors.textSecondary, this.icon, this.filled = false});

  final String text;
  final Color color;
  final IconData? icon;
  final bool filled;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: filled ? color.o(0.18) : color.o(0.08),
          borderRadius: BorderRadius.circular(Radii.pill),
          border: Border.all(color: color.o(0.28)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 12, color: color),
              const SizedBox(width: 4),
            ],
            Flexible(
              child: Text(
                text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.ui(11.5, weight: FontWeight.w700, color: color),
              ),
            ),
          ],
        ),
      );
}

/// Rounded icon tile used in lists and cards.
class IconTile extends StatelessWidget {
  const IconTile(this.icon, {super.key, required this.color, this.size = 40});

  final IconData icon;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: size,
        height: size,
        child: Icon(icon, color: AppColors.textSecondary, size: size * 0.5),
      );
}
