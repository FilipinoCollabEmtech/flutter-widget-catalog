import 'package:flutter/foundation.dart';

import '../models/route.dart';

/// Hands a route from the scanner to the home map.
///
/// The scanner and the map are siblings inside the tab [PageView], so there is
/// no ancestor widget to pass a callback through. A pair of global notifiers
/// keeps that wiring explicit, and lets the scanner work from either entry
/// point (the home tab's camera and the admin "test scanner" tile).
class RouteFocus {
  RouteFocus._();

  /// Route the map should draw. Consumed and cleared by the home page.
  static final ValueNotifier<JeepneyRoute?> pending =
      ValueNotifier<JeepneyRoute?>(null);

  /// Tab to switch to; `main.dart` listens and clears it. 0 is Home,
  /// 1 is the camera/scanner page.
  static final ValueNotifier<int?> tabRequest = ValueNotifier<int?>(null);

  /// Ask the map to draw [route] and bring the home tab forward.
  static void show(JeepneyRoute route) {
    pending.value = route;
    tabRequest.value = 0;
  }

  /// Bring the camera/scanner tab forward (Assistant "scan" command).
  static void openScanner() {
    tabRequest.value = 1;
  }
}
