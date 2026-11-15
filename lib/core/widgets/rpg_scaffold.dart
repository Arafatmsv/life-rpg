import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// Scaffold whose floating action button slides away while the user scrolls
/// down and returns on scroll up, so on small phones it never sits on top of
/// the content being read.
class RpgScaffold extends StatefulWidget {
  const RpgScaffold({super.key, this.appBar, required this.body, this.floatingActionButton});

  final PreferredSizeWidget? appBar;
  final Widget body;
  final Widget? floatingActionButton;

  @override
  State<RpgScaffold> createState() => _RpgScaffoldState();
}

class _RpgScaffoldState extends State<RpgScaffold> {
  var _fabVisible = true;

  bool _onScroll(UserScrollNotification n) {
    // Only vertical lists; horizontal carousels and tab swipes are ignored.
    if (n.metrics.axis != Axis.vertical) return false;
    final visible = switch (n.direction) {
      ScrollDirection.reverse => false,
      ScrollDirection.forward => true,
      ScrollDirection.idle => _fabVisible,
    };
    if (visible != _fabVisible) setState(() => _fabVisible = visible);
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final fab = widget.floatingActionButton;
    // On phones the shell's floating navigation bar overlaps the bottom of
    // the page (it reports itself as extra bottom padding); lift the FAB
    // above it. Tablets have no bottom bar, so the lift is zero there.
    final mq = MediaQuery.of(context);
    final barLift = (mq.padding.bottom - mq.viewPadding.bottom).clamp(0.0, 200.0);
    return Scaffold(
      appBar: widget.appBar,
      body: NotificationListener<UserScrollNotification>(onNotification: _onScroll, child: widget.body),
      floatingActionButton: fab == null
          ? null
          : AnimatedSlide(
              offset: _fabVisible ? Offset.zero : const Offset(0, 2),
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              child: AnimatedOpacity(
                opacity: _fabVisible ? 1 : 0,
                duration: const Duration(milliseconds: 180),
                child: IgnorePointer(
                  ignoring: !_fabVisible,
                  child: Padding(padding: EdgeInsets.only(bottom: barLift), child: fab),
                ),
              ),
            ),
    );
  }
}
