import 'dart:async';
import 'dart:collection';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/scheduler.dart';

/// Decides how many map tiles may be loaded at the same time, based on how
/// smoothly the app is drawing.
///
/// - Starts low (a couple of tiles at a time).
/// - While tiles are loading, if frames keep coming in on time, it allows one
///   more tile at a time, up to [maxLimit].
/// - The moment frames start dropping, it backs off by one, down to
///   [minLimit] (one tile at a time).
/// - The newest request goes first, so what is on screen now beats tiles you
///   already scrolled past.
///
/// Note: debug builds are always slower than release, so the limit will sit
/// low in debug. Judge it with `flutter run --profile` or `--release`.
class AdaptiveTileGate {
  AdaptiveTileGate({
    this.minLimit = 1,
    this.maxLimit = 6,
    int startLimit = 2,
    this.holdAfterUse = const Duration(milliseconds: 50),
    this.slowFrameFactor = 1.25,
    this.goodFramesToSpeedUp = 40,
    this.backOffCooldown = const Duration(milliseconds: 250),
  })  : _limit = startLimit.clamp(minLimit, maxLimit).toInt(),
        _startLimit = startLimit.clamp(minLimit, maxLimit).toInt();

  final int minLimit;
  final int maxLimit;

  /// A finished tile keeps its slot this long. Tiles are cheap to read but
  /// costly to draw afterwards, so this paces how fast they reach the screen.
  final Duration holdAfterUse;

  /// A frame counts as slow when build or raster takes longer than the frame
  /// budget (1000 / refresh rate ms) times this.
  final double slowFrameFactor;

  /// Smooth frames in a row (while loading) before allowing one more tile.
  final int goodFramesToSpeedUp;

  /// Minimum time between two back-offs.
  final Duration backOffCooldown;

  int _limit;
  final int _startLimit;
  int _active = 0;
  int _goodStreak = 0;
  bool _started = false;
  bool _disposed = false;
  DateTime _lastBackOff = DateTime.fromMillisecondsSinceEpoch(0);
  final Queue<Completer<void>> _waiting = Queue<Completer<void>>();

  /// When true (active pinch), the gate limits loads to a single concurrent
  /// tile and stops speeding up, so obsolete intermediate-zoom reads don't
  /// flood the worker isolate.
  bool _pinchMode = false;

  int get limit => _limit;
  int get active => _active;
  int get queued => _waiting.length;

  /// Get or set pinch mode. When entering pinch, the gate immediately drops
  /// to its minimum concurrent load count. When leaving, it returns to the
  /// starting limit.
  bool get pinchMode => _pinchMode;

  void setPinchMode(bool active) {
    _pinchMode = active;
    if (active) {
      _limit = minLimit.clamp(minLimit, maxLimit).toInt();
      _goodStreak = 0;
      _lastBackOff = DateTime.fromMillisecondsSinceEpoch(0);
    } else {
      _limit = _startLimit.clamp(minLimit, maxLimit).toInt();
    }
  }

  String get stats => 'limit $_limit · active $_active · queued $queued';

  void start() {
    if (_started || _disposed) return;
    _started = true;
    SchedulerBinding.instance.addTimingsCallback(_onTimings);
  }

  /// Wait for a free slot. Call [release] when done.
  Future<void> acquire() {
    if (_disposed) return Future.error(StateError('Tile gate disposed'));
    if (_active < _limit) {
      _active++;
      return Future<void>.value();
    }
    final waiter = Completer<void>();
    _waiting.addLast(waiter);
    return waiter.future;
  }

  void release() {
    Future<void>.delayed(holdAfterUse, () {
      _active = math.max(0, _active - 1);
      _pump();
    });
  }

  void _pump() {
    while (!_disposed && _active < _limit && _waiting.isNotEmpty) {
      _active++;
      _waiting.removeLast().complete(); // newest first
    }
  }

  double get _frameBudgetMs {
    final views = PlatformDispatcher.instance.views;
    final rate = views.isEmpty ? 60.0 : views.first.display.refreshRate;
    return 1000 / (rate > 0 ? rate : 60);
  }

  void _onTimings(List<FrameTiming> timings) {
    if (_disposed) return;
    final loading = _active > 0 || _waiting.isNotEmpty;
    if (!loading) {
      _goodStreak = 0;
      return;
    }

    final slowAbove = _frameBudgetMs * slowFrameFactor;
    for (final t in timings) {
      final worstMs = math.max(
        t.buildDuration.inMicroseconds,
        t.rasterDuration.inMicroseconds,
      ) /
          1000;

      if (worstMs > slowAbove) {
        _goodStreak = 0;
        final now = DateTime.now();
        if (_limit > minLimit && now.difference(_lastBackOff) > backOffCooldown) {
          _limit--;
          _lastBackOff = now;
        }
      } else if (++_goodStreak >= goodFramesToSpeedUp) {
        _goodStreak = 0;
        if (_limit < maxLimit) {
          _limit++;
          _pump();
        }
      }
    }
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    if (_started) {
      SchedulerBinding.instance.removeTimingsCallback(_onTimings);
    }
    for (final w in _waiting) {
      if (!w.isCompleted) w.completeError(StateError('Tile gate disposed'));
    }
    _waiting.clear();
  }
}
