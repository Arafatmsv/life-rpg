import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_theme.dart';
import '../../app/theme/app_tokens.dart';
import '../../core/game/game_clock.dart';
import '../../core/responsive/responsive.dart';
import '../../core/utils/day.dart';
import '../../core/widgets/rpg_scaffold.dart';
import '../../core/widgets/buttons.dart';
import '../../core/widgets/feedback.dart';
import '../../core/widgets/progress.dart';
import '../../core/widgets/rpg_card.dart';
import '../../core/widgets/rpg_icons.dart';
import '../../core/widgets/states.dart';
import '../../data/models/reward.dart';
import '../game/game_controller.dart';
import '../help/glossary.dart';

class RewardsScreen extends ConsumerWidget {
  const RewardsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(gameControllerProvider).valueOrNull;
    final snap = ref.watch(snapshotProvider);
    if (s == null || snap == null) return const Scaffold(body: LoadingView());
    final rewards = s.rewards.values.where((r) => !r.deleted).toList()..sort((a, b) => a.cost.compareTo(b.cost));
    final purchases = s.purchases.values.toList()..sort((a, b) => b.purchasedAt.compareTo(a.purchasedAt));
    final gold = s.gold.values.toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final tz = s.settings.tzOffsetMinutes;

    final balance = Explain(
      term: Term.gold,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: Gap.xs),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Баланс', style: AppText.ui(13, color: AppColors.textSecondary)),
          const SizedBox(height: 2),
          Text('${snap.gold} Gold', style: AppText.number(30, color: AppColors.text)),
          const SizedBox(height: Gap.xs),
          Text('Награды назначаете вы сами. Приложение ничего не покупает и не списывает реальные деньги.',
              style: AppText.ui(13, color: AppColors.textMuted, height: 1.45)),
        ]),
      ),
    );

    final shop = rewards.isEmpty
        ? EmptyState(
            icon: Icons.card_giftcard_rounded,
            title: 'Добавьте награды',
            message: 'Что порадует вас в реальной жизни? Фильм вечером, новая книга, день без дел.',
            actionLabel: 'Новая награда',
            onAction: () => _edit(context),
          )
        : RpgCard(
            padding: EdgeInsets.zero,
            child: Column(children: [
              for (var k = 0; k < rewards.length; k++) ...[
                if (k > 0) const Divider(height: 1, indent: Gap.md),
                _RewardRow(reward: rewards[k], gold: snap.gold, onEdit: () => _edit(context, rewards[k])),
              ],
            ]),
          );

    final history = purchases.isEmpty
        ? const EmptyState(
            icon: Icons.receipt_long_rounded,
            title: 'Покупок пока нет',
            message: 'Здесь будет история наград, которые вы себе позволили.',
          )
        : Column(children: [
            for (final p in purchases)
              RpgCard(
                padding: const EdgeInsets.symmetric(horizontal: Gap.md, vertical: Gap.sm),
                child: Row(children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(p.rewardTitle, style: AppText.ui(14.5, weight: FontWeight.w700)),
                      Text(
                        '${humanDayYear(GameClock.dayOf(p.purchasedAt, tz))}${p.isRefunded ? ' · возвращено' : ''}',
                        style: AppText.ui(12, color: AppColors.textMuted),
                      ),
                    ]),
                  ),
                  Text('−${p.cost}', style: AppText.number(14, color: p.isRefunded ? AppColors.textMuted : AppColors.gold)),
                  if (!p.isRefunded)
                    IconButton(
                      tooltip: 'Отменить покупку',
                      icon: const Icon(Icons.undo_rounded),
                      onPressed: () async {
                        final ok = await confirm(context,
                            title: 'Отменить покупку?',
                            message: '${p.cost} Gold вернутся на баланс.',
                            confirmLabel: 'Вернуть Gold');
                        if (ok && context.mounted) {
                          await runGameAction(context, ref, (e, s) => e.refundPurchase(s, p.id),
                              success: 'Gold возвращены');
                        }
                      },
                    ),
                ]),
              ),
          ].expand((w) => [w, const SizedBox(height: Gap.xs)]).toList());

    final ledger = RpgCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('Движение Gold', style: AppText.display(22)),
        const SizedBox(height: Gap.xs),
        if (gold.isEmpty) Text('Пока пусто', style: AppText.ui(13, color: AppColors.textMuted)),
        for (final g in gold.take(40))
          StatLine(
            '${g.note.isEmpty ? g.source.label : g.note} · ${humanDay(g.dayKey)}',
            '${g.amount > 0 ? '+' : ''}${g.amount}',
            color: g.amount >= 0 ? AppColors.gold : AppColors.textSecondary,
          ),
      ]),
    );

    return DefaultTabController(
      length: 2,
      child: RpgScaffold(
        appBar: AppBar(
          title: const Text('Магазин наград'),
          bottom: const TabBar(tabs: [Tab(text: 'Награды'), Tab(text: 'История')]),
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _edit(context),
          icon: const Icon(Icons.add_rounded),
          label: const Text('Награда'),
        ),
        body: AdaptiveBuilder(builder: (context, size, c) {
          final pad = EdgeInsets.fromLTRB(size.gutter, Gap.md, size.gutter, 96);
          return TabBarView(children: [
            ListView(padding: pad, children: [ContentWidth(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [balance, const SizedBox(height: Gap.md), shop]))]),
            ListView(padding: pad, children: [ContentWidth(maxWidth: 760, child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [history, const SizedBox(height: Gap.md), ledger]))]),
          ]);
        }),
      ),
    );
  }

  void _edit(BuildContext context, [Reward? r]) =>
      showRpgSheet(context, builder: (_) => _RewardEditor(reward: r));
}

