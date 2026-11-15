import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_theme.dart';
import '../../app/theme/app_tokens.dart';
import '../../core/responsive/responsive.dart';
import '../../core/utils/day.dart';
import '../../core/widgets/buttons.dart';
import '../../core/widgets/feedback.dart';
import '../../core/widgets/states.dart';
import '../../data/models/journal_entry.dart';
import '../game/game_controller.dart';
import 'journal_screen.dart';

class JournalEditorScreen extends ConsumerStatefulWidget {
  const JournalEditorScreen({super.key, required this.dayKey});
  final String dayKey;

  @override
  ConsumerState<JournalEditorScreen> createState() => _JournalEditorScreenState();
}

class _JournalEditorScreenState extends ConsumerState<JournalEditorScreen> {
  static const _fields = [
    ('wins', 'Что сегодня получилось', Icons.emoji_events_outlined),
    ('fails', 'Что не получилось', Icons.cloud_outlined),
    ('learned', 'Чему научился', Icons.lightbulb_outline_rounded),
    ('improve', 'Что нужно улучшить', Icons.trending_up_rounded),
    ('dayNotes', 'Как прошёл день', Icons.wb_twilight_rounded),
    ('tomorrow', 'План на завтра', Icons.event_note_rounded),
  ];

  late final Map<String, TextEditingController> _c;
  JournalEntry? _existing;
  int? _rating;
  var _dirty = false;
  var _busy = false;

  @override
  void initState() {
    super.initState();
    final s = ref.read(gameControllerProvider).valueOrNull!;
    final id = ref.read(engineProvider).journalIdFor(s, widget.dayKey);
    final e = s.journal[id];
    _existing = (e != null && !e.deleted) ? e : null;
    _rating = _existing?.rating;
    String v(String k) => switch (k) {
          'wins' => _existing?.wins ?? '',
          'fails' => _existing?.fails ?? '',
          'learned' => _existing?.learned ?? '',
          'improve' => _existing?.improve ?? '',
          'dayNotes' => _existing?.dayNotes ?? '',
          _ => _existing?.tomorrow ?? '',
        };
    _c = {
      for (final f in _fields)
        f.$1: TextEditingController(text: v(f.$1))..addListener(() => _dirty = true),
    };
  }

  @override
  void dispose() {
    for (final c in _c.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final s = ref.read(gameControllerProvider).valueOrNull!;
    final engine = ref.read(engineProvider);
    final now = DateTime.now();
    final base = _existing ??
        JournalEntry(
          id: engine.journalIdFor(s, widget.dayKey),
          dayKey: widget.dayKey,
          createdAt: now,
          updatedAt: now,
        );
    final entry = base.copyWith(
      wins: _c['wins']!.text.trim(),
      fails: _c['fails']!.text.trim(),
      learned: _c['learned']!.text.trim(),
      improve: _c['improve']!.text.trim(),
      dayNotes: _c['dayNotes']!.text.trim(),
      tomorrow: _c['tomorrow']!.text.trim(),
      rating: () => _rating,
      deleted: false,
    );
    if (entry.isEmpty) {
      showMessage(context, 'Запишите хоть что-нибудь или поставьте оценку дня', error: true);
      return;
    }
    setState(() => _busy = true);
    final ok = await runGameAction(context, ref, (e, st) => e.saveJournal(st, entry), success: 'Запись сохранена');
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) {
      _dirty = false;
      context.pop();
    }
  }

  Future<void> _delete() async {
    final ex = _existing;
    if (ex == null) return;
    final ok = await confirm(context,
        title: 'Удалить запись?',
        message: 'Запись за ${humanDayYear(widget.dayKey)} будет удалена.',
        confirmLabel: 'Удалить',
        destructive: true);
    if (!ok || !mounted) return;
    final done = await runGameAction(context, ref, (e, st) => e.deleteJournal(st, ex.id), success: 'Запись удалена');
    if (done && mounted) {
      _dirty = false;
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (ref.watch(gameControllerProvider).valueOrNull == null) return const Scaffold(body: LoadingView());
    final wd = weekdayFull[weekdayOf(widget.dayKey) - 1];
    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final leave = await confirm(context,
            title: 'Выйти без сохранения?', message: 'Изменения в записи будут потеряны.', confirmLabel: 'Выйти', destructive: true);
        if (leave && context.mounted) {
          _dirty = false;
          context.pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(humanDay(widget.dayKey)),
          actions: [
            if (_existing != null)
              IconButton(tooltip: 'Удалить запись', onPressed: _delete, icon: const Icon(Icons.delete_outline_rounded)),
          ],
        ),
        body: AdaptiveBuilder(builder: (context, size, c) => ListView(
              padding: EdgeInsets.fromLTRB(size.gutter, Gap.xs, size.gutter, Gap.xxl),
              children: [
                ContentWidth(
                  maxWidth: 720,
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    Text('$wd, ${humanDayYear(widget.dayKey)}', style: AppText.display(26)),
                    const SizedBox(height: Gap.lg),
                    Text('ОЦЕНКА ДНЯ', style: AppText.label()),
                    const SizedBox(height: Gap.xs),
                    Wrap(spacing: 6, runSpacing: 6, children: [
                      for (var r = 1; r <= 10; r++)
                        ChoiceChipX(
                          label: '$r',
                          color: ratingColor(r),
                          selected: _rating == r,
                          onTap: () => setState(() {
                            _rating = _rating == r ? null : r;
                            _dirty = true;
                          }),
                        ),
                    ]),
                    const SizedBox(height: Gap.lg),
                    for (final f in _fields) ...[
                      TextField(
                        controller: _c[f.$1],
                        minLines: 2,
                        maxLines: 6,
                        maxLength: 2000,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: InputDecoration(
                          labelText: f.$2,
                          alignLabelWithHint: true,
                          prefixIcon: Icon(f.$3),
                          counterText: '',
                        ),
                      ),
                      const SizedBox(height: Gap.sm),
                    ],
                    const SizedBox(height: Gap.md),
                    RpgButton(label: 'Сохранить', icon: Icons.check_rounded, expand: true, loading: _busy, onPressed: _save),
                    const SizedBox(height: Gap.xs),
                    Text('Запись видна только вам.', textAlign: TextAlign.center, style: AppText.ui(12, color: AppColors.textMuted)),
                  ]),
                ),
              ],
            )),
      ),
    );
  }
}
