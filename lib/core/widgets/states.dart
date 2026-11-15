import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_theme.dart';
import '../../app/theme/app_tokens.dart';
import 'buttons.dart';
import 'motion.dart';
import 'rpg_card.dart';

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
    this.compact = false,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool compact;

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.symmetric(vertical: compact ? Gap.md : Gap.xxl, horizontal: Gap.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconTile(icon, color: AppColors.textSecondary, size: compact ? 40 : 48),
            const SizedBox(height: Gap.md),
            Text(title, textAlign: TextAlign.center, style: AppText.ui(compact ? 15 : 17, weight: FontWeight.w600)),
            const SizedBox(height: Gap.xs),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360),
              child: Text(
                message,
                textAlign: TextAlign.center,
                style: AppText.ui(14, color: AppColors.textSecondary, height: 1.45),
              ),
            ),
            if (actionLabel != null) ...[
              const SizedBox(height: Gap.lg),
              RpgButton(label: actionLabel!, onPressed: onAction, kind: RpgButtonKind.secondary, compact: true),
            ],
          ],
        ),
      );
}

class ErrorView extends StatelessWidget {
  const ErrorView({super.key, required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(Gap.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Не удалось загрузить', style: AppText.ui(17, weight: FontWeight.w600)),
              const SizedBox(height: Gap.xs),
              Text(message, textAlign: TextAlign.center, style: AppText.ui(14, color: AppColors.textSecondary)),
              if (onRetry != null) ...[
                const SizedBox(height: Gap.lg),
                RpgButton(label: 'Повторить', onPressed: onRetry, kind: RpgButtonKind.secondary, compact: true),
              ],
            ],
          ),
        ),
      );
}

/// Placeholder block for skeleton screens. Pulses gently unless motion is
/// reduced.
class SkeletonBox extends StatefulWidget {
  const SkeletonBox({super.key, this.width, required this.height, this.radius = Radii.md});
  final double? width;
  final double height;
  final double radius;

  @override
  State<SkeletonBox> createState() => _SkeletonBoxState();
}

class _SkeletonBoxState extends State<SkeletonBox> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (Motion.enabled(context)) {
      if (!_c.isAnimating) _c.repeat(reverse: true);
    } else {
      _c.stop();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _c,
        builder: (context, _) => Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            color: Color.lerp(AppColors.surface1, AppColors.surface2, _c.value),
            borderRadius: BorderRadius.circular(widget.radius),
          ),
        ),
      );
}

/// Skeleton of a typical screen (title, a summary block, a list). Shown
/// instead of a spinner while data loads, so the layout does not jump.
class LoadingView extends StatelessWidget {
  const LoadingView({super.key, this.label = 'Загрузка'});
  final String label;

  @override
  Widget build(BuildContext context) => Semantics(
        label: label,
        child: SafeArea(
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: ListView(
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.all(Gap.md),
                children: const [
                  SkeletonBox(width: 160, height: 22),
                  SizedBox(height: Gap.lg),
                  SkeletonBox(height: 132, radius: Radii.lg),
                  SizedBox(height: Gap.lg),
                  SkeletonBox(width: 120, height: 16),
                  SizedBox(height: Gap.sm),
                  SkeletonBox(height: 64, radius: Radii.lg),
                  SizedBox(height: Gap.xs),
                  SkeletonBox(height: 64, radius: Radii.lg),
                  SizedBox(height: Gap.xs),
                  SkeletonBox(height: 64, radius: Radii.lg),
                ],
              ),
            ),
          ),
        ),
      );
}
