import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/errors/game_exception.dart';
import '../../core/game/game_engine.dart';
import '../../core/game/game_events.dart';
import '../../core/game/stats.dart';
import '../../data/datasources/local_game_store.dart';
import '../../data/datasources/remote_game_source.dart';
import '../../data/models/game_state.dart';
import '../../data/repositories/sync_service.dart';
import '../authentication/session_controller.dart';

final gameControllerProvider =
    AsyncNotifierProvider<GameController, GameState>(GameController.new);

/// Derived numbers (level, gold, streak…) for the current state.
final snapshotProvider = Provider<GameSnapshot?>((ref) {
  final s = ref.watch(gameControllerProvider).valueOrNull;
  if (s == null || !s.hasCharacter) return null;
  return ref.watch(engineProvider).snapshot(s);
});

final syncStatusProvider =
    NotifierProvider<SyncStatusNotifier, SyncStatus>(SyncStatusNotifier.new);

class SyncStatusNotifier extends Notifier<SyncStatus> {
  @override
  SyncStatus build() => const SyncStatus.localOnly();
  void set(SyncStatus s) => state = s;
}

/// Owns the game state of the current session: loads it from local
/// storage, applies engine actions, persists every change, queues it for
/// sync and broadcasts game events to the UI.
class GameController extends AsyncNotifier<GameState> {
  LocalGameStore? _store;
  SyncService? _sync;
  final _events = StreamController<GameEvent>.broadcast();
  Timer? _ticker;
  Timer? _syncDebounce;
  Timer? _retry;
  StreamSubscription<List<ConnectivityResult>>? _net;
  AppLifecycleListener? _lifecycle;
  String? _today;
  int _backoff = 5;
  DateTime? _lastPull;

  Stream<GameEvent> get events => _events.stream;
  GameEngine get _engine => ref.read(engineProvider);

  @override
  Future<GameState> build() async {
    final session = ref.watch(sessionProvider);
    _disposeRuntime();
    ref.onDispose(_disposeRuntime);
    final ns = session.namespace;
    if (ns == null) return const GameState();

    final store = await LocalGameStore.open(ns);
    _store = store;
    if (session.isUser) {
      await _migrateGuestIfNeeded(store);
      final client = ref.read(supabaseClientProvider);
      if (client != null) {
        _sync = SyncService(store: store, remote: RemoteGameSource(client));
      }
    }

    var s = store.load();
    // Close finished days (missed quests, overdue missions).
    final r = _engine.evaluateDays(s);
    if (r.changes.isNotEmpty) {
      s = r.state;
      await _persist(r.changes);
      _emitLater(r.events);
    }
    _today = _engine.today(s);
    _startRuntime(session);
    _rescheduleNotifications(s);
    return s;
  }

  // ───────────────────────────── actions ─────────────────────────────

  /// Applies an engine action. Returns an error message for the player, or
  /// null on success.
  Future<String?> act(GameResult Function(GameEngine engine, GameState state) action) async {
    final s = state.valueOrNull;
    if (s == null) return 'Игра ещё загружается';
    final GameResult r;
    try {
      r = action(_engine, s);
    } catch (e) {
      return describeError(e);
    }
    if (r.changes.isEmpty) return null;
    state = AsyncData(r.state);
    try {
      await _persist(r.changes);
    } catch (e) {
      return describeError(e);
    }
    for (final e in r.events) {
      _events.add(e);
    }
    _notifyEvents(r.events);
    _rescheduleNotifications(r.state);
    return null;
  }

  Future<void> _persist(List<EntityChange> changes) async {
    final store = _store;
    if (store == null) return;
    await store.apply(changes);
    if (_sync != null) {
      await store.enqueue(changes);
      _scheduleSync();
    }
  }

  /// Replaces all game data on this device with an exported snapshot.
  /// With an account, every imported row is queued for upload.
  Future<String?> importTables(Map<String, Map<String, Map<String, dynamic>>> tables) async {
    final store = _store;
    if (store == null) return 'Игра ещё загружается';
    try {
      await store.replaceAll(tables);
      if (_sync != null) {
        await store.enqueue([
          for (final t in tables.entries)
            for (final row in t.value.entries) EntityChange(t.key, row.key, row.value),
        ]);
      }
      final r = _engine.evaluateDays(store.load());
      if (r.changes.isNotEmpty) await _persist(r.changes);
      state = AsyncData(r.state);
      _rescheduleNotifications(r.state);
      if (_sync != null) _scheduleSync();
      return null;
    } catch (e) {
      return describeError(e);
    }
  }

  /// Removes all local data of this namespace (used after account deletion
  /// and for "start over").
  Future<void> wipeLocal() async {
    await _store?.clear();
    state = const AsyncData(GameState());
  }

  // ───────────────────────────── sync ─────────────────────────────

  void _scheduleSync({Duration delay = const Duration(seconds: 2)}) {
    _syncDebounce?.cancel();
    _syncDebounce = Timer(delay, () => syncNow());
  }

