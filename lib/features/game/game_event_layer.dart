import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_theme.dart';
import '../../app/theme/app_tokens.dart';
import '../../core/game/game_events.dart';
import '../../core/widgets/buttons.dart';
import '../../core/widgets/motion.dart';
import '../../core/widgets/rpg_icons.dart';
import '../../data/models/penalty.dart';
import '../../core/utils/day.dart';
import 'game_controller.dart';

class _Toast {
  _Toast(this.id, this.icon, this.color, this.title, this.subtitle, {this.onTap});
  final int id;
  final IconData icon;
  final Color color;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
}

/// Listens to game events and renders feedback: XP toasts, achievement
/// cards and the level-up celebration.
class GameEventLayer extends ConsumerStatefulWidget {
  const GameEventLayer({super.key, required this.child});
  final Widget child;

  @override
  ConsumerState<GameEventLayer> createState() => _GameEventLayerState();
}

class _GameEventLayerState extends ConsumerState<GameEventLayer> {
  StreamSubscription<GameEvent>? _sub;
  final _toasts = <_Toast>[];
  final _pendingLevels = <LevelUp>[];
  bool _levelDialogOpen = false;
  int _seq = 0;
  int _xpBatch = 0;
  String _xpReason = '';
  Timer? _xpFlush;

  @override
  void initState() {
    super.initState();
    _sub = ref.read(gameControllerProvider.notifier).events.listen(_onEvent);
  }

  @override
  void dispose() {
    _sub?.cancel();
    _xpFlush?.cancel();
    super.dispose();
  }

  void _onEvent(GameEvent e) {
    if (!mounted) return;
    switch (e) {
      case XpGained(:final amount, :final reason):
        // Batch XP from one action into a single toast.
        _xpBatch += amount;
        if (_xpReason.isEmpty) _xpReason = reason;
        _xpFlush?.cancel();
        _xpFlush = Timer(const Duration(milliseconds: 120), () {
          final v = _xpBatch;
          if (v != 0) {
            _push(
              v > 0 ? Icons.add_rounded : Icons.undo_rounded,
              v > 0 ? AppColors.violetBright : AppColors.textSecondary,
              '${v > 0 ? '+' : ''}$v XP',
              _xpReason,
            );
          }
          _xpBatch = 0;
          _xpReason = '';
        });
      case GoldChanged():
        break; // shown together with quest / purchase toasts
      case LevelUp():
        _pendingLevels.add(e);
        _showNextLevel();
      case AttributeLevelUp(:final attribute, :final level):
        _push(RpgIcons.attribute(attribute), AppColors.attribute(attribute),
            '${attribute.label}: уровень $level', '+1 очко навыков');
      case AchievementUnlockedEvent(:final def, :final xp, :final gold):
        _push(RpgIcons.byKey(def.icon), AppColors.rarity(def.rarity),
            'Достижение: ${def.title}', '${def.rarity.tag} · +$xp XP · +$gold Gold',
            onTap: () => context.push('/profile/achievements'));
      case QuestCompletedEvent(:final quest, :final gold):
        if (quest.type.isMission) {
          _push(Icons.flag_rounded, AppColors.gold, 'Миссия завершена', quest.title);
        } else if (gold > 0) {
          _push(Icons.paid_rounded, AppColors.gold, '+$gold Gold', quest.title);
        }
      case SkillUnlockedEvent(:final def):
        _push(Icons.account_tree_rounded, AppColors.attribute(def.attribute),
            'Навык открыт', def.title);
      case RewardPurchasedEvent(:final reward):
        _push(Icons.card_giftcard_rounded, AppColors.gold, 'Награда получена', reward.title);
      case DailyClearEvent(:final xp, :final gold):
        _push(Icons.done_all_rounded, AppColors.gold, 'День закрыт',
            'Все ежедневные задания · +$xp XP · +$gold Gold');
      case PenaltyAppliedEvent(:final penalties):
        _showPenalties(penalties);
    }
  }

  void _push(IconData icon, Color color, String title, String? subtitle, {VoidCallback? onTap}) {
    final t = _Toast(_seq++, icon, color, title, subtitle, onTap: onTap);
    setState(() {
      _toasts.add(t);
      if (_toasts.length > 3) _toasts.removeAt(0);
    });
    Timer(const Duration(milliseconds: 2800), () {
      if (mounted) setState(() => _toasts.remove(t));
    });
  }

