import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_theme.dart';
import '../../app/theme/app_tokens.dart';
import '../../core/game/level_math.dart';
import '../../core/game/stats.dart';
import '../../core/widgets/avatar_emblem.dart';
import '../../core/widgets/progress.dart';
import '../../core/widgets/rpg_card.dart';
import '../../core/widgets/rpg_icons.dart';
import '../../data/models/character.dart';
import '../../data/models/enums.dart';
import '../../data/repositories/sync_service.dart';
import '../../app/providers.dart';
import '../game/game_controller.dart';
import '../help/glossary.dart';

String greeting(DateTime now) {
  final h = now.hour;
  if (h < 5) return 'Доброй ночи';
  if (h < 12) return 'Доброе утро';
  if (h < 18) return 'Добрый день';
  return 'Добрый вечер';
}

/// Avatar, name, level and XP — the hero block of the home screen.
class CharacterHeader extends StatelessWidget {
  const CharacterHeader({super.key, required this.character, required this.snap, this.large = false});

  final Character character;
  final GameSnapshot snap;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final l = snap.level;
    return RpgCard(
      padding: EdgeInsets.all(large ? Gap.xl : Gap.lg),
      onTap: () => context.go('/character'),
      semanticLabel: '${character.name}, уровень ${l.level}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Explain(
                term: Term.level,
                child: AvatarEmblem(
                  avatarId: character.avatarId,
                  colorIndex: character.avatarColor,
                  level: l.level,
                  size: large ? 88 : 72,
                ),
              ),
              const SizedBox(width: Gap.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(character.name,
                        maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.display(large ? 32 : 28)),
                    const SizedBox(height: 2),
                    Text('${character.characterClass.label} · уровень ${l.level}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.ui(13.5, color: AppColors.textSecondary)),
                  ],
                ),
              ),
              const Explain(term: Term.sync, child: SyncBadge()),
            ],
          ),
          const SizedBox(height: Gap.lg),
          Explain(
            term: Term.xp,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Text('Опыт', style: AppText.ui(13, color: AppColors.textSecondary)),
                    const Spacer(),
                    Text('${l.xpIntoLevel} / ${l.xpForNext}', style: AppText.number(13, color: AppColors.text)),
                  ],
                ),
                const SizedBox(height: 8),
                XpBar(value: l.progress, height: 4),
                const SizedBox(height: 6),
                Text('До уровня ${l.level + 1}: ${l.xpRemaining} XP',
                    style: AppText.ui(12, color: AppColors.textMuted)),
              ],
            ),
          ),
          const SizedBox(height: Gap.md),
          const Divider(height: 1),
          const SizedBox(height: Gap.md),
          Row(
            children: [
              Expanded(child: _Stat(term: Term.gold, icon: Icons.paid_outlined, value: '${snap.gold}', label: 'Gold')),
              Expanded(
                  child: _Stat(
                      term: Term.streak,
                      icon: Icons.local_fire_department_outlined,
                      value: '${snap.streak.current}',
                      label: 'Серия')),
              Expanded(
                  child: _Stat(
                      term: Term.rating, icon: Icons.military_tech_outlined, value: '${snap.rating}', label: 'Рейтинг')),
              Expanded(
                  child: _Stat(
                      term: Term.sp, icon: Icons.account_tree_outlined, value: '${snap.skillPoints}', label: 'SP')),
            ],
          ),
        ],
      ),
    );
  }
}

/// Number over a caption. Long-press explains it.
class _Stat extends StatelessWidget {
  const _Stat({required this.term, required this.icon, required this.value, required this.label});
  final Term term;
  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) => Explain(
        term: term,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(icon, size: 16, color: AppColors.textMuted),
              const SizedBox(width: 6),
              Text(value, style: AppText.number(18, color: AppColors.text)),
            ]),
            const SizedBox(height: 2),
            Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.ui(12, color: AppColors.textMuted)),
          ],
        ),
      );
}

/// One attribute as a list row: icon, name, level and a thin bar.
/// Tap opens details, long-press explains the attribute.
class AttributeTile extends ConsumerWidget {
  const AttributeTile({super.key, required this.attribute, required this.level, this.focus = false});

