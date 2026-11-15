import 'dart:convert';

import 'package:hive_ce_flutter/hive_flutter.dart';

import '../../core/errors/game_exception.dart';
import '../../core/utils/json.dart';
import '../models/game_state.dart';

/// A queued change waiting to be pushed to the server.
class OutboxOp {
  const OutboxOp({
    required this.key,
    required this.table,
    required this.entityId,
    required this.data,
    required this.createdAt,
    this.attempts = 0,
    this.lastError,
    this.dead = false,
  });

  /// Sortable key that preserves enqueue order.
  final String key;
  final String table;
  final String entityId;
  final Json data;
  final DateTime createdAt;
  final int attempts;
  final String? lastError;

  /// Rejected by the server's validation; kept for inspection, not retried.
  final bool dead;

  bool get isDelete => data['_deleted'] == true;

  OutboxOp failed(String error, {bool dead = false}) => OutboxOp(
        key: key,
        table: table,
        entityId: entityId,
        data: data,
        createdAt: createdAt,
        attempts: attempts + 1,
        lastError: error,
        dead: dead,
      );

  Json toJson() => {
        'key': key,
        'table': table,
        'entity_id': entityId,
        'data': data,
        'created_at': iso(createdAt),
        'attempts': attempts,
        'last_error': lastError,
        'dead': dead,
      };

  factory OutboxOp.fromJson(Json j) => OutboxOp(
        key: asString(j['key']),
        table: asString(j['table']),
        entityId: asString(j['entity_id']),
        data: asJson(j['data']),
        createdAt: parseDateOr(j['created_at'], DateTime.now()),
        attempts: asInt(j['attempts']),
        lastError: j['last_error'] as String?,
        dead: asBool(j['dead']),
      );
}

/// Hive-backed storage of one player namespace (a signed-in user id or
/// "guest"). Every table is a box of JSON strings keyed by entity id.
class LocalGameStore {
  LocalGameStore._(this.namespace, this._boxes, this._outbox);

  final String namespace;
  final Map<String, Box<String>> _boxes;
  final Box<String> _outbox;
  int _seq = 0;

  static Future<void> initialize() => Hive.initFlutter('life_rpg');

  static String _boxName(String ns, String table) =>
      '${ns.replaceAll('-', '')}_$table'.toLowerCase();

  static Future<LocalGameStore> open(String namespace) async {
    try {
      final boxes = <String, Box<String>>{};
      for (final t in Tables.all) {
        boxes[t] = await Hive.openBox<String>(_boxName(namespace, t));
      }
      final outbox = await Hive.openBox<String>(_boxName(namespace, 'outbox'));
      final store = LocalGameStore._(namespace, boxes, outbox);
      store._seq = outbox.length;
      return store;
    } catch (e) {
      throw AppException('Не удалось открыть локальное хранилище', e);
    }
  }

  /// Whether a namespace has a created character (used for guest → account
  /// migration).
  static Future<bool> hasCharacter(String namespace) async {
    final box = await Hive.openBox<String>(_boxName(namespace, Tables.characters));
    return box.isNotEmpty;
  }

  Map<String, Map<String, Json>> readAll() {
    final out = <String, Map<String, Json>>{};
    for (final e in _boxes.entries) {
      final rows = <String, Json>{};
      for (final k in e.value.keys) {
        final raw = e.value.get(k);
        if (raw == null) continue;
        try {
          rows[k.toString()] = asJson(jsonDecode(raw));
        } catch (_) {
          // A corrupted row must not prevent the game from loading.
        }
      }
      out[e.key] = rows;
    }
    return out;
  }

  GameState load() => GameState.fromTables(readAll());

  Future<void> apply(Iterable<EntityChange> changes) async {
    for (final c in changes) {
      final box = _boxes[c.table];
      if (box == null) continue;
      if (c.data['_deleted'] == true) {
        await box.delete(c.id);
      } else {
        await box.put(c.id, jsonEncode(c.data));
      }
    }
  }

  /// Replaces all tables (server pull / guest migration). Meta is preserved.
  Future<void> replaceAll(Map<String, Map<String, Json>> tables) async {
    for (final t in Tables.all) {
      if (t == Tables.meta) continue;
      final box = _boxes[t]!;
      await box.clear();
      final rows = tables[t];
      if (rows == null) continue;
      await box.putAll({for (final e in rows.entries) e.key: jsonEncode(e.value)});
    }
  }

  // ───────────── outbox ─────────────

  List<OutboxOp> get pending => _outbox.keys
      .map((k) => _outbox.get(k))
      .whereType<String>()
      .map((s) => OutboxOp.fromJson(asJson(jsonDecode(s))))
      .toList()
    ..sort((a, b) => a.key.compareTo(b.key));

  int get pendingCount => pending.where((o) => !o.dead).length;

  /// Queues changes. For mutable tables only the latest version of an
  /// entity is kept; ledger rows are always queued individually.
  Future<void> enqueue(Iterable<EntityChange> changes) async {
    final existing = pending;
    for (final c in changes) {
      if (c.table == Tables.meta) continue;
      if (!Tables.ledger.contains(c.table)) {
        for (final o in existing) {
          if (o.table == c.table && o.entityId == c.id && !o.dead) {
            await _outbox.delete(o.key);
          }
        }
      }
      final key = '${DateTime.now().microsecondsSinceEpoch.toString().padLeft(20, '0')}'
          '_${(_seq++).toString().padLeft(8, '0')}';
      final op = OutboxOp(
        key: key,
        table: c.table,
        entityId: c.id,
        data: c.data,
        createdAt: DateTime.now(),
      );
      await _outbox.put(key, jsonEncode(op.toJson()));
    }
  }

  Future<void> remove(OutboxOp op) => _outbox.delete(op.key);

  Future<void> update(OutboxOp op) => _outbox.put(op.key, jsonEncode(op.toJson()));

  /// Wipes everything of this namespace (account deletion / reset).
  Future<void> clear() async {
    for (final b in _boxes.values) {
      await b.clear();
    }
    await _outbox.clear();
  }
}
