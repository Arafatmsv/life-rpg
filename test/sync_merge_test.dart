import 'package:flutter_test/flutter_test.dart';
import 'package:life_rpg/data/models/game_state.dart';
import 'package:life_rpg/data/repositories/sync_service.dart';

void main() {
  Map<String, Map<String, Map<String, dynamic>>> tables(
    Map<String, Map<String, Map<String, dynamic>>> t,
  ) =>
      {for (final name in Tables.all) name: t[name] ?? {}};

  test('mutable rows: newer updated_at wins on either side', () {
    final merged = mergeTables(
      local: tables({
        Tables.quests: {
          'a': {'id': 'a', 'title': 'local newer', 'updated_at': '2026-11-13T12:00:00Z'},
          'b': {'id': 'b', 'title': 'local older', 'updated_at': '2026-11-13T08:00:00Z'},
        },
      }),
      server: tables({
        Tables.quests: {
          'a': {'id': 'a', 'title': 'server older', 'updated_at': '2026-11-13T10:00:00Z'},
          'b': {'id': 'b', 'title': 'server newer', 'updated_at': '2026-11-13T09:00:00Z'},
        },
      }),
      pendingKeys: const {},
    );
    expect(merged[Tables.quests]!['a']!['title'], 'local newer');
    expect(merged[Tables.quests]!['b']!['title'], 'server newer');
  });

  test('pending local change always survives a pull', () {
    final merged = mergeTables(
      local: tables({
        Tables.quests: {
          'a': {'id': 'a', 'title': 'edited offline', 'updated_at': '2026-11-13T08:00:00Z'},
        },
      }),
      server: tables({
        Tables.quests: {
          'a': {'id': 'a', 'title': 'server', 'updated_at': '2026-11-13T09:00:00Z'},
        },
      }),
      pendingKeys: const {'quests/a'},
    );
    expect(merged[Tables.quests]!['a']!['title'], 'edited offline');
  });

  test('ledger is a union; same deterministic id collapses to one row', () {
    final merged = mergeTables(
      local: tables({
        Tables.xp: {
          'level-reward-2': {'id': 'level-reward-2', 'amount': 70},
          'local-only': {'id': 'local-only', 'amount': 20},
        },
      }),
      server: tables({
        Tables.xp: {
          'level-reward-2': {'id': 'level-reward-2', 'amount': 70},
          'other-device': {'id': 'other-device', 'amount': 40},
        },
      }),
      pendingKeys: const {},
    );
    final xp = merged[Tables.xp]!;
    expect(xp.keys, containsAll(['level-reward-2', 'local-only', 'other-device']));
    expect(xp.values.fold<int>(0, (s, r) => s + (r['amount'] as int)), 130);
  });

  test('a revert made on this device is not lost to an older server copy', () {
    final merged = mergeTables(
      local: tables({
        Tables.completions: {
          'c': {'id': 'c', 'reverted_at': '2026-11-13T10:00:00Z'},
        },
      }),
      server: tables({
        Tables.completions: {
          'c': {'id': 'c', 'reverted_at': null},
        },
      }),
      pendingKeys: const {},
    );
    expect(merged[Tables.completions]!['c']!['reverted_at'], isNotNull);
  });

  test('mutable row deleted on another device disappears; meta stays local', () {
    final merged = mergeTables(
      local: tables({
        Tables.dayMarks: {
          '2026-11-10': {'day_key': '2026-11-10', 'kind': 'rest'},
        },
        Tables.meta: {
          'state': {'last_evaluated_day': '2026-11-12'},
        },
      }),
      server: tables({}),
      pendingKeys: const {},
    );
    expect(merged[Tables.dayMarks], isEmpty);
    expect(merged[Tables.meta]!['state']!['last_evaluated_day'], '2026-11-12');
  });
}
