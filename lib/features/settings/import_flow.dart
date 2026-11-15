import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/errors/game_exception.dart';
import '../../core/widgets/feedback.dart';
import '../game/game_controller.dart';

/// Picks an export file and replaces the local game with it. Used from
/// settings and from onboarding (restoring progress on a new install).
Future<void> importProgressFromFile(BuildContext context, WidgetRef ref) async {
  // Any file type: Safari on iOS may grey out .json files behind an
  // extension filter. The content is validated by ExportService.parse.
  final picked = await FilePicker.pickFiles(withData: true);
  final bytes = picked?.files.firstOrNull?.bytes;
  if (bytes == null || !context.mounted) return;
  final Map<String, Map<String, Map<String, dynamic>>> tables;
  try {
    tables = ref.read(exportServiceProvider).parse(utf8.decode(bytes, allowMalformed: true));
  } catch (e) {
    showMessage(context, describeError(e), error: true);
    return;
  }
  final ch = tables['characters']!.values.first;
  final ok = await confirm(context,
      title: 'Заменить прогресс?',
      message: 'Будет загружен персонаж «${ch['name']}» из файла. Текущий прогресс на этом устройстве '
          'будет заменён. Если он нужен — сначала сделайте экспорт.',
      confirmLabel: 'Импортировать',
      destructive: true);
  if (!ok || !context.mounted) return;
  final err = await ref.read(gameControllerProvider.notifier).importTables(tables);
  if (!context.mounted) return;
  showMessage(context, err ?? 'Прогресс загружен', error: err != null);
}
