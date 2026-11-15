import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/utils/json.dart';
import '../models/game_state.dart';
import 'local_game_store.dart';

/// Thrown when the server rejected a row on purpose (validation). Such ops
/// are not retried.
class RejectedByServer implements Exception {
  const RejectedByServer(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Talks to Supabase. Mutable tables are written directly (RLS limits rows
/// to the owner); ledger tables go through `sync_ledger`, a security-definer
/// function that validates amounts, uniqueness and balances server-side.
class RemoteGameSource {
  RemoteGameSource(this._client);

  final SupabaseClient _client;

  String get _uid {
    final id = _client.auth.currentUser?.id;
    if (id == null) throw const AuthException('Нет активной сессии');
    return id;
  }

  /// Primary-key column of each directly written table.
  static const _keyColumn = {
    Tables.characters: 'id',
    Tables.settings: 'user_id',
    Tables.quests: 'id',
    Tables.progress: 'id',
    Tables.penalties: 'id',
    Tables.rewards: 'id',
    Tables.journal: 'id',
    Tables.skills: 'skill_id',
    Tables.dayMarks: 'day_key',
  };

  Future<void> push(OutboxOp op) async {
    try {
      if (Tables.ledger.contains(op.table)) {
        await _client.rpc('sync_ledger', params: {'p_table': op.table, 'p_row': op.data});
        return;
      }
      final uid = _uid;
      if (op.table == Tables.settings) {
        await _client.from(Tables.settings).upsert({
          'user_id': uid,
          'data': op.data,
          'updated_at': op.data['updated_at'] ?? DateTime.now().toUtc().toIso8601String(),
        });
        return;
      }
      final key = _keyColumn[op.table];
      if (key == null) return;
      if (op.isDelete) {
        await _client.from(op.table).delete().eq('user_id', uid).eq(key, op.entityId);
        return;
      }
      final row = Map<String, dynamic>.from(op.data)..['user_id'] = uid;
      await _client
          .from(op.table)
          .upsert(row, onConflict: key == 'id' ? 'id' : 'user_id,$key');
    } on PostgrestException catch (e) {
      // P0001 = raise exception in our SQL validation; 23xxx = constraint.
      final code = e.code ?? '';
      if (code == 'P0001' || code.startsWith('23') || code == '42501') {
        throw RejectedByServer(e.message);
      }
      rethrow;
    }
  }

  /// Downloads every row of the current user.
  Future<Map<String, Map<String, Json>>> pullAll() async {
    final out = <String, Map<String, Json>>{};
    for (final t in Tables.all) {
      if (t == Tables.meta) continue;
      final rows = await _fetchAll(t);
      final map = <String, Json>{};
      for (final r in rows) {
        final row = Map<String, dynamic>.from(r)..remove('user_id');
        if (t == Tables.settings) {
          map['settings'] = asJson(row['data']);
          continue;
        }
        final id = switch (t) {
          Tables.skills => row['skill_id'],
          Tables.achievements => row['achievement_id'],
          Tables.dayMarks => row['day_key'],
          _ => row['id'],
        };
        map[id.toString()] = row;
      }
      out[t] = map;
    }
    return out;
  }

  Future<List<Map<String, dynamic>>> _fetchAll(String table) async {
    const page = 1000;
    final all = <Map<String, dynamic>>[];
    var from = 0;
    while (true) {
      final batch = await _client.from(table).select().range(from, from + page - 1);
      all.addAll(batch);
      if (batch.length < page) break;
      from += page;
    }
    return all;
  }

  Future<void> deleteAccount() => _client.rpc('delete_my_account');
}
