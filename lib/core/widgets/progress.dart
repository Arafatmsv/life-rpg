import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_theme.dart';
import 'motion.dart';

/// Animated XP bar with gradient fill and a soft glow at the tip.
class XpBar extends StatelessWidget {
  const XpBar({
    super.key,
    required this.value,
    this.height = 10,
    this.colors = const [AppColors.xpStart, AppColors.xpEnd],
    this.background = AppColors.surface3,
    this.glow = true,
  });

  final double value;
  final double height;
  final List<Color> colors;
  final Color background;
  final bool glow;

  @override
  Widget build(BuildContext context) {
    final animate = Motion.enabled(context);
    return Semantics(
      value: '${(value * 100).round()}%',
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: value.clamp(0, 1)),
        duration: animate ? const Duration(milliseconds: 900) : Duration.zero,
        curve: Curves.easeOutCubic,
        builder: (context, v, _) => Container(
          height: height,
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(height),
          ),
          child: LayoutBuilder(
            builder: (context, c) => Align(
              alignment: Alignment.centerLeft,
              child: Container(
                width: math.max(v > 0 ? height : 0, c.maxWidth * v),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(height),
                  color: colors.last,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Circular progress with a centered child.
class ProgressRing extends StatelessWidget {
  const ProgressRing({
    super.key,
    required this.value,
    required this.color,
    this.size = 56,
    this.stroke = 5,
    this.child,
  });

  final double value;
  final Color color;
  final double size;
  final double stroke;
  final Widget? child;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: value.clamp(0, 1)),
        duration: Motion.enabled(context) ? const Duration(milliseconds: 900) : Duration.zero,
        curve: Curves.easeOutCubic,
        builder: (context, v, _) => SizedBox(
          width: size,
          height: size,
          child: CustomPaint(
            painter: _RingPainter(v, color, stroke),
            child: Center(child: child),
          ),
        ),
      );
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.v, this.color, this.stroke);
  final double v;
  final Color color;
  final double stroke;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final r = rect.deflate(stroke / 2);
    canvas.drawArc(r, 0, math.pi * 2, false,
        Paint()
          ..color = AppColors.surface3
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke);
    if (v <= 0) return;
    canvas.drawArc(
      r,
      -math.pi / 2,
      math.pi * 2 * v,
      false,
      Paint()
        ..shader = SweepGradient(
          startAngle: -math.pi / 2,
          endAngle: math.pi * 1.5,
          colors: [color.o(0.6), color],
        ).createShader(rect)
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = stroke,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.v != v || old.color != color;
}

/// "Label ······ value" line used in stat lists.
class StatLine extends StatelessWidget {
  const StatLine(this.label, this.value, {super.key, this.color});

  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Expanded(child: Text(label, style: AppText.ui(13.5, color: AppColors.textSecondary))),
            Text(value, style: AppText.number(14, color: color ?? AppColors.text)),
          ],
        ),
      );
}
