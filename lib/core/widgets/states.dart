import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_theme.dart';
import '../../app/theme/app_tokens.dart';
import 'buttons.dart';

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
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return Padding(
      padding: EdgeInsets.symmetric(vertical: compact ? Gap.lg : Gap.xxxl, horizontal: Gap.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: compact ? 56 : 76,
            height: compact ? 56 : 76,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(colors: [accent.o(0.22), accent.o(0.02)]),
              border: Border.all(color: accent.o(0.3)),
            ),
            child: Icon(icon, color: accent, size: compact ? 26 : 34),
          ),
          const SizedBox(height: Gap.md),
          Text(title, textAlign: TextAlign.center, style: AppText.display(compact ? 20 : 24)),
          const SizedBox(height: Gap.xs),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 380),
            child: Text(
              message,
              textAlign: TextAlign.center,
              style: AppText.ui(14, color: AppColors.textSecondary, height: 1.45),
            ),
          ),
          if (actionLabel != null) ...[
            const SizedBox(height: Gap.lg),
            RpgButton(label: actionLabel!, onPressed: onAction, icon: Icons.add_rounded),
          ],
        ],
      ),
    );
  }
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
              const Icon(Icons.error_outline_rounded, color: AppColors.danger, size: 44),
              const SizedBox(height: Gap.md),
              Text('Не удалось загрузить', style: AppText.display(24)),
              const SizedBox(height: Gap.xs),
              Text(message,
                  textAlign: TextAlign.center,
                  style: AppText.ui(14, color: AppColors.textSecondary)),
              if (onRetry != null) ...[
                const SizedBox(height: Gap.lg),
                RpgButton(
                  label: 'Повторить',
                  icon: Icons.refresh_rounded,
                  onPressed: onRetry,
                  kind: RpgButtonKind.secondary,
                ),
              ],
            ],
          ),
        ),
      );
}

class LoadingView extends StatelessWidget {
  const LoadingView({super.key, this.label = 'Загрузка мира…'});
  final String label;

  @override
  Widget build(BuildContext context) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 34,
              height: 34,
              child: CircularProgressIndicator(strokeWidth: 2.6),
            ),
            const SizedBox(height: Gap.md),
            Text(label, style: AppText.ui(13, color: AppColors.textMuted)),
          ],
        ),
      );
}
