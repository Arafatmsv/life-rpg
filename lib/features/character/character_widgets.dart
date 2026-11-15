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
import '../game/game_controller.dart';

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
    final accent = Theme.of(context).colorScheme.primary;
    final l = snap.level;
    return RpgCard(
      padding: EdgeInsets.all(large ? Gap.xl : Gap.lg),
      glow: AppColors.violet,
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF1F1A30), AppColors.surface1, AppColors.surface0],
      ),
      onTap: () => context.go('/character'),
      semanticLabel: '${character.name}, уровень ${l.level}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AvatarEmblem(
                avatarId: character.avatarId,
                colorIndex: character.avatarColor,
                level: l.level,
                size: large ? 104 : 84,
              ),
              const SizedBox(width: Gap.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(greeting(DateTime.now()), style: AppText.ui(13, color: AppColors.textSecondary)),
                    Text(character.name,
                        maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.display(large ? 34 : 30)),
                    const SizedBox(height: 2),
                    Row(children: [
                      Icon(RpgIcons.characterClass(character.characterClass), size: 14, color: accent),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(character.characterClass.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppText.ui(13, weight: FontWeight.w700, color: accent)),
                      ),
                    ]),
                  ],
                ),
              ),
              const SyncBadge(),
            ],
          ),
          const SizedBox(height: Gap.lg),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('УРОВЕНЬ ${l.level}', style: AppText.label(color: AppColors.text)),
              const Spacer(),
              Text('${l.xpIntoLevel} / ${l.xpForNext} XP', style: AppText.number(12.5, color: AppColors.textSecondary)),
            ],
          ),
          const SizedBox(height: 8),
          XpBar(value: l.progress, height: 12),
          const SizedBox(height: 6),
          Text('Всего ${l.totalXp} XP · до ${l.level + 1}-го уровня ${l.xpRemaining} XP',
              style: AppText.ui(12, color: AppColors.textMuted)),
          const SizedBox(height: Gap.md),
          Wrap(
            spacing: Gap.sm,
            runSpacing: Gap.xs,
            children: [
              _Stat(icon: Icons.paid_rounded, color: AppColors.gold, value: '${snap.gold}', label: 'Gold'),
              _Stat(
                  icon: Icons.local_fire_department_rounded,
                  color: AppColors.warning,
                  value: '${snap.streak.current}',
                  label: 'серия'),
              _Stat(icon: Icons.military_tech_rounded, color: AppColors.violetBright, value: '${snap.rating}', label: 'рейтинг'),
              _Stat(icon: Icons.account_tree_rounded, color: AppColors.info, value: '${snap.skillPoints}', label: 'SP'),
            ],
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.icon, required this.color, required this.value, required this.label});
  final IconData icon;
  final Color color;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.bg.o(0.4),
          borderRadius: Radii.rSm,
          border: Border.all(color: AppColors.borderSoft),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(value, style: AppText.number(14, color: AppColors.text)),
          const SizedBox(width: 4),
          Text(label, style: AppText.ui(12, color: AppColors.textMuted)),
        ]),
      );
}

/// Compact attribute tile with level and progress.
class AttributeTile extends StatelessWidget {
  const AttributeTile({super.key, required this.attribute, required this.level, this.focus = false});

  final AttributeType attribute;
  final LevelInfo level;
  final bool focus;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.attribute(attribute);
    return RpgCard(
      padding: const EdgeInsets.all(Gap.sm),
      radius: Radii.md,
      onTap: () => context.push('/character/attribute/${attribute.name}'),
      borderColor: focus ? c.o(0.45) : null,
      semanticLabel: '${attribute.label}, уровень ${level.level}',
      child: Row(
        children: [
          IconTile(RpgIcons.attribute(attribute), color: c, size: 36),
          const SizedBox(width: Gap.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Expanded(
                    child: Text(attribute.code,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.ui(11, weight: FontWeight.w700, color: c, spacing: 0.8)),
                  ),
                  if (focus) Icon(Icons.star_rounded, size: 12, color: c),
                  const SizedBox(width: 2),
                  Text('${level.level}', style: AppText.number(15)),
                ]),
                const SizedBox(height: 6),
                XpBar(value: level.progress, height: 5, colors: [c.o(0.55), c], glow: false),
              ],
            ),
          ),
        ],
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
    canvas.drawPath(
      shape,
      Paint()
        ..shader = RadialGradient(colors: [AppColors.violet.o(0.45), accent.o(0.25)])
            .createShader(Rect.fromCircle(center: c, radius: r)),
    );
    canvas.drawPath(
      shape,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = accent.o(0.9),
    );

    for (var i = 0; i < n; i++) {
      final a = AttributeType.values[i];
      final v = (values[a]! / maxV).clamp(0.04, 1.0) * t;
      canvas.drawCircle(pt(i, v), 3.5, Paint()..color = AppColors.attribute(a));
      final tp = TextPainter(
        text: TextSpan(
          text: '${a.code.substring(0, 3)} ${values[a]!.floor() + 1}',
          style: AppText.ui(10.5, weight: FontWeight.w700, color: AppColors.attribute(a)),
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
