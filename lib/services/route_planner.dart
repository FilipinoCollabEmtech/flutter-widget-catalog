import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';

import '../models/route.dart';

/// Plans a journey across the jeepney network.
///
/// The real work is collecting the route polylines; this code is the simple
/// part. Algorithm:
///
///   1. Direct ride — a single route passing within ~300 m of both the
///      origin and the destination.
///   2. One transfer — two routes that share a stop or pass within ~300 m of
///      each other, with a walk to each.
///   3. Fallback — walk the whole way.
///
/// Fares are computed from distance travelled along the route, not from a
/// road graph.
class RoutePlanner {
  static const double _walkThresholdM = 300;
  static const double _transferThresholdM = 300;
  static const double _baseFare = 13.0;
  static const double _perKm = 1.50;

  final List<JeepneyRoute> routes;

  RoutePlanner(this.routes);

  /// Plan a journey between two points.
  Journey plan(Waypoint origin, Waypoint destination) {
    final direct = _direct(origin, destination);
    if (direct != null) return direct;
    final transfer = _oneTransfer(origin, destination);
    if (transfer != null) return transfer;
    return _walkFallback(origin, destination);
  }
  Journey? _direct(Waypoint origin, Waypoint destination) {
    final o = origin.point;
    final d = destination.point;
    for (final route in routes) {
      final dOrigin = route.distanceTo(o);
      final dDest = route.distanceTo(d);
      if (dOrigin > _walkThresholdM || dDest > _walkThresholdM) continue;

      final walkIn = _walkLeg(o, _closestOnRoute(o, route));
      final walkOut = _walkLeg(_closestOnRoute(d, route), d);
      final ride = _rideLeg(route, o, d);
      final legs = <JourneyLeg>[];
      if (walkIn.lengthM > 0) legs.add(walkIn);
      legs.add(ride);
      if (walkOut.lengthM > 0) legs.add(walkOut);

      final total = legs.fold<double>(0, (s, l) => s + l.lengthM);
      return Journey(
        origin: origin,
        destination: destination,
        legs: legs,
        totalDistanceM: total,
        fare: _fare(total),
      );
    }
    return null;
  }

  /// Two routes with a shared stop or close approach.
  Journey? _oneTransfer(Waypoint origin, Waypoint destination) {
    final o = origin.point;
    final d = destination.point;
    for (final a in routes) {
      final aOrigin = a.distanceTo(o);
      if (aOrigin > _walkThresholdM) continue;

      for (final b in routes) {
        if (identical(a, b)) continue;
        final bDest = b.distanceTo(d);
        if (bDest > _walkThresholdM) continue;

        final transfer = _transferPoint(a, b);
        if (transfer == null) continue;

        final legs = <JourneyLeg>[];
        final walkIn = _walkLeg(o, _closestOnRoute(o, a));
        if (walkIn.lengthM > 0) legs.add(walkIn);
        legs.add(_rideLeg(a, o, transfer));
        legs.add(_walkLeg(transfer, _closestOnRoute(transfer, b)));
        legs.add(_rideLeg(b, transfer, d));
        final walkOut = _walkLeg(_closestOnRoute(d, b), d);
        if (walkOut.lengthM > 0) legs.add(walkOut);

        final total = legs.fold<double>(0, (s, l) => s + l.lengthM);
        return Journey(
          origin: origin,
          destination: destination,
          legs: legs,
          totalDistanceM: total,
          fare: _fare(total),
        );
      }
    }
    return null;
  }

  /// Closest point on [route]'s polyline to [point].
  LatLng _closestOnRoute(LatLng point, JeepneyRoute route) {
    var best = route.polyline.first;
    var bestDist = double.infinity;
    for (final p in route.polyline) {
      final d = haversineMeters(point, p);
      if (d < bestDist) {
        bestDist = d;
        best = p;
      }
    }
    return best;
  }

  /// Where two routes come closest to each other (the transfer point).
  LatLng? _transferPoint(JeepneyRoute a, JeepneyRoute b) {
    LatLng? best;
    var bestDist = double.infinity;
    for (final pa in a.polyline) {
      for (final pb in b.polyline) {
        final d = haversineMeters(pa, pb);
        if (d < bestDist) {
          bestDist = d;
          best = pb;
        }
      }
    }
    if (best == null || bestDist > _transferThresholdM) return null;
    return best;
  }

  JourneyLeg _walkLeg(LatLng from, LatLng to) => JourneyLeg(
        mode: 'walk',
        points: [from, to],
      );

  JourneyLeg _rideLeg(JeepneyRoute route, LatLng from, LatLng to) =>
      JourneyLeg(
        mode: 'ride',
        route: route,
        points: route.polyline,
      );

  Journey _walkFallback(Waypoint origin, Waypoint destination) => Journey(
        origin: origin,
        destination: destination,
        legs: [
          JourneyLeg(mode: 'walk', points: [origin.point, destination.point]),
        ],
        totalDistanceM: haversineMeters(origin.point, destination.point),
        fare: 0,
      );

  double _fare(double distanceM) {
    if (distanceM <= 0) return 0;
    final km = distanceM / 1000;
    return _baseFare + km * _perKm;
  }
}

/// Shared route-planning state, held at the app root so the Home search and
/// the route page can read and write the same plan.
class RouteState {
  final RoutePlanner planner;
  final ValueNotifier<Journey?> current = ValueNotifier<Journey?>(null);
  final ValueNotifier<Waypoint?> origin = ValueNotifier<Waypoint?>(null);
  final ValueNotifier<Waypoint?> destination =
      ValueNotifier<Waypoint?>(null);

  RouteState(this.planner);

  void plan(Waypoint from, Waypoint to) {
    origin.value = from;
    destination.value = to;
    current.value = planner.plan(from, to);
  }
}