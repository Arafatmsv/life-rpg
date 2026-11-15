import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/services/web_safe_area.dart';
import '../core/widgets/motion.dart';
import '../data/models/user_settings.dart';
import '../features/game/game_controller.dart';
import 'router.dart';
import 'theme/app_theme.dart';

class LifeRpgApp extends ConsumerWidget {
  const LifeRpgApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final settings = ref.watch(
      gameControllerProvider.select((s) => s.valueOrNull?.settings ?? const UserSettings()),
    );
    return Motion(
      animations: settings.animationsEnabled,
      child: MaterialApp.router(
        title: 'Life RPG',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(settings.accent),
        darkTheme: buildTheme(settings.accent),
        themeMode: ThemeMode.dark,
        routerConfig: router,
        builder: (context, child) => WebSafeArea(child: child ?? const SizedBox.shrink()),
        locale: const Locale('ru'),
        supportedLocales: const [Locale('ru'), Locale('en')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
      ),
    );
  }
}
