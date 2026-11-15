import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/widgets/states.dart';
import '../features/achievements/achievements_screen.dart';
import '../features/analytics/analytics_screen.dart';
import '../features/attributes/attribute_detail_screen.dart';
import '../features/authentication/auth_screen.dart';
import '../features/authentication/new_password_screen.dart';
import '../features/authentication/session_controller.dart';
import '../features/character/character_screen.dart';
import '../features/game/game_controller.dart';
import '../features/home/home_screen.dart';
import '../features/journal/journal_editor_screen.dart';
import '../features/journal/journal_screen.dart';
import '../features/missions/quest_detail_screen.dart';
import '../features/notifications/notification_settings_screen.dart';
import '../features/onboarding/onboarding_screen.dart';
import '../features/penalties/penalties_screen.dart';
import '../features/profile/profile_screen.dart';
import '../features/quests/quests_screen.dart';
import '../features/rewards/rewards_screen.dart';
import '../features/settings/penalty_settings_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/shell/app_shell.dart';
import '../features/skills/skills_screen.dart';
import '../features/streaks/streaks_screen.dart';
import '../data/models/enums.dart';

/// Bridges Riverpod state changes to GoRouter's refresh mechanism.
class _RouterRefresh extends ChangeNotifier {
  _RouterRefresh(Ref ref) {
    ref.listen(sessionProvider, (_, __) => notifyListeners());
    ref.listen(gameControllerProvider, (prev, next) {
      // Only structural changes matter for redirects.
      final a = prev?.valueOrNull?.hasCharacter, b = next.valueOrNull?.hasCharacter;
      if (a != b || prev?.isLoading != next.isLoading) notifyListeners();
    });
  }
}

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = _RouterRefresh(ref);
  ref.onDispose(refresh.dispose);
  return GoRouter(
    initialLocation: '/home',
    refreshListenable: refresh,
    redirect: (context, state) {
      final session = ref.read(sessionProvider);
      final loc = state.matchedLocation;
      final inAuth = loc.startsWith('/auth');
      if (session.passwordRecovery) return loc == '/auth/new-password' ? null : '/auth/new-password';
      if (session.mode == SessionMode.signedOut) return inAuth ? null : '/auth';
      final game = ref.read(gameControllerProvider);
      if (game.isLoading && !game.hasValue) return loc == '/splash' ? null : '/splash';
      if (game.hasError) return loc == '/splash' ? null : '/splash';
      final has = game.valueOrNull?.hasCharacter ?? false;
      if (!has) return loc == '/onboarding' ? null : '/onboarding';
      if (inAuth || loc == '/onboarding' || loc == '/splash') return '/home';
      return null;
    },
    routes: [
      GoRoute(path: '/splash', builder: (_, __) => const _Splash()),
      GoRoute(
        path: '/auth',
        builder: (_, __) => const AuthScreen(),
        routes: [
          GoRoute(path: 'new-password', builder: (_, __) => const NewPasswordScreen()),
        ],
      ),
      GoRoute(path: '/onboarding', builder: (_, __) => const OnboardingScreen()),
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => AppShell(shell: shell),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(path: '/home', builder: (_, __) => const HomeScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/quests',
              builder: (_, __) => const QuestsScreen(),
              routes: [
                GoRoute(
                  path: ':id',
                  builder: (_, s) => QuestDetailScreen(questId: s.pathParameters['id']!),
                ),
              ],
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/character',
              builder: (_, __) => const CharacterScreen(),
              routes: [
                GoRoute(
                  path: 'attribute/:name',
                  builder: (_, s) => AttributeDetailScreen(
                    attribute: AttributeType.fromName(s.pathParameters['name']),
                  ),
                ),
              ],
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/skills',
              builder: (_, s) => SkillsScreen(
                initial: s.uri.queryParameters['a'] == null
                    ? null
                    : AttributeType.fromName(s.uri.queryParameters['a']),
              ),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/profile',
              builder: (_, __) => const ProfileScreen(),
              routes: [
                GoRoute(path: 'analytics', builder: (_, __) => const AnalyticsScreen()),
                GoRoute(path: 'achievements', builder: (_, __) => const AchievementsScreen()),
                GoRoute(path: 'rewards', builder: (_, __) => const RewardsScreen()),
                GoRoute(path: 'streaks', builder: (_, __) => const StreaksScreen()),
                GoRoute(path: 'penalties', builder: (_, __) => const PenaltiesScreen()),
                GoRoute(
                  path: 'journal',
                  builder: (_, __) => const JournalScreen(),
                  routes: [
                    GoRoute(
                      path: ':day',
                      builder: (_, s) => JournalEditorScreen(dayKey: s.pathParameters['day']!),
                    ),
                  ],
                ),
                GoRoute(
                  path: 'settings',
                  builder: (_, __) => const SettingsScreen(),
                  routes: [
                    GoRoute(path: 'penalties', builder: (_, __) => const PenaltySettingsScreen()),
                    GoRoute(
                      path: 'notifications',
                      builder: (_, __) => const NotificationSettingsScreen(),
                    ),
                  ],
                ),
              ],
            ),
          ]),
        ],
      ),
    ],
  );
});

class _Splash extends ConsumerWidget {
  const _Splash();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final game = ref.watch(gameControllerProvider);
    return Scaffold(
      body: game.hasError
          ? ErrorView(
              message: '${game.error}',
              onRetry: () => ref.invalidate(gameControllerProvider),
            )
          : const LoadingView(),
    );
  }
}