class _RewardRow extends ConsumerWidget {
  const _RewardRow({required this.reward, required this.gold, required this.onEdit});
  final Reward reward;
  final int gold;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final r = reward;
    final enough = gold >= r.cost;
    return InkWell(
      onTap: onEdit,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: Gap.md, vertical: 12),
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(r.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: AppText.ui(15, weight: FontWeight.w500)),
              const SizedBox(height: 2),
              Text(
                enough ? '${r.cost} Gold' : '${r.cost} Gold · не хватает ${r.cost - gold}',
                style: AppText.ui(12.5, color: AppColors.textMuted),
              ),
            ]),
          ),
          const SizedBox(width: Gap.sm),
          RpgButton(
            label: 'Купить',
            compact: true,
            kind: enough ? RpgButtonKind.primary : RpgButtonKind.secondary,
            onPressed: enough
                ? () async {
                    final ok = await confirm(context,
                        title: 'Купить «${r.title}»?',
                        message: 'С баланса спишется ${r.cost} Gold, останется ${gold - r.cost}. '
                            'Покупку можно отменить в истории.',
                        confirmLabel: 'Купить');
                    if (ok && context.mounted) {
                      await runGameAction(context, ref, (e, s) => e.purchaseReward(s, r.id));
                    }
                  }
                : null,
          ),
        ]),
      ),
    );
  }
}

class _RewardEditor extends ConsumerStatefulWidget {
  const _RewardEditor({this.reward});
  final Reward? reward;

  @override
  ConsumerState<_RewardEditor> createState() => _RewardEditorState();
}

class _RewardEditorState extends ConsumerState<_RewardEditor> {
  final _form = GlobalKey<FormState>();
  late final _title = TextEditingController(text: widget.reward?.title ?? '');
  late final _desc = TextEditingController(text: widget.reward?.description ?? '');
  late final _cost = TextEditingController(text: '${widget.reward?.cost ?? 200}');
  late var _icon = widget.reward?.icon ?? 'gift';

  @override
  void dispose() {
    _title.dispose();
    _desc.dispose();
    _cost.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final now = DateTime.now();
    final base = widget.reward ??
        Reward(id: ref.read(engineProvider).newId(), title: '', cost: 1, icon: _icon, createdAt: now, updatedAt: now);
    final r = base.copyWith(
      title: _title.text,
      description: _desc.text.trim(),
      cost: int.parse(_cost.text.trim()),
      icon: _icon,
    );
    final ok = await runGameAction(context, ref, (e, s) => e.saveReward(s, r),
        success: widget.reward == null ? 'Награда добавлена' : 'Награда сохранена');
    if (ok && mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(Gap.lg, 0, Gap.lg, Gap.xl),
        child: Form(
          key: _form,
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(widget.reward == null ? 'Новая награда' : 'Награда', style: AppText.display(28)),
            const SizedBox(height: Gap.md),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final ex in const [('Посмотреть фильм', 100, 'film'), ('Вечер отдыха', 200, 'spa'), ('Небольшая покупка', 300, 'shopping'), ('Желанная вещь', 1500, 'gift')])
                if (widget.reward == null)
                  ActionChip(
                    label: Text('${ex.$1} · ${ex.$2}'),
                    onPressed: () => setState(() {
                      _title.text = ex.$1;
                      _cost.text = '${ex.$2}';
                      _icon = ex.$3;
                    }),
                  ),
            ]),
            const SizedBox(height: Gap.md),
            TextFormField(
              controller: _title,
              maxLength: 80,
              decoration: const InputDecoration(labelText: 'Название', counterText: ''),
              validator: (v) => (v ?? '').trim().isEmpty ? 'Введите название' : null,
            ),
            const SizedBox(height: Gap.sm),
            TextFormField(
              controller: _desc,
              maxLength: 200,
              decoration: const InputDecoration(labelText: 'Описание (необязательно)', counterText: ''),
            ),
            const SizedBox(height: Gap.sm),
            TextFormField(
              controller: _cost,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(labelText: 'Стоимость, Gold', prefixIcon: Icon(Icons.paid_rounded)),
              validator: (v) {
                final n = int.tryParse((v ?? '').trim()) ?? 0;
                return n < 1 || n > 1000000 ? 'От 1 до 1 000 000' : null;
              },
            ),
            const SizedBox(height: Gap.md),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final k in RpgIcons.rewardKeys)
                IconButton(
                  tooltip: 'Иконка',
                  isSelected: _icon == k,
                  style: IconButton.styleFrom(
                    backgroundColor: _icon == k ? AppColors.gold.o(0.16) : AppColors.surface1,
                    side: BorderSide(color: _icon == k ? AppColors.gold : AppColors.border),
                  ),
                  onPressed: () => setState(() => _icon = k),
                  icon: Icon(RpgIcons.byKey(k), color: _icon == k ? AppColors.gold : AppColors.textSecondary),
                ),
            ]),
            const SizedBox(height: Gap.xl),
            RpgButton(label: 'Сохранить', icon: Icons.check_rounded, expand: true, onPressed: _save),
            if (widget.reward != null) ...[
              const SizedBox(height: Gap.sm),
              RpgButton(
                label: 'Удалить награду',
                kind: RpgButtonKind.danger,
                expand: true,
                onPressed: () async {
                  final ok = await confirm(context,
                      title: 'Удалить награду?',
                      message: 'История покупок сохранится.',
                      confirmLabel: 'Удалить',
                      destructive: true);
                  if (ok && context.mounted) {
                    final done = await runGameAction(context, ref, (e, s) => e.deleteReward(s, widget.reward!.id));
                    if (done && context.mounted) Navigator.pop(context);
                  }
                },
              ),
            ],
          ]),
        ),
      );
}
