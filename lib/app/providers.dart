import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce/hive.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/game/game_engine.dart';
import '../core/services/export_service.dart';
import '../core/services/notification_service.dart';
import '../data/repositories/auth_repository.dart';
import 'config/env.dart';

/// Small key-value box for app-level flags (not game data). Opened in main.
final appPrefsProvider = Provider<Box<String>>((ref) => throw UnimplementedError());

final supabaseClientProvider = Provider<SupabaseClient?>(
  (ref) => Env.hasSupabase ? Supabase.instance.client : null,
);

final authRepositoryProvider =
    Provider<AuthRepository>((ref) => AuthRepository(ref.watch(supabaseClientProvider)));

final engineProvider = Provider<GameEngine>((ref) => GameEngine());

final notificationServiceProvider = Provider<NotificationService>((ref) => NotificationService());

final exportServiceProvider = Provider<ExportService>((ref) => const ExportService());
