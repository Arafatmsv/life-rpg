import 'package:flutter_test/flutter_test.dart';
import 'package:life_rpg/core/errors/game_exception.dart';
import 'package:life_rpg/core/game/game_clock.dart';
import 'package:life_rpg/core/game/game_engine.dart';
import 'package:life_rpg/core/services/export_service.dart';
import 'package:life_rpg/data/models/enums.dart';
import 'package:life_rpg/data/models/game_state.dart';
import 'package:life_rpg/data/models/quest.dart';

void main() {
  const export = ExportService();
  final now = DateTime.utc(2026, 11, 10, 12);
  final engine = GameEngine(clock: GameClock(now: () => now));

  GameState played() {
    var s = engine
        .createCharacter(
          const GameState(),
          const CharacterDraft(
            name: 'Импорт',
            avatarId: 'sword',
            avatarColor: 1,
            characterClass: CharacterClass.scholar,
            focus: [],
            goals: ['цель'],
          ),
        )
        .state;
    s = engine
        .saveQuest(
          s,
          Quest(
            id: 'q',
            title: 'Читать',
            type: QuestType.side,
            attribute: AttributeType.intelligence,
            difficulty: Difficulty.normal,
            xpReward: 0,
            startDay: '2026-11-10',
            createdAt: now,
            updatedAt: now,
          ),
        )
        .state;
    return engine.completeQuest(s, 'q').state;
  }

  test('export → parse restores the same game', () {
    final s = played();
    final back = GameState.fromTables(export.parse(export.buildJson(s)));
    expect(back.character!.name, 'Импорт');
    expect(back.character!.id, s.character!.id);
    expect(back.quests['q']!.status, QuestStatus.completed);
    expect(engine.snapshot(back).level.totalXp, engine.snapshot(s).level.totalXp);
    expect(engine.snapshot(back).gold, engine.snapshot(s).gold);
    expect(back.achievements.keys, s.achievements.keys);
  });

  test('foreign or broken files are rejected', () {
    expect(() => export.parse('not json'), throwsA(isA<GameException>()));
    expect(() => export.parse('{"format":"other"}'), throwsA(isA<GameException>()));
    expect(
      () => export.parse('{"format":"life-rpg-export","version":1,"tables":{}}'),
      throwsA(isA<GameException>()),
    );
  });
}
