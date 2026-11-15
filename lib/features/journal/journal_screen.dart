import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_theme.dart';
import '../../app/theme/app_tokens.dart';
import '../../core/responsive/responsive.dart';
import '../../core/utils/day.dart';
import '../../core/widgets/rpg_scaffold.dart';
import '../../core/widgets/rpg_card.dart';
import '../../core/widgets/states.dart';
import '../game/game_controller.dart';

/// Day ratings are shown as plain numbers; colour is not used for mood.
Color ratingColor(int r) => AppColors.textSecondary;

class JournalScreen extends ConsumerStatefulWidget {
  const JournalScreen({super.key});

  @override
  ConsumerState<JournalScreen> createState() => _JournalScreenState();
}

class _JournalScreenState extends ConsumerState<JournalScreen> {
  final _search = TextEditingController();
  var _q = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _pickDay() async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: now.subtract(const Duration(days: 365 * 3)),
      lastDate: now,
      helpText: 'Запись за день',
    );
    if (d != null && mounted) context.push('/profile/journal/${dayKeyOf(d)}');
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(gameControllerProvider).valueOrNull;
    final snap = ref.watch(snapshotProvider);
    if (s == null || snap == null) return const Scaffold(body: LoadingView());
    final q = _q.trim().toLowerCase();
    final entries = s.journal.values
        .where((e) => !e.deleted && !e.isEmpty)
        .where((e) => q.isEmpty || e.searchable.contains(q) || humanDayYear(e.dayKey).contains(q))
        .toList()
      ..sort((a, b) => b.dayKey.compareTo(a.dayKey));
    final hasToday = s.journal.values.any((e) => e.dayKey == snap.today && !e.deleted && !e.isEmpty);
    final rated = entries.where((e) => e.rating != null).toList();
    final avg = rated.isEmpty ? null : rated.fold<int>(0, (a, e) => a + e.rating!) / rated.length;

    return RpgScaffold(
      appBar: AppBar(
        title: const Text('Дневник'),
        actions: [
          IconButton(tooltip: 'Запись за другой день', onPressed: _pickDay, icon: const Icon(Icons.calendar_month_rounded)),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/profile/journal/${snap.today}'),
        icon: Icon(hasToday ? Icons.edit_rounded : Icons.edit_note_rounded),
        label: Text(hasToday ? 'Сегодня' : 'Записать день'),
      ),
      body: AdaptiveBuilder(builder: (context, size, c) => ListView(
            padding: EdgeInsets.fromLTRB(size.gutter, Gap.xs, size.gutter, 96),
            children: [
              ContentWidth(
                maxWidth: 820,
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Row(children: [
                    const Icon(Icons.lock_rounded, size: 14, color: AppColors.textMuted),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Дневник приватный: записи видите только вы'
                        '${avg == null ? '' : ' · средняя оценка дня ${avg.toStringAsFixed(1)}'}',
                        style: AppText.ui(12, color: AppColors.textMuted),
                      ),
                    ),
                  ]),
                  const SizedBox(height: Gap.sm),
                  TextField(
                    controller: _search,
                    onChanged: (v) => setState(() => _q = v),
                    decoration: InputDecoration(
                      hintText: 'Поиск по записям',
                      prefixIcon: const Icon(Icons.search_rounded),
                      suffixIcon: _q.isEmpty
                          ? null
                          : IconButton(
                              tooltip: 'Очистить',
                              onPressed: () => setState(() {
                                _search.clear();
                                _q = '';
                              }),
                              icon: const Icon(Icons.close_rounded),
                            ),
                    ),
                  ),
                  const SizedBox(height: Gap.md),
                  if (entries.isEmpty)
                    EmptyState(
                      icon: Icons.menu_book_rounded,
                      title: q.isEmpty ? 'Первая страница' : 'Ничего не найдено',
                      message: q.isEmpty
                          ? 'Пара минут рефлексии в конце дня помогает видеть, что работает, а что нет.'
                          : 'Попробуйте другой запрос.',
                    ),
                  for (final e in entries) ...[
                    RpgCard(
                      onTap: () => context.push('/profile/journal/${e.dayKey}'),
                      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Container(
                          width: 46,
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          decoration: BoxDecoration(
                            color: AppColors.surface2,
                            borderRadius: Radii.rSm,
                            border: Border.all(color: AppColors.borderSoft),
                          ),
                          child: Column(children: [
                            Text('${parseDayKey(e.dayKey).day}', style: AppText.number(18)),
                            Text(monthShort[parseDayKey(e.dayKey).month - 1], style: AppText.ui(10.5, color: AppColors.textMuted)),
                          ]),
                        ),
                        const SizedBox(width: Gap.md),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(
                              '${weekdayFull[weekdayOf(e.dayKey) - 1]}, ${humanDayYear(e.dayKey)}',
                              style: AppText.ui(13, weight: FontWeight.w700, color: AppColors.textSecondary),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              [e.wins, e.dayNotes, e.learned, e.fails, e.improve, e.tomorrow]
                                  .firstWhere((t) => t.trim().isNotEmpty, orElse: () => 'Оценка дня без заметок'),
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style: AppText.ui(14, height: 1.4),
                            ),
                          ]),
                        ),
                        if (e.rating != null) ...[
                          const SizedBox(width: Gap.sm),
                          Text('${e.rating}/10', style: AppText.number(13, color: AppColors.textSecondary)),
                        ],
                      ]),
                    ),
                    const SizedBox(height: Gap.xs),
                  ],
                ]),
              ),
            ],
          )),
    );
  }
}
