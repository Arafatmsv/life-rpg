import 'dart:convert';
import 'dart:typed_data';

import 'package:share_plus/share_plus.dart';

import '../../data/models/game_state.dart';
import '../errors/game_exception.dart';
import '../utils/day.dart';
import '../utils/json.dart';

/// Exports all of the player's data as a single JSON document.
class ExportService {
  const ExportService();

  String buildJson(GameState s) {
    final doc = {
      'format': 'life-rpg-export',
      'version': 1,
      'exported_at': DateTime.now().toUtc().toIso8601String(),
      'tables': s.toTables()..remove(Tables.meta),
    };
    return const JsonEncoder.withIndent('  ').convert(doc);
  }

  /// Opens the system share sheet (on web: downloads the file).
  Future<void> share(GameState s) async {
    final bytes = Uint8List.fromList(utf8.encode(buildJson(s)));
    final name = 'life-rpg-${dayKeyOf(DateTime.now())}.json';
    await SharePlus.instance.share(ShareParams(
      files: [XFile.fromData(bytes, name: name, mimeType: 'application/json')],
      fileNameOverrides: [name],
      subject: 'Life RPG — экспорт данных',
    ));
  }

  /// Parses and validates a file produced by [buildJson]. Returns table rows
  /// ready for [GameState.fromTables].
  Map<String, Map<String, Json>> parse(String text) {
    final Object? raw;
    try {
      raw = jsonDecode(text);
    } catch (_) {
      throw const GameException('Файл повреждён или это не JSON');
    }
    final doc = asJson(raw);
    if (doc['format'] != 'life-rpg-export') {
      throw const GameException('Это не файл экспорта Life RPG');
    }
    if (asInt(doc['version']) > 1) {
      throw const GameException('Файл создан более новой версией приложения');
    }
    final tables = <String, Map<String, Json>>{};
    final src = asJson(doc['tables']);
    for (final t in Tables.all) {
      if (t == Tables.meta) continue;
      tables[t] = {for (final e in asJson(src[t]).entries) e.key: asJson(e.value)};
    }
    if ((tables[Tables.characters] ?? const {}).length != 1) {
      throw const GameException('В файле нет персонажа');
    }
    // Make sure every row can actually be read before replacing anything.
    try {
      GameState.fromTables(tables);
    } catch (_) {
      throw const GameException('Данные в файле повреждены');
    }
    return tables;
  }
}
