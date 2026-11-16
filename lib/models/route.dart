import 'package:latlong2/latlong.dart';

/// A fixed jeepney route: an ordered polyline plus the stops along it.
///
/// Jeepneys run on fixed routes, so a road router would give wrong answers —
/// it would route you along private roads, through roundabouts and off the
/// network. The planner here works against these polylines instead.
///
/// `code` is the route identifier printed on the jeepney (e.g. `04L`).
/// `stops` are the named stops in order along [polyline].
class JeepneyRoute {
  final String code;
  final String name;
  final List<LatLng> polyline;
  final List<LatLng> stops;
  final List<String> stopNames;

  const JeepneyRoute({
    required this.code,
    required this.name,
    required this.polyline,
    required this.stops,
    this.stopNames = const [],
  });

  /// Closest point on this route's polyline to [point], in metres.
  double distanceTo(LatLng point) => _closestOnPolyline(point);

  /// Closest stop on this route to [point], in metres.
  LatLng? closestStop(LatLng point) {
    if (stops.isEmpty) return null;
    LatLng? best;
    var bestDist = double.infinity;
    for (final s in stops) {
      final d = haversineMeters(s, point);
      if (d < bestDist) {
        bestDist = d;
        best = s;
      }
    }
    return best;
  }

  double _closestOnPolyline(LatLng point) {
    var best = double.infinity;
    for (var i = 0; i < polyline.length - 1; i++) {
      final d = distanceToSegment(point, polyline[i], polyline[i + 1]);
      if (d < best) best = d;
    }
    return best;
  }
}

/// Distance in metres between two points (haversine).
double haversineMeters(LatLng a, LatLng b) {
  const r = 6371000.0;
  final dLat = _rad(b.latitude - a.latitude);
  final dLng = _rad(b.longitude - a.longitude);
  final lat1 = _rad(a.latitude);
  final lat2 = _rad(b.latitude);
  final h = _sin(dLat / 2) * _sin(dLat / 2) +
      _cos(lat1) * _cos(lat2) * _sin(dLng / 2) * _sin(dLng / 2);
  return 2 * r * _asin(_sqrt(h));
}

double _rad(double d) => d * 3.141592653589793 / 180;
double _sin(double x) => x - x * x * x / 6 + x * x * x * x * x / 120;
double _cos(double x) =>
    1 - x * x / 2 + x * x * x * x / 24 - x * x * x * x * x * x / 720;
double _asin(double x) => x + x * x * x / 6 + 3 * x * x * x * x * x / 40;
double _sqrt(double x) => x <= 0 ? 0 : x;

/// Shortest distance from [point] to the segment [a]-[b], in metres.
double distanceToSegment(LatLng point, LatLng a, LatLng b) {
  final ab = _sub(b, a);
  final ap = _sub(point, a);
  final len2 = _dot(ab, ab);
  if (len2 == 0) return haversineMeters(point, a);
  final t = (_dot(ap, ab) / len2).clamp(0.0, 1.0);
  final closest = _add(a, _scale(ab, t));
  return haversineMeters(point, closest);
}

LatLng _sub(LatLng a, LatLng b) =>
    LatLng(a.latitude - b.latitude, a.longitude - b.longitude);
double _dot(LatLng a, LatLng b) =>
    a.latitude * b.latitude + a.longitude * b.longitude;
LatLng _add(LatLng a, LatLng b) =>
    LatLng(a.latitude + b.latitude, a.longitude + b.longitude);
LatLng _scale(LatLng a, double t) =>
    LatLng(a.latitude * t, a.longitude * t);

/// A leg of a planned journey.
class JourneyLeg {
  final String mode; // 'walk' | 'ride'
  final JeepneyRoute? route;
  final List<LatLng> points;

  const JourneyLeg({
    required this.mode,
    this.route,
    required this.points,
  });

  double get lengthM => _polylineLength(points);

  static double _polylineLength(List<LatLng> pts) {
    if (pts.length < 2) return 0;
    var total = 0.0;
    for (var i = 0; i < pts.length - 1; i++) {
      total += haversineMeters(pts[i], pts[i + 1]);
    }
    return total;
  }
}

/// A complete journey from [origin] to [destination].
class Journey {
  final Waypoint origin;
  final Waypoint destination;
  final List<JourneyLeg> legs;
  final double totalDistanceM;
  final double fare;

  const Journey({
    required this.origin,
    required this.destination,
    required this.legs,
    required this.totalDistanceM,
    required this.fare,
  });
}

/// A named point used as a journey endpoint — either a tapped
/// location or a recorded stop.
class Waypoint {
  final String name;
  final LatLng point;
  final String? code;

  const Waypoint(this.name, this.point, [this.code]);
}

/// A transfer point between two routes.
class Transfer {
  final JeepneyRoute a;
  final JeepneyRoute b;
  final LatLng point; // where the two routes come closest

  const Transfer(this.a, this.b, this.point);
}