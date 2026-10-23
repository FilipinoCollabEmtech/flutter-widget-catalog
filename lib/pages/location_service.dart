import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_compass/flutter_compass.dart';
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

/// Owns everything about the user's location and facing direction.
/// Knows nothing about the map, so it keeps working unchanged when you
/// switch to vector tiles.
class LocationService extends ChangeNotifier {
  /// How long to wait for a first fix before telling the user it is slow.
  static const Duration _slowFixDelay = Duration(seconds: 15);

  LocationStatus _status = LocationStatus.off;
  LatLng? _position;
  double? _accuracyMeters;
  double? _heading;
  bool _approximate = false;
  bool _searchingSlow = false;
  bool _hasCompass = false;

  StreamSubscription<Position>? _positionSub;
  StreamSubscription<CompassEvent>? _compassSub;
  Timer? _slowTimer;

  LocationStatus get status => _status;

  /// Latest known position, or null if off / no fix yet.
  LatLng? get position => _position;

  /// Horizontal accuracy radius in meters, or null if unknown.
  double? get accuracyMeters => _accuracyMeters;

  /// Direction the user is facing, in degrees clockwise from north.
  /// This value is *continuous* (it can go below 0 or above 360) so that
  /// animating between two headings always turns the short way round.
  /// Null until a heading is known.
  double? get heading => _heading;

  /// True when the user only granted approximate (coarse) location.
  /// Approximate location does not use GPS and is far less precise.
  bool get approximate => _approximate;

  /// True when we have been waiting a while for the first GPS fix.
  bool get searchingSlow => _searchingSlow;

  bool get isEnabled =>
      _status == LocationStatus.starting || _status == LocationStatus.active;

  /// GPS-focused settings. On Android we force the plain GPS provider
  /// (LocationManager) instead of Google's fused provider, which leans on
  /// network data and can fail to produce a fix when the phone is offline.
  LocationSettings _settings() {
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return AndroidSettings(
          accuracy: LocationAccuracy.best,
          distanceFilter: 3,
          intervalDuration: const Duration(seconds: 1),
          forceLocationManager: true,
        );
      case TargetPlatform.iOS:
        return AppleSettings(
          accuracy: LocationAccuracy.best,
          activityType: ActivityType.otherNavigation,
          distanceFilter: 3,
          pauseLocationUpdatesAutomatically: false,
        );
      default:
        return const LocationSettings(
          accuracy: LocationAccuracy.best,
          distanceFilter: 3,
        );
    }
  }

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

      // Did the user pick "Approximate" instead of "Precise"?
      try {
        _approximate = await Geolocator.getLocationAccuracy() ==
            LocationAccuracyStatus.reduced;
      } catch (_) {
        _approximate = false;
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

      _positionSub = Geolocator.getPositionStream(
        locationSettings: _settings(),
      ).listen(
        _applyPosition,
        onError: (Object error) {
          debugPrint('Location stream error: $error');
          _stopStreams();
          _position = null;
          _accuracyMeters = null;
          _setStatus(LocationStatus.error);
        },
      );

      // Compass: works offline and, unlike GPS course, also when standing
      // still. events is null on devices without a magnetometer.
      final compassEvents = FlutterCompass.events;
      if (compassEvents != null) {
        _hasCompass = true;
        _compassSub = compassEvents.listen(
          (event) {
            final value = event.heading;
            if (value != null) _applyHeading(value);
          },
          onError: (Object _) {},
        );
      }

      if (_position == null) {
        _slowTimer = Timer(_slowFixDelay, () {
          if (_position == null && _status == LocationStatus.active) {
            _searchingSlow = true;
            notifyListeners();
          }
        });
      }

      _setStatus(LocationStatus.active);
    } catch (error, stackTrace) {
      debugPrint('Failed to start location: $error');
      debugPrintStack(stackTrace: stackTrace);
      _setStatus(LocationStatus.error);
    }
  }

  void disable() {
    _stopStreams();
    _position = null;
    _accuracyMeters = null;
    _heading = null;
    _approximate = false;
    _searchingSlow = false;
    _hasCompass = false;
    _setStatus(LocationStatus.off);
  }

  Future<bool> openAppSettings() => Geolocator.openAppSettings();

  Future<bool> openLocationSettings() => Geolocator.openLocationSettings();

  void _applyPosition(Position p) {
    _position = LatLng(p.latitude, p.longitude);
    _accuracyMeters = p.accuracy;
    _searchingSlow = false;
    _slowTimer?.cancel();
    _slowTimer = null;

    // No compass on this device: fall back to GPS course while moving.
    if (!_hasCompass && p.speed > 1 && p.heading >= 0) {
      _applyHeading(p.heading);
    }
    notifyListeners();
  }

  void _applyHeading(double raw) {
    final wrapped = raw % 360; // Dart's % is never negative here
    final current = _heading;
    if (current == null) {
      _heading = wrapped;
      notifyListeners();
      return;
    }
    // Shortest signed turn from the current heading to the new one.
    final delta = ((wrapped - (current % 360) + 540) % 360) - 180;
    if (delta.abs() < 2) return; // ignore sensor jitter
    _heading = current + delta;
    notifyListeners();
  }

  void _stopStreams() {
    _positionSub?.cancel();
    _positionSub = null;
    _compassSub?.cancel();
    _compassSub = null;
    _slowTimer?.cancel();
    _slowTimer = null;
  }

  void _setStatus(LocationStatus value) {
    _status = value;
    notifyListeners();
  }

  @override
  void dispose() {
    _stopStreams();
    super.dispose();
  }
}
