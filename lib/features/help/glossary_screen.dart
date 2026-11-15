import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_theme.dart';
import '../../app/theme/app_tokens.dart';
import '../../core/responsive/responsive.dart';
import '../../core/widgets/rpg_card.dart';
import '../../data/models/enums.dart';
import 'glossary.dart';

/// All game concepts in one place. The same cards open on long-press.
class GlossaryScreen extends ConsumerWidget {
  const GlossaryScreen({super.key});

  static const _groups = <(String, List<Term>)>[
    ('Прогресс', [Term.xp, Term.level, Term.sp, Term.rating, Term.attribute, Term.focus]),
    ('Задания', [Term.daily, Term.weekly, Term.mission, Term.side, Term.boss, Term.difficulty]),
    ('Награды', [Term.gold, Term.shop, Term.dailyClear, Term.dailyCap, Term.rarity, Term.skillTree]),
    ('Ритм и отдых', [Term.streak, Term.restDay, Term.freeze, Term.vacation]),
    ('Пропуски', [Term.penalty, Term.recovery, Term.excuse]),
    ('Прочее', [Term.journal, Term.sync]),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cfg = ref.watch(engineProvider).config;
    return Scaffold(
      appBar: AppBar(title: const Text('Как устроена игра')),
      body: AdaptiveBuilder(builder: (context, size, c) => ListView(
            padding: EdgeInsets.fromLTRB(size.gutter, Gap.xs, size.gutter, Gap.xxl),
            children: [
              ContentWidth(
                maxWidth: 720,
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Text('Подсказку к любому значку можно открыть, зажав его.',
                      style: AppText.ui(14, color: AppColors.textSecondary)),
                  for (final (title, terms) in _groups) ...[
                    const SizedBox(height: Gap.lg),
                    Text(title.toUpperCase(), style: AppText.label()),
                    const SizedBox(height: Gap.xs),
                    _List(infos: [for (final t in terms) termInfo(t, cfg)]),
                  ],
                  const SizedBox(height: Gap.lg),
                  Text('ХАРАКТЕРИСТИКИ', style: AppText.label()),
                  const SizedBox(height: Gap.xs),
                  _List(infos: [for (final a in AttributeType.values) attributeInfo(a, cfg)]),
                ]),
              ),
            ],
          )),
    );
  }
}

class _List extends StatelessWidget {
  const _List({required this.infos});
  final List<TermInfo> infos;

  @override
  Widget build(BuildContext context) => RpgCard(
        padding: EdgeInsets.zero,
        child: Column(children: [
          for (var i = 0; i < infos.length; i++) ...[
            if (i > 0) const Divider(height: 1, indent: Gap.md),
            InkWell(
              onTap: () => showTermInfo(context, infos[i]),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: Gap.md, vertical: 12),
                child: Row(children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(infos[i].title, style: AppText.ui(15, weight: FontWeight.w500)),
                      const SizedBox(height: 2),
                      Text(infos[i].what,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.ui(12.5, color: AppColors.textMuted, height: 1.4)),
                    ]),
                  ),
                  const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted, size: 20),
                ]),
              ),
            ),
          ],
        ]),
      );
}