  final AttributeType attribute;
  final LevelInfo level;
  final bool focus;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cfg = ref.watch(engineProvider).config;
    return Explain(
      info: attributeInfo(attribute, cfg),
      child: InkWell(
        onTap: () => context.push('/character/attribute/${attribute.name}'),
        child: Semantics(
          label: '${attribute.label}, уровень ${level.level}',
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(
              children: [
                Icon(RpgIcons.attribute(attribute), size: 18, color: AppColors.textSecondary),
                const SizedBox(width: Gap.sm),
                Expanded(
                  flex: 5,
                  child: Text(
                    focus ? '${attribute.label} · фокус' : attribute.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.ui(14),
                  ),
                ),
                Expanded(flex: 4, child: XpBar(value: level.progress, height: 3)),
                SizedBox(
                  width: 36,
                  child: Text('${level.level}', textAlign: TextAlign.right, style: AppText.number(14)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Heptagon radar of the seven attributes.
class AttributeRadar extends StatelessWidget {
  const AttributeRadar({super.key, required this.levels, this.size = 260});

  final Map<AttributeType, LevelInfo> levels;
  final double size;

  @override
  Widget build(BuildContext context) {
    final values = {
      for (final a in AttributeType.values) a: levels[a]!.level + levels[a]!.progress - 1,
    };
    final maxV = math.max(4.0, values.values.fold<double>(0, math.max) + 1);
    return Semantics(
      label: 'Диаграмма характеристик: '
          '${AttributeType.values.map((a) => '${a.label} ${levels[a]!.level}').join(', ')}',
      child: SizedBox(
        width: size,
        height: size,
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: const Duration(milliseconds: 900),
          curve: Curves.easeOutCubic,
          builder: (context, t, _) => CustomPaint(
            painter: _RadarPainter(values, maxV, t, Theme.of(context).colorScheme.primary),
          ),
        ),
      ),
    );
  }
}

class _RadarPainter extends CustomPainter {
  _RadarPainter(this.values, this.maxV, this.t, this.accent);
  final Map<AttributeType, double> values;
  final double maxV;
  final double t;
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2 - 34;
    final n = AttributeType.values.length;
    Offset pt(int i, double k) {
      final a = -math.pi / 2 + i * 2 * math.pi / n;
      return c + Offset(math.cos(a), math.sin(a)) * r * k;
    }

    final grid = Paint()
      ..style = PaintingStyle.stroke
      ..color = AppColors.border
      ..strokeWidth = 1;
    for (var ring = 1; ring <= 4; ring++) {
      final p = Path();
      for (var i = 0; i < n; i++) {
        final o = pt(i, ring / 4);
        i == 0 ? p.moveTo(o.dx, o.dy) : p.lineTo(o.dx, o.dy);
      }
      canvas.drawPath(p..close(), grid);
    }
    for (var i = 0; i < n; i++) {
      canvas.drawLine(c, pt(i, 1), grid);
    }

    final shape = Path();
    for (var i = 0; i < n; i++) {
      final v = (values[AttributeType.values[i]]! / maxV).clamp(0.04, 1.0) * t;
      final o = pt(i, v);
      i == 0 ? shape.moveTo(o.dx, o.dy) : shape.lineTo(o.dx, o.dy);
    }
    shape.close();
    canvas.drawPath(shape, Paint()..color = accent.o(0.12));
    canvas.drawPath(
      shape,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = accent,
    );

    for (var i = 0; i < n; i++) {
      final a = AttributeType.values[i];
      final v = (values[a]! / maxV).clamp(0.04, 1.0) * t;
      canvas.drawCircle(pt(i, v), 2.5, Paint()..color = accent);
      final tp = TextPainter(
        text: TextSpan(
          text: '${a.code.substring(0, 3)} ${values[a]!.floor() + 1}',
          style: AppText.ui(10.5, weight: FontWeight.w500, color: AppColors.textSecondary),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final lp = pt(i, 1.16);
      tp.paint(canvas, lp - Offset(tp.width / 2, tp.height / 2));
    }
  }

  @override
  bool shouldRepaint(_RadarPainter old) => old.t != t || old.values != values;
}

/// Small indicator of the sync state.
class SyncBadge extends ConsumerWidget {
  const SyncBadge({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final st = ref.watch(syncStatusProvider);
    final (icon, color) = switch (st.phase) {
      SyncPhase.localOnly => (Icons.phone_android_rounded, AppColors.textMuted),
      SyncPhase.idle => (Icons.cloud_done_rounded, AppColors.success),
      SyncPhase.syncing => (Icons.cloud_sync_rounded, AppColors.info),
      SyncPhase.offline => (Icons.cloud_off_rounded, AppColors.warning),
      SyncPhase.error => (Icons.sync_problem_rounded, AppColors.danger),
    };
    final pending = st.pending > 0 ? ' · в очереди: ${st.pending}' : '';
    return Tooltip(
      message: '${st.phase.label}$pending',
      child: Semantics(
        label: 'Синхронизация: ${st.phase.label}$pending',
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(icon, size: 20, color: color),
        ),
      ),
    );
  }
}
