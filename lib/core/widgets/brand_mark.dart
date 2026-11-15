import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_theme.dart';

/// Life RPG mark: two stacked chevrons (a rank insignia: "level up").
/// The same geometry is used for the launcher icons.
class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.size = 28, this.color});
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: size,
        height: size,
        child: CustomPaint(painter: _ChevronsPainter(color ?? Theme.of(context).colorScheme.primary)),
      );
}

class _ChevronsPainter extends CustomPainter {
  _ChevronsPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.11
      ..strokeCap = StrokeCap.square
      ..strokeJoin = StrokeJoin.miter;
    for (final y in [0.33, 0.59]) {
      final path = Path()
        ..moveTo(w * 0.22, h * (y + 0.16))
        ..lineTo(w * 0.50, h * (y - 0.08))
        ..lineTo(w * 0.78, h * (y + 0.16));
      canvas.drawPath(path, p);
    }
  }

  @override
  bool shouldRepaint(_ChevronsPainter old) => old.color != color;
}

/// Mark + wordmark, for the navigation rail and the sign-in screen.
class BrandLockup extends StatelessWidget {
  const BrandLockup({super.key, this.markSize = 24, this.textSize = 18});
  final double markSize;
  final double textSize;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          BrandMark(size: markSize),
          SizedBox(width: markSize * 0.4),
          Text('Life RPG', style: AppText.ui(textSize, weight: FontWeight.w600, color: AppColors.text, spacing: -0.2)),
        ],
      );
}
