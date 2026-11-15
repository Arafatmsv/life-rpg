import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_theme.dart';
import '../../app/theme/app_tokens.dart';
import 'rpg_icons.dart';

/// The character portrait: emblem in a thin metal ring. Progress shows as
/// quiet structure, not effects: a second ring from level 10, a third from
/// level 30.
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
      ? 2
      : level >= 10
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
            Positioned.fill(child: CustomPaint(painter: _RingsPainter(color, tier))),
            Center(
              child: Container(
                width: size * 0.74,
                height: size * 0.74,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.surface1,
                  border: Border.all(color: color, width: 1.4),
                ),
                child: Icon(RpgIcons.byKey(avatarId), color: color, size: size * 0.32),
              ),
            ),
            if (showLevel)
              Positioned(
                bottom: -2,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: size * 0.07, vertical: 1),
                    decoration: BoxDecoration(
                      color: AppColors.bg,
                      borderRadius: Radii.rSm,
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Text('$level', style: AppText.number(size < 80 ? 11 : 12, color: AppColors.text)),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _RingsPainter extends CustomPainter {
  _RingsPainter(this.color, this.tier);
  final Color color;
  final int tier;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2;
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = color.o(0.45);
    if (tier >= 1) canvas.drawCircle(c, r * 0.86, p);
    if (tier >= 2) canvas.drawCircle(c, r * 0.97, p);
  }

  @override
  bool shouldRepaint(_RingsPainter old) => old.color != color || old.tier != tier;
}
