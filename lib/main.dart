import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive_ce/hive.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app/app.dart';
import 'app/config/env.dart';
import 'app/providers.dart';
import 'core/services/secure_session_storage.dart';
import 'data/datasources/local_game_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Fonts ship inside the app (assets/fonts) — never download them at runtime.
  GoogleFonts.config.allowRuntimeFetching = false;
  LicenseRegistry.addLicense(() async* {
    for (final f in const ['Manrope', 'CormorantGaramond']) {
      yield LicenseEntryWithLineBreaks([f], await rootBundle.loadString('assets/fonts/$f-OFL.txt'));
    }
  });
  await initializeDateFormatting('ru');
  await LocalGameStore.initialize();
  final prefs = await Hive.openBox<String>('app_prefs');

  if (Env.hasSupabase) {
    await Supabase.initialize(
      url: Env.supabaseUrl,
      publishableKey: Env.supabaseAnonKey,
      authOptions: FlutterAuthClientOptions(
        // Keychain / Keystore on mobile; the web build uses the default.
        localStorage: kIsWeb ? null : const SecureSessionStorage(),
      ),
    );
  }

  runApp(ProviderScope(
    overrides: [appPrefsProvider.overrideWithValue(prefs)],
    child: const LifeRpgApp(),
  ));
}
