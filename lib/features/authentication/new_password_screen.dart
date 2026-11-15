import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../app/theme/app_theme.dart';
import '../../app/theme/app_tokens.dart';
import '../../core/errors/game_exception.dart';
import '../../core/widgets/buttons.dart';
import '../../core/widgets/feedback.dart';
import '../../core/widgets/rpg_card.dart';
import 'session_controller.dart';

/// Shown after opening a password-reset link.
class NewPasswordScreen extends ConsumerStatefulWidget {
  const NewPasswordScreen({super.key});

  @override
  ConsumerState<NewPasswordScreen> createState() => _NewPasswordScreenState();
}

class _NewPasswordScreenState extends ConsumerState<NewPasswordScreen> {
  final _form = GlobalKey<FormState>();
  final _p1 = TextEditingController();
  final _p2 = TextEditingController();
  var _busy = false;

  @override
  void dispose() {
    _p1.dispose();
    _p2.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      await ref.read(authRepositoryProvider).updatePassword(_p1.text);
      if (!mounted) return;
      showMessage(context, 'Пароль обновлён');
      ref.read(sessionProvider.notifier).finishRecovery();
    } catch (e) {
      if (mounted) showMessage(context, describeError(e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(Gap.lg),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: RpgCard(
                  padding: const EdgeInsets.all(Gap.lg),
                  child: Form(
                    key: _form,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text('Новый пароль', style: AppText.display(28)),
                        const SizedBox(height: Gap.md),
                        TextFormField(
                          controller: _p1,
                          obscureText: true,
                          decoration: const InputDecoration(labelText: 'Новый пароль'),
                          validator: (v) => (v ?? '').length < 8 ? 'Минимум 8 символов' : null,
                        ),
                        const SizedBox(height: Gap.sm),
                        TextFormField(
                          controller: _p2,
                          obscureText: true,
                          decoration: const InputDecoration(labelText: 'Повторите пароль'),
                          validator: (v) => v != _p1.text ? 'Пароли не совпадают' : null,
                        ),
                        const SizedBox(height: Gap.lg),
                        RpgButton(label: 'Сохранить', loading: _busy, expand: true, onPressed: _save),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
}
