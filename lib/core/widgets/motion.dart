import 'package:flutter/widgets.dart';

/// Decides whether decorative animations should play: off when the player
/// disabled them in settings or the OS asks to reduce motion.
class Motion extends InheritedWidget {
  const Motion({super.key, required this.animations, required super.child});

  final bool animations;

  static bool enabled(BuildContext context) {
    final m = context.dependOnInheritedWidgetOfExactType<Motion>();
    final os = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    return (m?.animations ?? true) && !os;
  }

  @override
  bool updateShouldNotify(Motion oldWidget) => oldWidget.animations != animations;
}
