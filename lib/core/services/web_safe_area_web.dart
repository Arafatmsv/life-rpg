import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:flutter/painting.dart';
import 'package:web/web.dart' as web;

/// Safe-area insets for the web build.
///
/// Flutter web installs its own viewport meta without `viewport-fit=cover`,
/// so CSS `env(safe-area-inset-*)` is usually 0. The status bar is opaque
/// (see web/index.html), which keeps the top safe; only the iPhone home
/// indicator still overlaps the bottom of a home-screen web app, and that
/// inset is supplied here.
EdgeInsets readSafeAreaInsets() {
  final css = _cssInsets();
  if (css != EdgeInsets.zero) return css;
  return _homeIndicatorInset();
}

EdgeInsets _cssInsets() {
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

/// iPhones without a home button (X and newer, screen ≥ 812 pt tall) opened
/// from the home screen: keep controls above the home indicator.
EdgeInsets _homeIndicatorInset() {
  final nav = web.window.navigator;
  final standalone = (nav as JSObject).getProperty<JSAny?>('standalone'.toJS);
  if (standalone == null || !standalone.isA<JSBoolean>() || !(standalone as JSBoolean).toDart) {
    return EdgeInsets.zero;
  }
  if (!nav.userAgent.contains('iPhone')) return EdgeInsets.zero;
  final s = web.window.screen;
  final longSide = s.width > s.height ? s.width : s.height;
  if (longSide < 812) return EdgeInsets.zero;
  final portrait = web.window.innerHeight >= web.window.innerWidth;
  return EdgeInsets.only(bottom: portrait ? 34 : 21);
}
