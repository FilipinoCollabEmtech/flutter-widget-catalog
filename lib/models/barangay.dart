import 'dart:math';

import 'package:latlong2/latlong.dart';

import '../services/geojson.dart' show containsInAny;

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

/// A single barangay with its boundary and optional user tag.
///
/// Geometry is held as one or more outer rings in [parts]: a Polygon feature
/// contributes one ring, a MultiPolygon contributes one ring per part. Rings
/// are ordered largest-first, so [polygon] is always the piece big enough to
/// carry the label.
class Barangay {
  /// Display name — official PSGC name, no "Barangay" prefix.
  final String name;

  /// Primary key — `ADM4_PCODE`, unique across every feature in the file.
  final String code;

  /// City / municipality (`ADM3_EN`). Barangay names repeat across LGUs, so
  /// this is what tells two identically-named barangays apart.
  final String city;

  /// Outer rings, largest first. Non-empty for every loaded feature.
  final List<List<LatLng>> parts;

  final bool seen;
  final DateTime? seenAt;
  final String? note;

  const Barangay({
    required this.name,
    required this.code,
    required this.city,
    required this.parts,
    this.seen = false,
    this.seenAt,
    this.note,
  });

  /// Largest outer ring — the part that should carry the label.
  /// Empty only for a default-constructed instance.
  List<LatLng> get polygon => parts.isEmpty ? const <LatLng>[] : parts.first;

  Barangay copyWith({
    String? name,
    String? code,
    String? city,
    List<List<LatLng>>? parts,
    bool? seen,
    DateTime? seenAt,
    String? note,
  }) {
    return Barangay(
      name: name ?? this.name,
      code: code ?? this.code,
      city: city ?? this.city,
      parts: parts ?? this.parts,
      seen: seen ?? this.seen,
      seenAt: seenAt ?? this.seenAt,
      note: note ?? this.note,
    );
  }

  /// Point-in-polygon (ray casting) across every part. A route can cross a
  /// detached piece without ever touching the largest one, so all parts are
  /// tested.
  bool contains(LatLng point) => containsInAny(parts, point);

  /// Centroid for label placement — centroid of the largest part.
  LatLng get centroid => _ringCentroid(polygon);

  /// Bounding box covering every part.
  LatLngBounds get bounds {
    double minLat = 90, maxLat = -90, minLng = 180, maxLng = -180;
    for (final part in parts) {
      for (final p in part) {
        minLat = minLat < p.latitude ? minLat : p.latitude;
        maxLat = maxLat > p.latitude ? maxLat : p.latitude;
        minLng = minLng < p.longitude ? minLng : p.longitude;
        maxLng = maxLng > p.longitude ? maxLng : p.longitude;
      }
    }
    return LatLngBounds(LatLng(minLat, minLng), LatLng(maxLat, maxLng));
  }

  static LatLng _ringCentroid(List<LatLng> ring) {
    if (ring.isEmpty) return const LatLng(0, 0);
    double lat = 0, lng = 0;
    for (final p in ring) {
      lat += p.latitude;
      lng += p.longitude;
    }
    return LatLng(lat / ring.length, lng / ring.length);
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
