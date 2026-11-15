import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../app/config/env.dart';
import '../../app/providers.dart';

enum SessionMode { signedOut, guest, user }

class SessionState {
  const SessionState({
    required this.mode,
    this.userId,
    this.email,
    this.passwordRecovery = false,
  });

  final SessionMode mode;
  final String? userId;
  final String? email;

  /// The user opened a password-reset link and must choose a new password.
  final bool passwordRecovery;

  bool get isUser => mode == SessionMode.user;
  bool get isGuest => mode == SessionMode.guest;

  /// Local storage namespace of this session.
  String? get namespace => switch (mode) {
        SessionMode.user => userId,
        SessionMode.guest => 'guest',
        SessionMode.signedOut => null,
      };
}

final sessionProvider =
    NotifierProvider<SessionController, SessionState>(SessionController.new);

class SessionController extends Notifier<SessionState> {
  static const _guestKey = 'guest_mode';
  StreamSubscription<AuthState>? _sub;

  @override
  SessionState build() {
    final auth = ref.watch(authRepositoryProvider);
    _sub?.cancel();
    _sub = auth.changes.listen(_onAuth);
    ref.onDispose(() => _sub?.cancel());
    final user = auth.currentUser;
    if (user != null) return _userState(user);
    final prefs = ref.read(appPrefsProvider);
    if (!Env.hasSupabase || prefs.get(_guestKey) == '1') {
      return const SessionState(mode: SessionMode.guest);
    }
    return const SessionState(mode: SessionMode.signedOut);
  }

  SessionState _userState(User u, {bool recovery = false}) =>
      SessionState(mode: SessionMode.user, userId: u.id, email: u.email, passwordRecovery: recovery);

  void _onAuth(AuthState s) {
    final user = s.session?.user;
    switch (s.event) {
      case AuthChangeEvent.passwordRecovery:
        if (user != null) state = _userState(user, recovery: true);
      case AuthChangeEvent.signedOut:
        final prefs = ref.read(appPrefsProvider);
        state = SessionState(
          mode: prefs.get(_guestKey) == '1' ? SessionMode.guest : SessionMode.signedOut,
        );
      default:
        if (user != null && (state.userId != user.id || !state.isUser)) {
          state = _userState(user);
        }
    }
  }

  Future<void> continueAsGuest() async {
    await ref.read(appPrefsProvider).put(_guestKey, '1');
    state = const SessionState(mode: SessionMode.guest);
  }

  Future<void> signIn(String email, String password) async {
    final auth = ref.read(authRepositoryProvider);
    await auth.signIn(email, password);
    final u = auth.currentUser;
    if (u != null) state = _userState(u);
  }

  /// Returns true when e-mail confirmation is required.
  Future<bool> signUp(String email, String password) async {
    final auth = ref.read(authRepositoryProvider);
    final needsConfirm = await auth.signUp(email, password);
    final u = auth.currentUser;
    if (u != null && !needsConfirm) state = _userState(u);
    return needsConfirm;
  }

  Future<void> signOut() async {
    await ref.read(appPrefsProvider).delete(_guestKey);
    if (state.isUser) {
      await ref.read(authRepositoryProvider).signOut();
    }
    state = SessionState(
      mode: Env.hasSupabase ? SessionMode.signedOut : SessionMode.guest,
    );
  }

  /// Leaves guest mode and returns to the sign-in screen (guest data stays
  /// on the device and can be migrated into a new account).
  Future<void> leaveGuest() async {
    await ref.read(appPrefsProvider).delete(_guestKey);
    state = const SessionState(mode: SessionMode.signedOut);
  }

  void finishRecovery() {
    final u = ref.read(authRepositoryProvider).currentUser;
    if (u != null) state = _userState(u);
  }
}
