import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/config/env.dart';
import '../../app/providers.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_theme.dart';
import '../../app/theme/app_tokens.dart';
import '../../core/errors/game_exception.dart';
import '../../core/widgets/buttons.dart';
import '../../core/widgets/feedback.dart';
import '../../core/widgets/rpg_card.dart';
import 'session_controller.dart';

enum _Mode { signIn, signUp, reset }

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _password2 = TextEditingController();
  var _mode = _Mode.signIn;
  var _busy = false;
  var _obscure = true;
  String? _info;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _password2.dispose();
    super.dispose();
  }

  static final _emailRe = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _info = null;
    });
    final session = ref.read(sessionProvider.notifier);
    try {
      switch (_mode) {
        case _Mode.signIn:
          await session.signIn(_email.text, _password.text);
        case _Mode.signUp:
          final confirm = await session.signUp(_email.text, _password.text);
          if (confirm) {
            setState(() {
              _mode = _Mode.signIn;
              _info = 'Мы отправили письмо на ${_email.text.trim()}. '
                  'Подтвердите e-mail и войдите.';
            });
          }
        case _Mode.reset:
          await ref.read(authRepositoryProvider).sendPasswordReset(_email.text);
          setState(() {
            _mode = _Mode.signIn;
            _info = 'Ссылка для сброса пароля отправлена на ${_email.text.trim()}.';
          });
      }
    } catch (e) {
      if (mounted) showMessage(context, describeError(e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    final title = switch (_mode) {
      _Mode.signIn => 'Вход',
      _Mode.signUp => 'Регистрация',
      _Mode.reset => 'Восстановление пароля',
    };
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(0, -0.9),
            radius: 1.2,
            colors: [AppColors.violetDeep.o(0.35), AppColors.bg],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(Gap.lg),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Icon(Icons.auto_awesome_rounded, color: accent, size: 40),
                    const SizedBox(height: Gap.sm),
                    Text('Life RPG', textAlign: TextAlign.center, style: AppText.display(44)),
                    Text(
                      'Прокачивай персонажа.\nПрокачивай себя в реальной жизни.',
                      textAlign: TextAlign.center,
                      style: AppText.ui(14, color: AppColors.textSecondary, height: 1.5),
                    ),
                    const SizedBox(height: Gap.xl),
                    if (!Env.hasSupabase) _offlineOnly(context) else _formCard(title),
                    const SizedBox(height: Gap.md),
                    RpgButton(
                      label: 'Играть без аккаунта',
                      icon: Icons.phone_android_rounded,
                      kind: RpgButtonKind.secondary,
                      expand: true,
                      onPressed: _busy
                          ? null
                          : () => ref.read(sessionProvider.notifier).continueAsGuest(),
                    ),
                    const SizedBox(height: Gap.xs),
                    Text(
                      'Прогресс сохранится на устройстве. Позже его можно перенести в аккаунт.',
                      textAlign: TextAlign.center,
                      style: AppText.ui(12, color: AppColors.textMuted),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _offlineOnly(BuildContext context) => RpgCard(
        child: Text(
          'Облачная синхронизация не настроена в этой сборке. '
          'Можно играть локально — все данные останутся на устройстве.',
          style: AppText.ui(14, color: AppColors.textSecondary, height: 1.45),
        ),
      );

  Widget _formCard(String title) => RpgCard(
        padding: const EdgeInsets.all(Gap.lg),
        child: Form(
          key: _form,
          child: AutofillGroup(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(title, style: AppText.display(26)),
                const SizedBox(height: Gap.md),
                if (_info != null) ...[
                  Container(
                    padding: const EdgeInsets.all(Gap.sm),
                    decoration: BoxDecoration(
                      color: AppColors.success.o(0.08),
                      borderRadius: Radii.rMd,
                      border: Border.all(color: AppColors.success.o(0.3)),
                    ),
                    child: Text(_info!, style: AppText.ui(13, color: AppColors.success)),
                  ),
                  const SizedBox(height: Gap.md),
                ],
                TextFormField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.email],
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'E-mail',
                    prefixIcon: Icon(Icons.alternate_email_rounded),
                  ),
                  validator: (v) =>
                      _emailRe.hasMatch((v ?? '').trim()) ? null : 'Введите корректный e-mail',
                ),
                if (_mode != _Mode.reset) ...[
                  const SizedBox(height: Gap.sm),
                  TextFormField(
                    controller: _password,
                    obscureText: _obscure,
                    autofillHints: [
                      _mode == _Mode.signUp ? AutofillHints.newPassword : AutofillHints.password,
                    ],
                    textInputAction:
                        _mode == _Mode.signUp ? TextInputAction.next : TextInputAction.done,
                    onFieldSubmitted: (_) => _mode == _Mode.signIn ? _submit() : null,
                    decoration: InputDecoration(
                      labelText: 'Пароль',
                      prefixIcon: const Icon(Icons.lock_outline_rounded),
                      suffixIcon: IconButton(
                        tooltip: _obscure ? 'Показать пароль' : 'Скрыть пароль',
                        icon: Icon(_obscure ? Icons.visibility_rounded : Icons.visibility_off_rounded),
                        onPressed: () => setState(() => _obscure = !_obscure),
                      ),
                    ),
                    validator: (v) => (v ?? '').length < 8 ? 'Минимум 8 символов' : null,
                  ),
                ],
                if (_mode == _Mode.signUp) ...[
                  const SizedBox(height: Gap.sm),
                  TextFormField(
                    controller: _password2,
                    obscureText: _obscure,
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => _submit(),
                    decoration: const InputDecoration(
                      labelText: 'Повторите пароль',
                      prefixIcon: Icon(Icons.lock_outline_rounded),
                    ),
                    validator: (v) => v != _password.text ? 'Пароли не совпадают' : null,
                  ),
                ],
                const SizedBox(height: Gap.lg),
                RpgButton(
                  label: switch (_mode) {
                    _Mode.signIn => 'Войти',
                    _Mode.signUp => 'Создать аккаунт',
                    _Mode.reset => 'Отправить ссылку',
                  },
                  loading: _busy,
                  expand: true,
                  onPressed: _submit,
                ),
                const SizedBox(height: Gap.sm),
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  children: [
                    if (_mode != _Mode.signIn)
                      TextButton(
                        onPressed: () => setState(() => _mode = _Mode.signIn),
                        child: const Text('У меня есть аккаунт'),
                      ),
                    if (_mode != _Mode.signUp)
                      TextButton(
                        onPressed: () => setState(() => _mode = _Mode.signUp),
                        child: const Text('Регистрация'),
                      ),
                    if (_mode == _Mode.signIn)
                      TextButton(
                        onPressed: () => setState(() => _mode = _Mode.reset),
                        child: const Text('Забыли пароль?'),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
}
