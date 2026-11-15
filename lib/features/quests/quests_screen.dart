import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_theme.dart';
import '../../app/theme/app_tokens.dart';
import '../../core/responsive/responsive.dart';
import '../../core/widgets/rpg_scaffold.dart';
import '../../core/widgets/states.dart';
import '../../core/game/game_engine.dart';
import '../../data/models/enums.dart';
import '../../data/models/game_state.dart';
import '../../data/models/quest.dart';
import '../game/game_controller.dart';
import 'quest_card.dart';
import 'quest_editor.dart';

enum _Tab {
  today('Сегодня'),
  missions('Миссии'),
  bosses('Испытания'),
  side('Побочные'),
  all('Все'),
  archive('Архив');

  const _Tab(this.label);
  final String label;
}

class QuestsScreen extends ConsumerWidget {
  const QuestsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(gameControllerProvider).valueOrNull;
    if (s == null) return const Scaffold(body: LoadingView());
    final e = ref.watch(engineProvider);
    return DefaultTabController(
      length: _Tab.values.length,
      child: RpgScaffold(
        appBar: AppBar(
          title: const Text('Задания'),
          bottom: TabBar(
            isScrollable: true,
            tabs: [
              for (final t in _Tab.values)
                Tab(
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Text(t.label),
                    if (t == _Tab.today) ...[
                      const SizedBox(width: 6),
                      _Counter(_list(t, s, e).where((q) => !e.isDoneThisPeriod(s, q)).length),
                    ],
                  ]),
                ),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => openQuestEditor(context),
          icon: const Icon(Icons.add_rounded),
          label: const Text('Задание'),
        ),
        body: TabBarView(
          children: [for (final t in _Tab.values) _QuestList(tab: t)],
        ),
      ),
    );
  }

  static List<Quest> _list(_Tab t, GameState s, GameEngine e) {
    final live = s.liveQuests.toList();
    int byDue(Quest a, Quest b) => (a.dueDay ?? '9999').compareTo(b.dueDay ?? '9999');
    List<Quest> sorted(Iterable<Quest> it) {
      final l = it.toList();
      // Pending first, then done; inside: by type and deadline.
      l.sort((a, b) {
        final da = e.isDoneThisPeriod(s, a) ? 1 : 0, db = e.isDoneThisPeriod(s, b) ? 1 : 0;
        if (da != db) return da - db;
        final t = a.type.index - b.type.index;
        return t != 0 ? t : byDue(a, b);
      });
      return l;
    }

    return switch (t) {
      _Tab.today => sorted(live.where((q) =>
          q.isOpen &&
          (q.periodKind != PeriodKind.once
              ? e.isDueToday(s, q)
              : (q.isRecovery || (q.dueDay != null && q.dueDay!.compareTo(e.today(s)) <= 0))))),
      _Tab.missions => sorted(live.where((q) => q.type == QuestType.main && q.isOpen)),
      _Tab.bosses => sorted(live.where((q) => q.type == QuestType.boss && q.isOpen)),
      _Tab.side => sorted(live.where((q) => q.type == QuestType.side && q.isOpen)),
      _Tab.all => sorted(live.where((q) => q.isOpen)),
      _Tab.archive => live.where((q) => !q.isOpen).toList()
        ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt)),
    };
  }
}

class _Counter extends StatelessWidget {
  const _Counter(this.n);
  final int n;

  @override
  Widget build(BuildContext context) => n == 0
      ? const Icon(Icons.check_circle_rounded, size: 16, color: AppColors.success)
      : Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary.o(0.18),
            borderRadius: BorderRadius.circular(99),
          ),
          child: Text('$n', style: AppText.number(11, color: Theme.of(context).colorScheme.primary)),
        );
}

class _QuestList extends ConsumerWidget {
  const _QuestList({required this.tab});
  final _Tab tab;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(gameControllerProvider).valueOrNull!;
    final e = ref.watch(engineProvider);
    final list = QuestsScreen._list(tab, s, e);
    if (list.isEmpty) {
      final (title, msg, type) = switch (tab) {
        _Tab.today => ('Свободный день', 'На сегодня заданий нет. Добавьте ежедневную привычку или просто отдохните.', QuestType.daily),
        _Tab.missions => ('Нет миссий', 'Миссия: большая цель вроде «выучить язык» или «сменить работу», разбитая на шаги.', QuestType.main),
        _Tab.bosses => ('Нет испытаний', 'Испытание: серия усилий на недели, например 30 дней английского или 20 тренировок.', QuestType.boss),
        _Tab.side => ('Нет побочных заданий', 'Небольшие необязательные задачи, которые дают дополнительный опыт.', QuestType.side),
        _Tab.all => ('Журнал пуст', 'Создайте первое задание.', QuestType.daily),
        _Tab.archive => ('Архив пуст', 'Здесь появятся выполненные, проваленные и архивные задания.', null),
      };
      return SingleChildScrollView(
        child: EmptyState(
          icon: Icons.assignment_outlined,
          title: title,
          message: msg,
          actionLabel: type == null ? null : 'Создать',
          onAction: type == null ? null : () => openQuestEditor(context, type: type),
        ),
      );
    }
    return AdaptiveBuilder(
      builder: (context, size, c) => ListView(
        padding: EdgeInsets.fromLTRB(size.gutter, Gap.md, size.gutter, 96 + MediaQuery.paddingOf(context).bottom),
        children: [
          ContentWidth(
            child: ResponsiveColumns(
              minItemWidth: 360,
              maxColumns: 2,
              spacing: Gap.sm,
              children: [for (final q in list) QuestCard(key: ValueKey(q.id), quest: q)],
            ),
          ),
        ],
      ),
    );
  }
}
