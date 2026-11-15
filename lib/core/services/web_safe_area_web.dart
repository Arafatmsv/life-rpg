import 'package:flutter/painting.dart';
import 'package:web/web.dart' as web;

/// Measures CSS `env(safe-area-inset-*)` with an invisible probe element.
/// CSS pixels equal Flutter logical pixels on web.
EdgeInsets readSafeAreaInsets() {
  final body = web.document.body;
  if (body == null) return EdgeInsets.zero;
  final probe = web.document.createElement('div') as web.HTMLDivElement;
  probe.style.cssText = 'position:fixed;top:0;left:0;width:0;height:0;visibility:hidden;'
      'padding-top:env(safe-area-inset-top);padding-right:env(safe-area-inset-right);'
      'padding-bottom:env(safe-area-inset-bottom);padding-left:env(safe-area-inset-left);';
  body.append(probe);
  final cs = web.window.getComputedStyle(probe);
  double px(String v) => double.tryParse(v.replaceAll('px', '').trim()) ?? 0;
  final insets = EdgeInsets.fromLTRB(
    px(cs.paddingLeft),
    px(cs.paddingTop),
    px(cs.paddingRight),
    px(cs.paddingBottom),
  );
  probe.remove();
  return insets;
}
