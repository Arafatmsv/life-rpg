import 'package:supabase_flutter/supabase_flutter.dart';

import '../../app/config/env.dart';
import '../../core/errors/game_exception.dart';

/// Thin wrapper over Supabase Auth with Russian error messages.
class AuthRepository {
  AuthRepository(this._client);

  final SupabaseClient? _client;

  bool get isAvailable => _client != null;

  User? get currentUser => _client?.auth.currentUser;

  Stream<AuthState> get changes =>
      _client?.auth.onAuthStateChange ?? const Stream<AuthState>.empty();

  SupabaseClient get _c {
    final c = _client;
    if (c == null) throw const AppException('Облачный сервер не настроен');
    return c;
  }

  Future<void> signIn(String email, String password) =>
      _guard(() => _c.auth.signInWithPassword(email: email.trim(), password: password));

  /// Returns true when the project requires e-mail confirmation first.
  Future<bool> signUp(String email, String password) async {
    final res = await _guard(() => _c.auth.signUp(
          email: email.trim(),
          password: password,
          emailRedirectTo: Env.authRedirectUrl,
        ));
    return res.session == null;
  }

  Future<void> sendPasswordReset(String email) => _guard(
        () => _c.auth.resetPasswordForEmail(email.trim(), redirectTo: Env.authRedirectUrl),
      );

  Future<void> updatePassword(String password) =>
      _guard(() => _c.auth.updateUser(UserAttributes(password: password)));

  Future<void> signOut() => _guard(() => _c.auth.signOut());

  Future<T> _guard<T>(Future<T> Function() f) async {
    try {
      return await f();
    } on AuthException catch (e) {
      throw AppException(_translate(e.message));
    } catch (e) {
      if (e is AppException) rethrow;
      throw const AppException('Нет соединения с сервером. Проверьте интернет.');
    }
  }

  static String _translate(String m) {
    final s = m.toLowerCase();
    if (s.contains('invalid login')) return 'Неверный e-mail или пароль';
    if (s.contains('already registered') || s.contains('already exists')) {
      return 'Этот e-mail уже зарегистрирован';
    }
    if (s.contains('email not confirmed')) return 'Подтвердите e-mail по ссылке из письма';
    if (s.contains('password should be')) return 'Пароль слишком простой (минимум 6 символов)';
    if (s.contains('rate limit')) return 'Слишком много попыток. Подождите немного';
    if (s.contains('invalid email') || s.contains('unable to validate email')) {
      return 'Некорректный e-mail';
    }
    return m;
  }
}
