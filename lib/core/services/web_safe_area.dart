import 'package:flutter/widgets.dart';

import 'web_safe_area_stub.dart' if (dart.library.js_interop) 'web_safe_area_web.dart' as impl;

/// Applies the browser's safe-area insets (notch, Dynamic Island, home
/// indicator) to [MediaQuery] when the app runs as a web app on iOS.
///
/// Flutter web reports zero view padding, so without this the status bar
/// and the home indicator would cover the UI of the home-screen app.
class WebSafeArea extends StatelessWidget {
  const WebSafeArea({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context); // rebuilds on rotation / resize
    final insets = impl.readSafeAreaInsets();
    if (insets == EdgeInsets.zero) return child;
    EdgeInsets merge(EdgeInsets a) => EdgeInsets.fromLTRB(
          a.left > insets.left ? a.left : insets.left,
          a.top > insets.top ? a.top : insets.top,
          a.right > insets.right ? a.right : insets.right,
          a.bottom > insets.bottom ? a.bottom : insets.bottom,
        );
    return MediaQuery(
      data: mq.copyWith(padding: merge(mq.padding), viewPadding: merge(mq.viewPadding)),
      child: child,
    );
  }
}
