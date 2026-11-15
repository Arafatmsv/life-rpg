import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_theme.dart';
import '../../app/theme/app_tokens.dart';
import '../../core/game/achievement_catalog.dart';
import '../../core/game/game_clock.dart';
import '../../core/responsive/responsive.dart';
import '../../core/utils/day.dart';
import '../../core/widgets/buttons.dart';
import '../../core/widgets/feedback.dart';
import '../../core/widgets/progress.dart';
import '../../core/widgets/rpg_card.dart';
import '../../core/widgets/rpg_icons.dart';
import '../../core/widgets/states.dart';
import '../../data/models/enums.dart';
import '../game/game_controller.dart';
import '../help/glossary.dart';

class AchievementsScreen extends ConsumerStatefulWidget {
  const AchievementsScreen({super.key});

  @override
  ConsumerState<AchievementsScreen> createState() => _AchievementsScreenState();
}

class _AchievementsScreenState extends ConsumerState<AchievementsScreen> {
  Rarity? _rarity;
  var _onlyUnlocked = false;

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(gameControllerProvider).valueOrNull;
    final snap = ref.watch(snapshotProvider);
    if (s == null || snap == null) return const Scaffold(body: LoadingView());
    final cfg = ref.watch(engineProvider).config;
    final list = achievementCatalog
        .where((a) => _rarity == null || a.rarity == _rarity)
        .where((a) => !_onlyUnlocked || s.achievements.containsKey(a.id))
        .toList()
      ..sort((a, b) {
        final ua = s.achievements.containsKey(a.id) ? 0 : 1, ub = s.achievements.containsKey(b.id) ? 0 : 1;
        return ua != ub ? ua - ub : a.rarity.index - b.rarity.index;
      });

    return Scaffold(
      appBar: AppBar(title: const Text('Достижения')),
      body: AdaptiveBuilder(builder: (context, size, c) => ListView(
            padding: EdgeInsets.fromLTRB(size.gutter, Gap.xs, size.gutter, Gap.xxl + MediaQuery.paddingOf(context).bottom),
            children: [
              ContentWidth(
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  RpgCard(
                    child: Row(children: [
                      ProgressRing(
                        value: s.achievements.length / achievementCatalog.length,
                        color: Theme.of(context).colorScheme.primary,
                        size: 56,
                        stroke: 3,
                        child: Text('${s.achievements.length}', style: AppText.number(18)),
                      ),
                      const SizedBox(width: Gap.md),
                      Expanded(
                        child: Text(
                          'Собрано ${s.achievements.length} из ${achievementCatalog.length}. '
                          'Каждое достижение даёт XP и Gold по редкости.',
                          style: AppText.ui(13.5, color: AppColors.textSecondary),
                        ),
                      ),
                    ]),
                  ),
                  const SizedBox(height: Gap.md),
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    ChoiceChipX(label: 'Все', selected: _rarity == null, onTap: () => setState(() => _rarity = null)),
                    for (final r in Rarity.values)
                      ChoiceChipX(
                        label: r.tag,
                        color: AppColors.rarity(r),
                        selected: _rarity == r,
                        onTap: () => setState(() => _rarity = r),
                      ),
                    ChoiceChipX(
                      label: 'Только полученные',
                      icon: Icons.check_rounded,
                      selected: _onlyUnlocked,
                      onTap: () => setState(() => _onlyUnlocked = !_onlyUnlocked),
                    ),
                  ]),
                  const SizedBox(height: Gap.md),
                  if (list.isEmpty)
                    const EmptyState(
                      icon: Icons.emoji_events_outlined,
                      title: 'Пока ничего',
                      message: 'Здесь появятся полученные достижения.',
                    ),
                  RpgCard(
                    padding: EdgeInsets.zero,
                    child: Column(children: [
                      for (var k = 0; k < list.length; k++) ...[
                        if (k > 0) const Divider(height: 1, indent: Gap.md),
                        Builder(builder: (context) {
                          final a = list[k];
                          final u = s.achievements[a.id];
                          final p = a.progress(snap).clamp(0, a.target);
                          return InkWell(
                            onTap: () => showRpgSheet(context, builder: (_) => _Details(id: a.id)),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: Gap.md, vertical: 12),
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Row(children: [
                                  Icon(u == null ? Icons.lock_outline_rounded : RpgIcons.byKey(a.icon),
                                      size: 18, color: u == null ? AppColors.textMuted : AppColors.textSecondary),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(a.title,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: AppText.ui(15,
                                            weight: FontWeight.w500,
                                            color: u != null ? AppColors.text : AppColors.textSecondary)),
                                  ),
                                  Explain(
                                    term: Term.rarity,
                                    child: Text(a.rarity.tag,
                                        style: AppText.ui(12.5, color: AppColors.rarity(a.rarity))),
                                  ),
                                ]),
                                const SizedBox(height: 2),
                                Text(a.description, style: AppText.ui(12.5, color: AppColors.textMuted)),
                                const SizedBox(height: 6),
                                if (u != null)
                                  Text(
                                    'Получено ${humanDayYear(GameClock.dayOf(u.unlockedAt, s.settings.tzOffsetMinutes))} · '
                                    '+${cfg.rarityXp[a.rarity]} XP · +${cfg.rarityGold[a.rarity]} Gold',
                                    style: AppText.ui(12, color: AppColors.textSecondary),
                                  )
                                else
                                  Row(children: [
                                    Expanded(child: XpBar(value: p / a.target, height: 3)),
                                    const SizedBox(width: 8),
                                    Text('$p / ${a.target}', style: AppText.number(11.5, color: AppColors.textMuted)),
                                  ]),
                              ]),
                            ),
                          );
                        }),
                      ],
                    ]),
                  ),
                ]),
              ),
            ],
          )),
    );
  }
}

class _Details extends ConsumerWidget {
  const _Details({required this.id});
  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(gameControllerProvider).valueOrNull!;
    final snap = ref.watch(snapshotProvider)!;
    final cfg = ref.watch(engineProvider).config;
    final a = achievementById[id]!;
    final u = s.achievements[id];
    final c = AppColors.rarity(a.rarity);
    final p = a.progress(snap).clamp(0, a.target);
    return Padding(
      padding: const EdgeInsets.fromLTRB(Gap.lg, 0, Gap.lg, Gap.xl),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        IconTile(RpgIcons.byKey(a.icon), color: u == null ? AppColors.textMuted : c, size: 84),
        const SizedBox(height: Gap.md),
        Text(a.title, style: AppText.display(30)),
        Text('${a.rarity.tag} · ${a.rarity.label}', style: AppText.ui(13, weight: FontWeight.w700, color: c)),
        const SizedBox(height: Gap.md),
        Text(a.description, textAlign: TextAlign.center, style: AppText.ui(15, color: AppColors.textSecondary)),
        const SizedBox(height: Gap.lg),
        StatLine('Условие', '${a.target}'),
        StatLine('Ваш прогресс', '$p'),
        StatLine('Награда', '+${cfg.rarityXp[a.rarity]} XP · +${cfg.rarityGold[a.rarity]} Gold'),
        StatLine('Статус', u == null ? 'Не получено' : 'Получено ${humanDayYear(GameClock.dayOf(u.unlockedAt, s.settings.tzOffsetMinutes))}',
            color: u == null ? AppColors.textMuted : c),
      ]),
    );
  }
}
