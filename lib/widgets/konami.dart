import 'dart:math' show sin;

import 'package:flutter/material.dart';

/// Tracks Konami-code progress across the app.
/// Arrows come from the Profile D-pad, B/A from Home/Profile tab
/// switches, Start from the D-pad center button.
class KonamiController extends ChangeNotifier {
  static const List<String> sequence = [
    'up',
    'up',
    'down',
    'down',
    'left',
    'right',
    'left',
    'right',
    'b',
    'a',
    'start',
  ];

  final List<String> _inputs = [];

  /// Feed one input. Only the trailing inputs matter, so random
  /// tapping can never complete the code by accident.
  void add(String input) {
    // Double-taps on B/A/Start collapse into one. (The arrows
    // legitimately repeat, so only B/A/Start are deduped.)
    if (_inputs.isNotEmpty &&
        _inputs.last == input &&
        (input == 'b' || input == 'a' || input == 'start')) {
      return;
    }
    _inputs.add(input);
    if (_inputs.length > sequence.length) {
      _inputs.removeAt(0);
    }
    if (completed) notifyListeners();
  }

  bool get completed {
    if (_inputs.length != sequence.length) return false;
    for (var i = 0; i < sequence.length; i++) {
      if (_inputs[i] != sequence[i]) return false;
    }
    return true;
  }

  void reset() => _inputs.clear();
}

/// Slow lurching rise with no overshoot, so the PageView stays stable.
class ZombieLurch extends Curve {
  const ZombieLurch();

  @override
  double transform(double t) {
    return t + 0.05 * (1 - t) * sin(t * 12.566);
  }
}
