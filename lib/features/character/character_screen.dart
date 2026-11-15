import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_theme.dart';
import '../../app/theme/app_tokens.dart';
import '../../core/game/game_clock.dart';
import '../../core/responsive/responsive.dart';
import '../../core/utils/day.dart';
import '../../core/widgets/avatar_emblem.dart';
import '../../core/widgets/progress.dart';
import '../../core/widgets/rpg_card.dart';
import '../../core/widgets/rpg_icons.dart';
import '../../core/widgets/states.dart';
import '../../data/models/enums.dart';
import '../../data/models/ledger.dart';
import '../game/game_controller.dart';
import '../help/glossary.dart';
import 'character_edit_sheet.dart';
import 'character_widgets.dart';

class CharacterScreen extends ConsumerWidget {
  const CharacterScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(gameControllerProvider).valueOrNull;
    final snap = ref.watch(snapshotProvider);
    if (s == null || snap == null) return const Scaffold(body: LoadingView());
    final ch = s.character!;
    final tz = s.settings.tzOffsetMinutes;
    final recent = s.xp.values.toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    final hero = RpgCard(
      padding: const EdgeInsets.all(Gap.xl),
      glow: AppColors.avatarPalette[ch.avatarColor % AppColors.avatarPalette.length],
      child: Column(children: [
        AvatarEmblem(avatarId: ch.avatarId, colorIndex: ch.avatarColor, level: snap.level.level, size: 140),
        const SizedBox(height: Gap.md),
        Text(ch.name, textAlign: TextAlign.center, style: AppText.display(34)),
        const SizedBox(height: 4),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(RpgIcons.characterClass(ch.characterClass), size: 16, color: AppColors.textMuted),
          const SizedBox(width: 6),
          Text(ch.characterClass.label, style: AppText.ui(14, color: AppColors.textSecondary)),
        ]),
        const SizedBox(height: Gap.lg),
        Row(children: [
          Text('УРОВЕНЬ ${snap.level.level}', style: AppText.label(color: AppColors.text)),
          const Spacer(),
          Text('${snap.level.xpIntoLevel} / ${snap.level.xpForNext} XP',
              style: AppText.number(12.5, color: AppColors.textSecondary)),
        ]),
        const SizedBox(height: 8),
        XpBar(value: snap.level.progress, height: 12),
        const SizedBox(height: Gap.lg),
        Wrap(alignment: WrapAlignment.center, spacing: Gap.lg, runSpacing: Gap.sm, children: [
          Explain(term: Term.xp, child: _Big('${snap.level.totalXp}', 'всего XP')),
          Explain(term: Term.gold, child: _Big('${snap.gold}', 'Gold')),
          Explain(term: Term.rating, child: _Big('${snap.rating}', 'рейтинг')),
          Explain(term: Term.sp, child: _Big('${snap.skillPoints}', 'очки навыков')),
        ]),
        const SizedBox(height: Gap.lg),
        Wrap(spacing: Gap.xs, runSpacing: Gap.xs, alignment: WrapAlignment.center, children: [
          OutlinedButton.icon(
            onPressed: () => openCharacterEditor(context),
            icon: const Icon(Icons.edit_rounded, size: 18),
            label: const Text('Изменить персонажа'),
          ),
          OutlinedButton.icon(
            onPressed: () => context.go('/skills'),
            icon: const Icon(Icons.account_tree_rounded, size: 18),
            label: const Text('Дерево навыков'),
          ),
        ]),
      ]),
    );

    final radar = RpgCard(
      child: Column(children: [
        Row(children: [
          Expanded(child: Text('Баланс развития', style: AppText.display(22))),
          Text('Σ ${snap.rating}', style: AppText.number(14, color: AppColors.textSecondary)),
        ]),
        const SizedBox(height: Gap.sm),
        LayoutBuilder(
          builder: (context, c) => Center(child: AttributeRadar(levels: snap.attributeLevels, size: c.maxWidth.clamp(220, 340))),
        ),
      ]),
    );

    final attrs = RpgCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('Характеристики', style: AppText.display(22)),
        const SizedBox(height: 4),
        Text('Игровые показатели. Растут от реальных действий.',
            style: AppText.ui(12.5, color: AppColors.textMuted)),
        const SizedBox(height: Gap.sm),
        for (final a in AttributeType.values)
          InkWell(
            borderRadius: Radii.rMd,
            onTap: () => context.push('/character/attribute/${a.name}'),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
              child: Row(children: [
                IconTile(RpgIcons.attribute(a), color: AppColors.attribute(a), size: 38),
                const SizedBox(width: Gap.sm),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Expanded(
                        child: Text(a.label,
                            maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.ui(14.5, weight: FontWeight.w700)),
                      ),
                      if (ch.focus.contains(a))
                        Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: const Explain(term: Term.focus, child: Pill('фокус')),
                        ),
                      Text('Ур. ${snap.attributeLevels[a]!.level}', style: AppText.number(14)),
                    ]),
                    const SizedBox(height: 6),
                    XpBar(
                      value: snap.attributeLevels[a]!.progress,
                      height: 6,
                      colors: [AppColors.attribute(a).o(0.6), AppColors.attribute(a)],
                      glow: false,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${snap.attributeLevels[a]!.xpIntoLevel} / ${snap.attributeLevels[a]!.xpForNext} XP · '
                      'всего ${snap.attributeXp[a]}',
                      style: AppText.ui(11.5, color: AppColors.textMuted),
                    ),
                  ]),
                ),
                const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
              ]),
            ),
          ),
      ]),
    );

    final goals = RpgCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Expanded(child: Text('Цели и приоритеты', style: AppText.display(22))),
          IconButton(
            tooltip: 'Изменить',
            onPressed: () => openCharacterEditor(context),
            icon: const Icon(Icons.edit_rounded, size: 20),
          ),
        ]),
        const SizedBox(height: Gap.xs),
        Wrap(spacing: 6, runSpacing: 6, children: [
          for (final a in ch.focus)
            Explain(term: Term.focus, child: Pill(a.label, color: AppColors.text)),
          if (ch.focus.isEmpty) Text('Фокус не выбран', style: AppText.ui(13, color: AppColors.textMuted)),
        ]),
        const SizedBox(height: Gap.sm),
        for (final g in ch.goals)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(children: [
              Expanded(child: Text(g, style: AppText.ui(14))),
            ]),
          ),
        if (ch.goals.isEmpty) Text('Добавьте личные цели в редактировании персонажа.', style: AppText.ui(13, color: AppColors.textMuted)),
      ]),
    );

    final history = RpgCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('За что получен опыт', style: AppText.display(22)),
        const SizedBox(height: Gap.xs),
        if (recent.isEmpty) Text('Пока пусто', style: AppText.ui(13, color: AppColors.textMuted)),
        for (final t in recent.take(15)) XpHistoryRow(tx: t, tz: tz),
      ]),
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Персонаж')),
      body: AdaptiveBuilder(builder: (context, size, c) {
        final pad = EdgeInsets.fromLTRB(size.gutter, Gap.xs, size.gutter, Gap.xxl + MediaQuery.paddingOf(context).bottom);
        if (size.atLeastExpanded) {
          return SingleChildScrollView(
            padding: pad,
            child: ContentWidth(
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(child: _col([hero, goals, history])),
                const SizedBox(width: Gap.lg),
                Expanded(child: _col([radar, attrs])),
              ]),
            ),
          );
        }
        return ListView(padding: pad, children: [
          ContentWidth(maxWidth: 720, child: _col([hero, radar, attrs, goals, history])),
        ]);
      }),
    );
  }

  Widget _col(List<Widget> c) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < c.length; i++) ...[if (i > 0) const SizedBox(height: Gap.md), c[i]],
        ],
      );
}

class _Big extends StatelessWidget {
  const _Big(this.value, this.label);
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) => Column(children: [
        Text(value, style: AppText.number(22, color: AppColors.text)),
        Text(label, style: AppText.ui(11.5, color: AppColors.textMuted)),
      ]);
}

/// One ledger line: what was earned, why and when.
class XpHistoryRow extends StatelessWidget {
  const XpHistoryRow({super.key, required this.tx, required this.tz});
  final XpTransaction tx;
  final int? tz;

  @override
  Widget build(BuildContext context) {
    final positive = tx.amount >= 0;
    final at = GameClock.toWall(tx.createdAt, tz);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(tx.note.isEmpty ? tx.source.label : tx.note,
                maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.ui(13.5, weight: FontWeight.w600)),
            Text(
              '${tx.source.label}${tx.attribute != null ? ' · ${tx.attribute!.label}' : ''} · '
              '${humanDay(dayKeyOf(at))} ${two(at.hour)}:${two(at.minute)}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.ui(11.5, color: AppColors.textMuted),
            ),
          ]),
        ),
        Text('${positive ? '+' : ''}${tx.amount}',
            style: AppText.number(14, color: positive ? AppColors.text : AppColors.danger)),
      ]),
    );
  }
}