  Future<void> syncNow({bool forcePull = false}) async {
    final sync = _sync, store = _store;
    if (sync == null || store == null) return;
    final status = ref.read(syncStatusProvider.notifier);
    final current = ref.read(syncStatusProvider);
    status.set(current.copyWith(phase: SyncPhase.syncing, pending: store.pendingCount));
    final pull = forcePull ||
        _lastPull == null ||
        DateTime.now().difference(_lastPull!) > const Duration(minutes: 5);
    try {
      final res = await sync.run(pull: pull);
      if (res.skipped) return;
      if (res.merged != null) {
        _lastPull = DateTime.now();
        final merged = GameState.fromTables(res.merged!);
        final ev = _engine.evaluateDays(merged);
        state = AsyncData(ev.state);
        if (ev.changes.isNotEmpty) {
          await store.apply(ev.changes);
          await store.enqueue(ev.changes);
        }
      }
      _backoff = 5;
      status.set(SyncStatus(
        phase: SyncPhase.idle,
        pending: store.pendingCount,
        rejected: res.rejected,
        lastSyncedAt: DateTime.now(),
      ));
      if (store.pendingCount > 0) _scheduleSync();
    } on RejectedByServer catch (e) {
      status.set(current.copyWith(phase: SyncPhase.error, message: e.message));
    } catch (e) {
      // Network or server unavailable — keep the queue and retry later.
      status.set(current.copyWith(
        phase: SyncPhase.offline,
        pending: store.pendingCount,
        message: e.toString(),
      ));
      _retry?.cancel();
      _retry = Timer(Duration(seconds: _backoff), () => syncNow());
      _backoff = (_backoff * 2).clamp(5, 300);
    }
  }

  Future<void> _migrateGuestIfNeeded(LocalGameStore store) async {
    if (store.load().hasCharacter) return;
    if (!await LocalGameStore.hasCharacter('guest')) return;
    // The account starts empty on this device: carry the guest progress
    // over (it is uploaded; the server keeps it if the account is new).
    final guest = await LocalGameStore.open('guest');
    final tables = guest.readAll();
    await store.replaceAll(tables);
    final changes = <EntityChange>[
      for (final t in tables.entries)
        if (t.key != Tables.meta)
          for (final row in t.value.entries) EntityChange(t.key, row.key, row.value),
    ];
    await store.enqueue(changes);
  }

  // ───────────────────────────── runtime ─────────────────────────────

  void _startRuntime(SessionState session) {
    _ticker = Timer.periodic(const Duration(minutes: 1), (_) => _checkDayChange());
    _lifecycle = AppLifecycleListener(onResume: () {
      _checkDayChange();
      if (_sync != null) syncNow(forcePull: true);
    });
    if (_sync != null) {
      ref.read(syncStatusProvider.notifier).set(SyncStatus(
            phase: SyncPhase.syncing,
            pending: _store?.pendingCount ?? 0,
          ));
      _net = Connectivity().onConnectivityChanged.listen((r) {
        if (!r.contains(ConnectivityResult.none)) syncNow();
      });
      Future.microtask(() => syncNow(forcePull: true));
    } else {
      Future.microtask(() => ref.read(syncStatusProvider.notifier).set(const SyncStatus.localOnly()));
    }
  }

  void _checkDayChange() {
    final s = state.valueOrNull;
    if (s == null || !s.hasCharacter) return;
    final t = _engine.today(s);
    if (t == _today) return;
    _today = t;
    act((e, st) => e.evaluateDays(st));
  }

  void _emitLater(List<GameEvent> events) {
    if (events.isEmpty) return;
    // Let the UI subscribe first.
    Future.delayed(const Duration(milliseconds: 800), () {
      for (final e in events) {
        _events.add(e);
      }
    });
  }

  void _notifyEvents(List<GameEvent> events) {
    final s = state.valueOrNull;
    if (s == null) return;
    final n = s.settings.notifications;
    if (!n.enabled) return;
    final svc = ref.read(notificationServiceProvider);
    for (final e in events) {
      if (e is LevelUp && n.levelUp) {
        svc.showEvent('Новый уровень: ${e.level}!', 'Награда: ${e.goldReward} Gold. Так держать.');
      } else if (e is QuestCompletedEvent && e.quest.type.isMission && n.missionComplete) {
        svc.showEvent('Миссия завершена', '${e.quest.title} · +${e.xp} XP');
      }
    }
  }

  void _rescheduleNotifications(GameState s) {
    if (!s.hasCharacter) return;
    unawaited(ref.read(notificationServiceProvider).reschedule(s).catchError((_) {}));
  }

  void _disposeRuntime() {
    _ticker?.cancel();
    _syncDebounce?.cancel();
    _retry?.cancel();
    _net?.cancel();
    _lifecycle?.dispose();
    _ticker = _syncDebounce = _retry = null;
    _net = null;
    _lifecycle = null;
    _sync = null;
    _lastPull = null;
  }
}
