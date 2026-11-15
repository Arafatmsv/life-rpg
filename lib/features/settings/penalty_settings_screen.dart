import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_theme.dart';
import '../../app/theme/app_tokens.dart';
import '../../core/responsive/responsive.dart';
import '../../core/widgets/buttons.dart';
import '../../core/widgets/feedback.dart';
import '../../core/widgets/states.dart';
import '../../data/models/enums.dart';
import '../../data/models/user_settings.dart';
import '../game/game_controller.dart';
import 'settings_widgets.dart';

class PenaltySettingsScreen extends ConsumerWidget {
  const PenaltySettingsScreen({super.key});

  Future<void> _set(BuildContext context, WidgetRef ref, UserSettings Function(UserSettings) f) =>
      runGameAction(context, ref, (e, s) => e.updateSettings(s, f));

  Widget _stepper(BuildContext context, WidgetRef ref, int value, int min, int max, UserSettings Function(UserSettings, int) f) =>
      Row(mainAxisSize: MainAxisSize.min, children: [
        IconButton(
          tooltip: 'Меньше',
          onPressed: value > min ? () => _set(context, ref, (x) => f(x, value - 1)) : null,
          icon: const Icon(Icons.remove_rounded),
        ),
        SizedBox(width: 24, child: Text('$value', textAlign: TextAlign.center, style: AppText.number(15))),
        IconButton(
          tooltip: 'Больше',
          onPressed: value < max ? () => _set(context, ref, (x) => f(x, value + 1)) : null,
          icon: const Icon(Icons.add_rounded),
        ),
      ]);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(gameControllerProvider).valueOrNull;
    if (s == null) return const Scaffold(body: LoadingView());
    final st = s.settings;
    final cfg = ref.watch(engineProvider).config;
    final on = st.penaltiesEnabled;

    return Scaffold(
      appBar: AppBar(title: const Text('Последствия')),
      body: AdaptiveBuilder(builder: (context, size, c) => ListView(
            padding: EdgeInsets.fromLTRB(size.gutter, Gap.xs, size.gutter, Gap.xxl + MediaQuery.paddingOf(context).bottom),
            children: [
              ContentWidth(
                maxWidth: 760,
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: Gap.lg),
                    child: Text(
                      'Последствия только игровые: отметка в журнале, потеря бонуса серии, восстановительное задание. '
                      'Никаких реальных наказаний. Пропуск одного дня не уничтожает накопленный прогресс.',
                      style: AppText.ui(13.5, color: AppColors.textSecondary, height: 1.5),
                    ),
                  ),
                  SettingsGroup(title: 'Основное', children: [
                    SwitchListTile(
                      title: const Text('Последствия включены'),
                      value: on,
                      onChanged: (v) => _set(context, ref, (x) => x.copyWith(penaltiesEnabled: v)),
                    ),
                    SwitchListTile(
                      title: const Text('За пропущенные задания'),
                      value: st.missedQuestPenalty,
                      onChanged: on ? (v) => _set(context, ref, (x) => x.copyWith(missedQuestPenalty: v)) : null,
                    ),
                    SwitchListTile(
                      title: const Text('За прерванную серию'),
                      subtitle: const Text('Лёгкая отметка, если серия от 3 дней прервалась'),
                      value: st.streakBreakPenalty,
                      onChanged: on ? (v) => _set(context, ref, (x) => x.copyWith(streakBreakPenalty: v)) : null,
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(Gap.md, Gap.xs, Gap.md, Gap.md),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('Строгость', style: AppText.ui(15, weight: FontWeight.w600)),
                        const SizedBox(height: 2),
                        Text('Мягкая снижает уровень последствий на ступень, строгая повышает',
                            style: AppText.ui(12.5, color: AppColors.textMuted)),
                        const SizedBox(height: Gap.xs),
                        Wrap(spacing: 8, children: [
                          for (final v in Strictness.values)
                            ChoiceChipX(
                              label: v.label,
                              selected: st.strictness == v,
                              onTap: () => _set(context, ref, (x) => x.copyWith(strictness: v)),
                            ),
                        ]),
                      ]),
                    ),
                  ]),
                  SettingsGroup(
                    title: 'Последствия по типам заданий',
                    footer: 'Лёгкое: отметка и потеря бонуса серии на день. Среднее: бонус серии на 3 дня и '
                        'восстановительное задание. Серьёзное: провал миссии, восстановительное задание и потеря Gold, если она включена.',
                    children: [
                      for (final t in QuestType.values)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: Gap.md, vertical: Gap.xs),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(t.label, style: AppText.ui(14, weight: FontWeight.w700)),
                            const SizedBox(height: 6),
                            Wrap(spacing: 6, runSpacing: 6, children: [
                              for (final c in Consequence.values)
                                ChoiceChipX(
                                  label: c.label,
                                  selected: st.consequenceFor(t) == c,
                                  color: c.severity == null ? AppColors.textSecondary : AppColors.severity(c.severity!),
                                  onTap: () => _set(context, ref, (x) => x.copyWith(consequences: {...x.consequences, t: c})),
                                ),
                            ]),
                          ]),
                        ),
                    ],
                  ),
                  SettingsGroup(
                    title: 'Потери (по желанию)',
                    footer: 'Выключено по умолчанию. XP никогда не опускается ниже начала текущего уровня.',
                    children: [
                      SwitchListTile(
                        title: const Text('Потеря Gold при серьёзном нарушении'),
                        subtitle: Text('${(cfg.goldPenaltyShare * 100).round()}% баланса, не больше ${cfg.goldPenaltyMax}'),
                        value: st.goldPenaltyEnabled,
                        onChanged: on ? (v) => _set(context, ref, (x) => x.copyWith(goldPenaltyEnabled: v)) : null,
                      ),
                      SwitchListTile(
                        title: const Text('Небольшая потеря XP'),
                        subtitle: Text('${cfg.xpPenalty[Severity.light]} / ${cfg.xpPenalty[Severity.medium]} / '
                            '${cfg.xpPenalty[Severity.severe]} XP по уровню нарушения'),
                        value: st.xpPenaltyEnabled,
                        onChanged: on ? (v) => _set(context, ref, (x) => x.copyWith(xpPenaltyEnabled: v)) : null,
                      ),
                    ],
                  ),
                  SettingsGroup(title: 'Восстановление', children: [
                    SwitchListTile(
                      title: const Text('Восстановительные задания'),
                      subtitle: const Text('Небольшой шаг, который закрывает нарушение'),
                      value: st.allowRecovery,
                      onChanged: (v) => _set(context, ref, (x) => x.copyWith(allowRecovery: v)),
                    ),
                    ListTile(
                      title: const Text('Уважительные причины в месяц'),
                      subtitle: const Text('Закрывают нарушение и возвращают потери'),
                      trailing: _stepper(context, ref, st.recoveryDaysPerMonth, 0, 31,
                          (x, v) => x.copyWith(recoveryDaysPerMonth: v)),
                    ),
                    SwitchListTile(
                      title: const Text('Заморозка серии'),
                      subtitle: const Text('Защитить пропущенный день и сохранить серию'),
                      value: st.streakFreezeEnabled,
                      onChanged: (v) => _set(context, ref, (x) => x.copyWith(streakFreezeEnabled: v)),
                    ),
                    if (st.streakFreezeEnabled)
                      ListTile(
                        title: const Text('Заморозок в месяц'),
                        trailing: _stepper(context, ref, st.streakFreezesPerMonth, 0, 10,
                            (x, v) => x.copyWith(streakFreezesPerMonth: v)),
                      ),
                  ]),
                ]),
              ),
            ],
          )),
    );
  }
}
