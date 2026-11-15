import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_theme.dart';
import '../../app/theme/app_tokens.dart';
import '../../features/game/game_controller.dart';
import '../game/game_engine.dart';
import '../../data/models/game_state.dart';
import 'buttons.dart';

void showMessage(BuildContext context, String text, {bool error = false}) {
  final m = ScaffoldMessenger.maybeOf(context);
  m?.hideCurrentSnackBar();
  m?.showSnackBar(SnackBar(
    content: Row(
      children: [
        Icon(error ? Icons.error_outline_rounded : Icons.check_circle_outline_rounded,
            color: error ? AppColors.danger : AppColors.success, size: 20),
        const SizedBox(width: 10),
        Expanded(child: Text(text)),
      ],
    ),
    duration: Duration(seconds: error ? 4 : 2),
  ));
}

/// Runs an engine action through the controller and reports failures.
Future<bool> runGameAction(
  BuildContext context,
  WidgetRef ref,
  GameResult Function(GameEngine e, GameState s) action, {
  String? success,
}) async {
  final err = await ref.read(gameControllerProvider.notifier).act(action);
  if (!context.mounted) return err == null;
  if (err != null) {
    showMessage(context, err, error: true);
    return false;
  }
  if (success != null) showMessage(context, success);
  return true;
}

Future<bool> confirm(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Подтвердить',
  bool destructive = false,
}) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actionsPadding: const EdgeInsets.fromLTRB(Gap.md, 0, Gap.md, Gap.md),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text('Отмена', style: AppText.ui(14, weight: FontWeight.w700, color: AppColors.textSecondary)),
        ),
        RpgButton(
          label: confirmLabel,
          compact: true,
          kind: destructive ? RpgButtonKind.danger : RpgButtonKind.primary,
          onPressed: () => Navigator.pop(ctx, true),
        ),
      ],
    ),
  );
  return r ?? false;
}

/// Opens a scrollable, keyboard-aware bottom sheet; on wide screens it is
/// limited in width instead of stretching edge to edge.
Future<T?> showRpgSheet<T>(BuildContext context, {required WidgetBuilder builder}) =>
    showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      // Above the shell's navigation bar, not inside the tab's navigator.
      useRootNavigator: true,
      constraints: const BoxConstraints(maxWidth: 640),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
        child: builder(ctx),
      ),
    );

/// Asks for a whole number (progress amount, etc.).
Future<int?> askNumber(BuildContext context,
    {required String title, String? hint, String? suffix, int? initial}) async {
  final ctrl = TextEditingController(text: initial?.toString() ?? '');
  final formKey = GlobalKey<FormState>();
  final r = await showDialog<int>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Form(
        key: formKey,
        child: TextFormField(
          controller: ctrl,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(hintText: hint, suffixText: suffix),
          validator: (v) {
            final n = int.tryParse((v ?? '').trim());
            if (n == null || n <= 0) return 'Введите число больше нуля';
            if (n > 1000000) return 'Слишком большое значение';
            return null;
          },
          onFieldSubmitted: (_) {
            if (formKey.currentState!.validate()) Navigator.pop(ctx, int.parse(ctrl.text.trim()));
          },
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Отмена')),
        RpgButton(
          label: 'Готово',
          compact: true,
          onPressed: () {
            if (formKey.currentState!.validate()) Navigator.pop(ctx, int.parse(ctrl.text.trim()));
          },
        ),
      ],
    ),
  );
  // Disposed after the dialog's exit animation, which still reads it.
  Future.delayed(const Duration(milliseconds: 400), ctrl.dispose);
  return r;
}
