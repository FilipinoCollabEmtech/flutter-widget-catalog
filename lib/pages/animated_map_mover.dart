import 'package:flutter/animation.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

/// Smoothly glides a [MapController] to a new center (and optionally zoom).
/// flutter_map 6 only has an instant `move`, so this tweens it frame by frame.
class AnimatedMapMover {
  AnimatedMapMover({required this.vsync, required this.mapController});

  final TickerProvider vsync;
  final MapController mapController;

  AnimationController? _controller;

  void animateTo(
    LatLng destination, {
    double? zoom,
    Duration duration = const Duration(milliseconds: 1200),
    Curve curve = Curves.easeInOutCubic,
  }) {
    cancel();

    final camera = mapController.camera;
    final latTween = Tween<double>(
      begin: camera.center.latitude,
      end: destination.latitude,
    );
    final lngTween = Tween<double>(
      begin: camera.center.longitude,
      end: destination.longitude,
    );
    final zoomTween = Tween<double>(
      begin: camera.zoom,
      end: zoom ?? camera.zoom,
    );

    final controller = AnimationController(vsync: vsync, duration: duration);
    final animation = CurvedAnimation(parent: controller, curve: curve);

    controller.addListener(() {
      mapController.move(
        LatLng(latTween.evaluate(animation), lngTween.evaluate(animation)),
        zoomTween.evaluate(animation),
      );
    });

    controller.addStatusListener((status) {
      if (status == AnimationStatus.completed ||
          status == AnimationStatus.dismissed) {
        if (identical(_controller, controller)) _controller = null;
        controller.dispose();
      }
    });

    _controller = controller;
    controller.forward();
  }

  /// Stops any animation in progress (e.g. when the user drags the map).
  void cancel() {
    final controller = _controller;
    _controller = null;
    controller?.dispose();
  }

  void dispose() => cancel();
}
