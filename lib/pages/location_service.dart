import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

enum LocationStatus {
  /// Feature is switched off by the user.
  off,

  /// Checking permission / waiting for the stream to start.
  starting,

  /// Subscribed to GPS updates (position may still be null until first fix).
  active,

  /// Device location (GPS) toggle is off.
  serviceDisabled,

  /// User denied the permission prompt (can be asked again).
  denied,

  /// User denied permanently; only the app settings page can fix this.
  deniedForever,

  /// Something unexpected failed.
  error,
}

/// Owns everything about the user's location. Knows nothing about the map,
/// so it keeps working unchanged when you switch to vector tiles.
class LocationService extends ChangeNotifier {
  LocationStatus _status = LocationStatus.off;
  LatLng? _position;
  double? _accuracyMeters;
  StreamSubscription<Position>? _subscription;

  LocationStatus get status => _status;

  /// Latest known position, or null if off / no fix yet.
  LatLng? get position => _position;

  /// Horizontal accuracy radius in meters, or null if unknown.
  double? get accuracyMeters => _accuracyMeters;

  bool get isEnabled =>
      _status == LocationStatus.starting || _status == LocationStatus.active;

  Future<void> enable() async {
    if (isEnabled) return;
    _setStatus(LocationStatus.starting);

    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        _setStatus(LocationStatus.serviceDisabled);
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      // The user may have toggled the feature off while the prompt was open.
      if (_status != LocationStatus.starting) return;

      if (permission == LocationPermission.deniedForever) {
        _setStatus(LocationStatus.deniedForever);
        return;
      }
      if (permission != LocationPermission.whileInUse &&
          permission != LocationPermission.always) {
        _setStatus(LocationStatus.denied);
        return;
      }

      // Show something immediately if the OS already has a recent fix.
      try {
        final last = await Geolocator.getLastKnownPosition();
        if (last != null && _status == LocationStatus.starting) {
          _applyPosition(last);
        }
      } catch (_) {
        // Not critical; the stream below will deliver a position.
      }

      if (_status != LocationStatus.starting) return;

      _subscription = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 3, // meters; avoids redrawing for tiny jitter
        ),
      ).listen(
        _applyPosition,
        onError: (Object error) {
          debugPrint('Location stream error: $error');
          _stopStream();
          _position = null;
          _accuracyMeters = null;
          _setStatus(LocationStatus.error);
        },
      );

      _setStatus(LocationStatus.active);
    } catch (error, stackTrace) {
      debugPrint('Failed to start location: $error');
      debugPrintStack(stackTrace: stackTrace);
      _setStatus(LocationStatus.error);
    }
  }

  void disable() {
    _stopStream();
    _position = null;
    _accuracyMeters = null;
    _setStatus(LocationStatus.off);
  }

  Future<bool> openAppSettings() => Geolocator.openAppSettings();

  Future<bool> openLocationSettings() => Geolocator.openLocationSettings();

  void _applyPosition(Position p) {
    _position = LatLng(p.latitude, p.longitude);
    _accuracyMeters = p.accuracy;
    notifyListeners();
  }

  void _stopStream() {
    _subscription?.cancel();
    _subscription = null;
  }

  void _setStatus(LocationStatus value) {
    _status = value;
    notifyListeners();
  }

  @override
  void dispose() {
    _stopStream();
    super.dispose();
  }
}
