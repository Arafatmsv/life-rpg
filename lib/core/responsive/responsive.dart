import 'package:flutter/material.dart';

/// Layout classes by available width (not device type).
enum WindowSize {
  compact, // < 600: phones
  medium, // 600–900: large phones, small tablets
  expanded, // 900–1200: tablets
  large; // ≥ 1200: wide screens

  static WindowSize of(double width) {
    if (width < 600) return compact;
    if (width < 900) return medium;
    if (width < 1200) return expanded;
    return large;
  }

  bool get isCompact => this == compact;
  bool get atLeastMedium => index >= medium.index;
  bool get atLeastExpanded => index >= expanded.index;

  /// Columns of the main content grid.
  int get columns => switch (this) {
        compact => 1,
        medium => 2,
        expanded => 2,
        large => 3,
      };

  double get gutter => switch (this) {
        compact => 16,
        medium => 20,
        expanded => 24,
        large => 28,
      };
}

extension ResponsiveContext on BuildContext {
  WindowSize get windowSize => WindowSize.of(MediaQuery.sizeOf(this).width);
}

/// Builds with the [WindowSize] of the *available* constraints, so nested
/// panes adapt to their real space rather than the whole screen.
class AdaptiveBuilder extends StatelessWidget {
  const AdaptiveBuilder({super.key, required this.builder});

  final Widget Function(BuildContext context, WindowSize size, BoxConstraints c) builder;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, c) => builder(context, WindowSize.of(c.maxWidth), c),
      );
}

/// Centers content and caps its width on large screens.
class ContentWidth extends StatelessWidget {
  const ContentWidth({super.key, required this.child, this.maxWidth = 1180});

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) => Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: child,
        ),
      );
}

/// Lays children into N columns with equal width; rows size to content.
/// Unlike GridView it does not force a fixed aspect ratio, so cards with
/// different heights never overflow.
class ResponsiveColumns extends StatelessWidget {
  const ResponsiveColumns({
    super.key,
    required this.children,
    this.minItemWidth = 320,
    this.spacing = 16,
    this.maxColumns = 3,
  });

  final List<Widget> children;
  final double minItemWidth;
  final double spacing;
  final int maxColumns;

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, c) {
        final cols = ((c.maxWidth + spacing) / (minItemWidth + spacing))
            .floor()
            .clamp(1, maxColumns);
        if (cols == 1) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < children.length; i++) ...[
                if (i > 0) SizedBox(height: spacing),
                children[i],
              ],
            ],
          );
        }
        final w = (c.maxWidth - spacing * (cols - 1)) / cols;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [for (final ch in children) SizedBox(width: w, child: ch)],
        );
      });
}
