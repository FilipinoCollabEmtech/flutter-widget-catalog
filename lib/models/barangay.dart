import 'dart:math';

import 'package:latlong2/latlong.dart';

/// Simple bounding box for lat/lng (latlong2 0.9.x doesn't export LatLngBounds).
class LatLngBounds {
  final LatLng southwest;
  final LatLng northeast;

  const LatLngBounds(this.southwest, this.northeast);

  bool intersects(LatLngBounds other) {
    return southwest.latitude <= other.northeast.latitude &&
        northeast.latitude >= other.southwest.latitude &&
        southwest.longitude <= other.northeast.longitude &&
        northeast.longitude >= other.southwest.longitude;
  }
}

/// A single barangay with boundary polygon and optional user tag.
class Barangay {
  final String name;
  final String code;
  final List<LatLng> polygon;
  final bool seen;
  final DateTime? seenAt;
  final String? note;

  const Barangay({
    required this.name,
    required this.code,
    required this.polygon,
    this.seen = false,
    this.seenAt,
    this.note,
  });

  Barangay copyWith({
    String? name,
    String? code,
    List<LatLng>? polygon,
    bool? seen,
    DateTime? seenAt,
    String? note,
  }) {
    return Barangay(
      name: name ?? this.name,
      code: code ?? this.code,
      polygon: polygon ?? this.polygon,
      seen: seen ?? this.seen,
      seenAt: seenAt ?? this.seenAt,
      note: note ?? this.note,
    );
  }

  /// Point-in-polygon (ray casting).
  bool contains(LatLng point) {
    bool inside = false;
    final n = polygon.length;
    for (int i = 0, j = n - 1; i < n; j = i++) {
      final pi = polygon[i];
      final pj = polygon[j];
      if ((pi.longitude > point.longitude) != (pj.longitude > point.longitude)) {
        final slope = (pj.latitude - pi.latitude) / (pj.longitude - pi.longitude);
        if (point.latitude < pi.latitude + slope * (point.longitude - pi.longitude)) {
          inside = !inside;
        }
      }
    }
    return inside;
  }

  /// Centroid for label placement.
  LatLng get centroid {
    double lat = 0, lng = 0;
    for (final p in polygon) {
      lat += p.latitude;
      lng += p.longitude;
    }
    final n = polygon.length;
    return LatLng(lat / n, lng / n);
  }

  /// Bounding box.
  LatLngBounds get bounds {
    double minLat = 90, maxLat = -90, minLng = 180, maxLng = -180;
    for (final p in polygon) {
      minLat = minLat < p.latitude ? minLat : p.latitude;
      maxLat = maxLat > p.latitude ? maxLat : p.latitude;
      minLng = minLng < p.longitude ? minLng : p.longitude;
      maxLng = maxLng > p.longitude ? maxLng : p.longitude;
    }
    return LatLngBounds(LatLng(minLat, minLng), LatLng(maxLat, maxLng));
  }
}

/// A planned route: ordered waypoints connected by straight lines.
class RoutePlan {
  final List<LatLng> waypoints;

  const RoutePlan({this.waypoints = const []});

  RoutePlan copyWith({List<LatLng>? waypoints}) {
    return RoutePlan(waypoints: waypoints ?? this.waypoints);
  }

  /// Sample points along each segment at roughly [meters] apart and check
  /// if any fall inside [barangay]. Returns true if the route passes through.
  bool passesThrough(Barangay barangay, {double sampleMeters = 50}) {
    if (waypoints.length < 2) return false;

    // Quick bounding-box reject.
    final routeBounds = _bounds();
    final bBounds = barangay.bounds;
    if (!routeBounds.intersects(bBounds)) return false;

    // Check waypoints themselves.
    for (final wp in waypoints) {
      if (barangay.contains(wp)) return true;
    }

    // Sample points along each segment.
    for (var i = 0; i < waypoints.length - 1; i++) {
      final a = waypoints[i];
      final b = waypoints[i + 1];
      final dist = _haversineMeters(a, b);
      final steps = (dist / sampleMeters).ceil();
      if (steps < 1) continue;
      for (var s = 1; s <= steps; s++) {
        final t = s / steps;
        final lat = a.latitude + (b.latitude - a.latitude) * t;
        final lng = a.longitude + (b.longitude - a.longitude) * t;
        if (barangay.contains(LatLng(lat, lng))) return true;
      }
    }
    return false;
  }

  LatLngBounds _bounds() {
    double minLat = 90, maxLat = -90, minLng = 180, maxLng = -180;
    for (final p in waypoints) {
      minLat = minLat < p.latitude ? minLat : p.latitude;
      maxLat = maxLat > p.latitude ? maxLat : p.latitude;
      minLng = minLng < p.longitude ? minLng : p.longitude;
      maxLng = maxLng > p.longitude ? maxLng : p.longitude;
    }
    return LatLngBounds(LatLng(minLat, minLng), LatLng(maxLat, maxLng));
  }

  static double _haversineMeters(LatLng a, LatLng b) {
    const R = 6371000.0;
    final dLat = _rad(b.latitude - a.latitude);
    final dLng = _rad(b.longitude - a.longitude);
    final lat1 = _rad(a.latitude);
    final lat2 = _rad(b.latitude);
    final h = _hav(dLat) + cos(lat1) * cos(lat2) * _hav(dLng);
    return 2 * R * asin(sqrt(h));
  }

  static double _rad(double d) => d * pi / 180;
  static double _hav(double d) {
    final s = sin(d / 2);
    return s * s;
  }
}