  void _showPenalties(List<PenaltyRecord> list) {
    final n = list.length;
    final days = list.map((p) => p.dayKey).toSet().toList()..sort();
    final msg = n == 1
        ? 'Пропущено: «${list.first.title}» (${humanDay(list.first.dayKey)})'
        : 'Пропущено $n ${plural(n, 'обязательство', 'обязательства', 'обязательств')} '
            'с ${humanDay(days.first)}';
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(
      duration: const Duration(seconds: 6),
      content: Text('$msg. Это можно восстановить в журнале.'),
      action: SnackBarAction(
        label: 'Журнал',
        onPressed: () => context.push('/profile/penalties'),
      ),
    ));
  }

  Future<void> _showNextLevel() async {
    if (_levelDialogOpen || _pendingLevels.isEmpty || !mounted) return;
    _levelDialogOpen = true;
    // Several levels at once: celebrate only the highest.
    final top = _pendingLevels.reduce((a, b) => a.level > b.level ? a : b);
    final gold = _pendingLevels.fold<int>(0, (s, e) => s + e.goldReward);
    _pendingLevels.clear();
    await Future.delayed(const Duration(milliseconds: 350));
    if (!mounted) return;
    final goCharacter = await showGeneralDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Новый уровень',
      barrierColor: Colors.black.o(0.6),
      transitionDuration: Motion.enabled(context) ? Durations2.fast : Duration.zero,
      pageBuilder: (ctx, _, __) => _LevelUpDialog(level: top.level, gold: gold),
      transitionBuilder: (ctx, anim, _, child) => FadeTransition(
        opacity: CurvedAnimation(parent: anim, curve: Curves.easeOut),
        child: child,
      ),
    );
    _levelDialogOpen = false;
    if (goCharacter == true && mounted) context.go('/character');
    _showNextLevel();
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    return Stack(
      children: [
        widget.child,
        Positioned(
          top: top + 8,
          left: 0,
          right: 0,
          child: IgnorePointer(
            ignoring: _toasts.every((t) => t.onTap == null),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: Gap.md),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [for (final t in _toasts) _ToastView(key: ValueKey(t.id), toast: t)],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Quiet notice: solid surface, hairline border, no glow. The accent is
/// used only for the headline number or title.
class _ToastView extends StatelessWidget {
  const _ToastView({super.key, required this.toast});
  final _Toast toast;

  @override
  Widget build(BuildContext context) {
    final animate = Motion.enabled(context);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: animate ? const Duration(milliseconds: 200) : Duration.zero,
      curve: Curves.easeOut,
      builder: (context, v, child) => Opacity(
        opacity: v,
        child: Transform.translate(offset: Offset(0, (1 - v) * -8), child: child),
      ),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: toast.onTap,
            borderRadius: Radii.rMd,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.surface2,
                borderRadius: Radii.rMd,
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  Icon(toast.icon, color: AppColors.textSecondary, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(toast.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppText.ui(14, weight: FontWeight.w600, color: toast.color)),
                        if (toast.subtitle != null && toast.subtitle!.isNotEmpty)
                          Text(toast.subtitle!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppText.ui(12.5, color: AppColors.textSecondary)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Level-up: a calm full-screen card. Big number, what was earned, two
/// choices. No rays, sparks or glow.
class _LevelUpDialog extends StatelessWidget {
  const _LevelUpDialog({required this.level, required this.gold});
  final int level;
  final int gold;

  @override
  Widget build(BuildContext context) => SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(Gap.lg),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360),
              child: Material(
                color: AppColors.surface1,
                shape: const RoundedRectangleBorder(
                  borderRadius: Radii.rXl,
                  side: BorderSide(color: AppColors.border),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(Gap.xl),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text('Новый уровень', style: AppText.label()),
                      const SizedBox(height: Gap.xs),
                      Text('$level',
                          style: AppText.number(64, weight: FontWeight.w600, color: Theme.of(context).colorScheme.primary)),
                      const SizedBox(height: Gap.sm),
                      Text('+$gold Gold и 1 очко навыков',
                          style: AppText.ui(15, weight: FontWeight.w500)),
                      const SizedBox(height: 4),
                      Text('Очко можно потратить в дереве навыков.',
                          style: AppText.ui(13.5, color: AppColors.textSecondary)),
                      const SizedBox(height: Gap.xl),
                      Row(
                        children: [
                          Expanded(
                            child: RpgButton(
                              label: 'Закрыть',
                              kind: RpgButtonKind.secondary,
                              onPressed: () => Navigator.pop(context, false),
                            ),
                          ),
                          const SizedBox(width: Gap.sm),
                          Expanded(
                            child: RpgButton(
                              label: 'К персонажу',
                              onPressed: () => Navigator.pop(context, true),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
}
