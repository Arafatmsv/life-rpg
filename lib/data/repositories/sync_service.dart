import 'dart:async';

import '../../core/utils/json.dart';
import '../datasources/local_game_store.dart';
import '../datasources/remote_game_source.dart';
import '../models/game_state.dart';

enum SyncPhase {
  localOnly('Только на устройстве'),
  idle('Синхронизировано'),
  syncing('Синхронизация…'),
  offline('Нет сети — изменения сохранены'),
  error('Ошибка синхронизации');

  const SyncPhase(this.label);
  final String label;
}

class SyncStatus {
  const SyncStatus({
    required this.phase,
    this.pending = 0,
    this.rejected = 0,
    this.lastSyncedAt,
    this.message,
  });

  const SyncStatus.localOnly() : this(phase: SyncPhase.localOnly);

  final SyncPhase phase;
  final int pending;
  final int rejected;
  final DateTime? lastSyncedAt;
  final String? message;

  SyncStatus copyWith({
    SyncPhase? phase,
    int? pending,
    int? rejected,
    DateTime? lastSyncedAt,
    String? message,
  }) =>
      SyncStatus(
        phase: phase ?? this.phase,
        pending: pending ?? this.pending,
        rejected: rejected ?? this.rejected,
        lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
        message: message,
      );
}

/// Merges server rows into local rows.
///
/// * Rows with a pending (or rejected) local op always keep the local version
///   — the op will be (or was) pushed.
/// * Mutable rows: last write wins by `updated_at`.
/// * Ledger rows are immutable and identified by deterministic ids, so the
///   union of both sides is correct and duplicates collapse.
/// * A mutable row that is missing on the server and not pending was deleted
///   on another device.
Map<String, Map<String, Json>> mergeTables({
  required Map<String, Map<String, Json>> local,
  required Map<String, Map<String, Json>> server,
  required Set<String> pendingKeys,
}) {
  final out = <String, Map<String, Json>>{};
  for (final table in Tables.all) {
    if (table == Tables.meta) {
      out[table] = local[table] ?? {};
      continue;
    }
    final l = local[table] ?? const {};
    final s = server[table] ?? const {};
    final merged = <String, Json>{...s};
    for (final e in l.entries) {
      final key = '$table/${e.key}';
      final remote = s[e.key];
      if (pendingKeys.contains(key)) {
        merged[e.key] = e.value;
      } else if (remote == null) {
        if (Tables.ledger.contains(table)) merged[e.key] = e.value;
      } else if (!Tables.ledger.contains(table)) {
        final lu = parseDate(e.value['updated_at']);
        final ru = parseDate(remote['updated_at']);
        if (lu != null && (ru == null || lu.isAfter(ru))) merged[e.key] = e.value;
      } else if (table == Tables.completions || table == Tables.purchases) {
        // The only allowed ledger mutation: reverted/refunded timestamps.
        final flag = table == Tables.completions ? 'reverted_at' : 'refunded_at';
        if (e.value[flag] != null && remote[flag] == null) merged[e.key] = e.value;
      }
    }
    out[table] = merged;
  }
  return out;
}

/// Pushes the outbox and pulls server state. Network failures leave the
/// outbox intact and are retried with backoff; validation rejections are
/// parked so one bad row cannot block the queue.
class SyncService {
  SyncService({required this.store, required this.remote});

  final LocalGameStore store;
  final RemoteGameSource remote;
  bool _running = false;

  bool get isRunning => _running;

  /// Returns merged tables when the pull changed something, otherwise null.
  Future<SyncResult> run({bool pull = true}) async {
    if (_running) return const SyncResult.skipped();
    _running = true;
    var rejected = 0;
    try {
      for (final op in store.pending) {
        if (op.dead) {
          rejected++;
          continue;
        }
        try {
          await remote.push(op);
          await store.remove(op);
        } on RejectedByServer catch (e) {
          rejected++;
          await store.update(op.failed(e.message, dead: true));
        }
      }
      Map<String, Map<String, Json>>? merged;
      if (pull) {
        final server = await remote.pullAll();
        final pendingKeys = {for (final o in store.pending) '${o.table}/${o.entityId}'};
        merged = mergeTables(local: store.readAll(), server: server, pendingKeys: pendingKeys);
        await store.replaceAll(merged);
      }
      return SyncResult(merged: merged, rejected: rejected);
    } finally {
      _running = false;
    }
  }
}

class SyncResult {
  const SyncResult({this.merged, this.rejected = 0, this.skipped = false});
  const SyncResult.skipped() : this(skipped: true);

  final Map<String, Map<String, Json>>? merged;
  final int rejected;
  final bool skipped;
}
