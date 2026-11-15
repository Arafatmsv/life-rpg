import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_theme.dart';
import 'rpg_icons.dart';

/// The character portrait. The frame grows more ornate with the level, so
/// progress is visible at a glance: plain ring → runes (5) → double ring (10)
/// → crown of rays (20) → radiant (30).
class AvatarEmblem extends StatelessWidget {
  const AvatarEmblem({
    super.key,
    required this.avatarId,
    required this.colorIndex,
    this.level = 1,
    this.size = 88,
    this.showLevel = true,
  });

  final String avatarId;
  final int colorIndex;
  final int level;
  final double size;
  final bool showLevel;

  static int tierOf(int level) => level >= 30
      ? 4
      : level >= 20
          ? 3
          : level >= 10
              ? 2
              : level >= 5
                  ? 1
                  : 0;

  @override
  Widget build(BuildContext context) {
    final color = AppColors.avatarPalette[colorIndex % AppColors.avatarPalette.length];
    final tier = tierOf(level);
    return Semantics(
      label: 'Аватар персонажа, уровень $level',
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(child: CustomPaint(painter: _FramePainter(color, tier))),
            Center(
              child: Container(
                width: size * 0.68,
                height: size * 0.68,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [color.o(0.32), AppColors.surface1],
                    stops: const [0, 1],
                  ),
                  border: Border.all(color: color.o(0.55), width: 1.2),
                ),
                child: Icon(RpgIcons.byKey(avatarId), color: color, size: size * 0.32),
              ),
            ),
            if (showLevel)
              Positioned(
                bottom: -size * 0.04,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: size * 0.08, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.bg,
                      borderRadius: BorderRadius.circular(99),
                      border: Border.all(color: color.o(0.8)),
                    ),
                    child: Text(
                      '$level',
                      style: AppText.number(math.max(11, size * 0.14), color: color),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _FramePainter extends CustomPainter {
  _FramePainter(this.color, this.tier);
  final Color color;
  final int tier;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2;
    if (tier >= 4) {
      canvas.drawCircle(
        c,
        r,
        Paint()..shader = RadialGradient(colors: [color.o(0.28), color.o(0)]).createShader(Offset.zero & size),
      );
    }
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..color = color.o(0.75);
    canvas.drawCircle(c, r * 0.82, ring);
    if (tier >= 1) {
      // runes: small diamonds around the ring
      final rune = Paint()..color = color.o(0.85);
      final n = tier >= 3 ? 12 : 8;
      for (var i = 0; i < n; i++) {
        final a = i / n * math.pi * 2;
        final p = c + Offset(math.cos(a), math.sin(a)) * r * 0.82;
        final path = Path()
          ..moveTo(p.dx, p.dy - 3)
          ..lineTo(p.dx + 2.2, p.dy)
          ..lineTo(p.dx, p.dy + 3)
          ..lineTo(p.dx - 2.2, p.dy)
          ..close();
        canvas.drawPath(path, rune);
      }
    }
    if (tier >= 2) {
      canvas.drawCircle(
        c,
        r * 0.94,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = color.o(0.4),
      );
    }
    if (tier >= 3) {
      final ray = Paint()
        ..color = color.o(0.6)
        ..strokeWidth = 1.4
        ..strokeCap = StrokeCap.round;
      for (var i = 0; i < 24; i++) {
        final a = i / 24 * math.pi * 2;
        final d = Offset(math.cos(a), math.sin(a));
        canvas.drawLine(c + d * r * 0.95, c + d * r * (i.isEven ? 1.04 : 1.0), ray);
      }
    }
  }

  @override
  bool shouldRepaint(_FramePainter old) => old.color != color || old.tier != tier;
}
