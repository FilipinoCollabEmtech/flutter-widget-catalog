import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

import 'package:seeruta/models/route.dart';
import 'package:seeruta/services/route_planner.dart';

void main() {
  group('haversineMeters', () {
    test('same point returns 0', () {
      const p = LatLng(10.3, 123.9);
      expect(haversineMeters(p, p), closeTo(0, 0.001));
    });

    test('known distance: 1 degree latitude ~ 111 km', () {
      const a = LatLng(10.0, 123.9);
      const b = LatLng(11.0, 123.9);
      final d = haversineMeters(a, b);
      expect(d, closeTo(111194.9, 1000));
    });

    test('symmetric', () {
      const a = LatLng(10.3, 123.9);
      const b = LatLng(10.4, 123.95);
      expect(haversineMeters(a, b), closeTo(haversineMeters(b, a), 0.001));
    });
  });

  group('distanceToSegment', () {
    test('point on segment returns 0', () {
      const a = LatLng(10.0, 123.9);
      const b = LatLng(10.1, 123.9);
      const p = LatLng(10.05, 123.9);
      expect(distanceToSegment(p, a, b), closeTo(0, 1));
    });

    test('point perpendicular to segment', () {
      const a = LatLng(10.0, 123.9);
      const b = LatLng(10.0, 123.91);
      const p = LatLng(10.001, 123.905);
      final d = distanceToSegment(p, a, b);
      // ~111m north of the segment
      expect(d, greaterThan(100));
      expect(d, lessThan(120));
    });

    test('point beyond endpoint uses endpoint distance', () {
      const a = LatLng(10.0, 123.9);
      const b = LatLng(10.0, 123.91);
      const p = LatLng(10.0, 123.92);
      final d = distanceToSegment(p, a, b);
      // distance to b
      expect(d, closeTo(haversineMeters(p, b), 1));
    });

    test('degenerate segment (a == b)', () {
      const a = LatLng(10.0, 123.9);
      const p = LatLng(10.001, 123.9);
      expect(distanceToSegment(p, a, a), closeTo(haversineMeters(p, a), 1));
    });
  });

  group('JeepneyRoute.distanceTo', () {
    test('point on route returns ~0', () {
      final route = JeepneyRoute(
        code: 'T1',
        name: 'Test',
        polyline: [const LatLng(10.0, 123.9), const LatLng(10.1, 123.9)],
        stops: const [],
      );
      const p = LatLng(10.05, 123.9);
      expect(route.distanceTo(p), closeTo(0, 1));
    });

    test('point far from route returns large distance', () {
      final route = JeepneyRoute(
        code: 'T1',
        name: 'Test',
        polyline: [const LatLng(10.0, 123.9), const LatLng(10.1, 123.9)],
        stops: const [],
      );
      const p = LatLng(10.5, 123.9);
      expect(route.distanceTo(p), greaterThan(40000));
    });
  });

  group('RoutePlanner', () {
    late List<JeepneyRoute> routes;

    setUp(() {
      routes = [
        // Route A: vertical line at lng 123.9, lat 10.0-10.2 (vertex at intersection)
        JeepneyRoute(
          code: 'A',
          name: 'Route A',
          polyline: [const LatLng(10.0, 123.9), const LatLng(10.1, 123.9), const LatLng(10.2, 123.9)],
          stops: const [],
        ),
        // Route B: horizontal line at lat 10.1, lng 123.9-124.0 (vertex at intersection)
        JeepneyRoute(
          code: 'B',
          name: 'Route B',
          polyline: [const LatLng(10.1, 123.9), const LatLng(10.1, 124.0)],
          stops: const [],
        ),
      ];
    });

    test('direct ride when one route serves both endpoints', () {
      final planner = RoutePlanner(routes);
      final origin = Waypoint('origin', const LatLng(10.05, 123.9));
      final dest = Waypoint('dest', const LatLng(10.15, 123.9));
      final journey = planner.plan(origin, dest);
      expect(journey.legs.length, greaterThanOrEqualTo(1));
      expect(journey.legs.any((l) => l.mode == 'ride'), isTrue);
      // Should use route A
      final rideLeg = journey.legs.firstWhere((l) => l.mode == 'ride');
      expect(rideLeg.route?.code, 'A');
    });

    test('one transfer when no single route serves both', () {
      final planner = RoutePlanner(routes);
      final origin = Waypoint('origin', const LatLng(10.0, 123.9));
      final dest = Waypoint('dest', const LatLng(10.1, 124.0));
      final journey = planner.plan(origin, dest);
      expect(journey.legs.length, greaterThanOrEqualTo(3));
      // Should have two ride legs
      final rideLegs = journey.legs.where((l) => l.mode == 'ride').toList();
      expect(rideLegs.length, 2);
    });

    test('walk fallback when no routes nearby', () {
      final planner = RoutePlanner(routes);
      final origin = Waypoint('origin', const LatLng(15.0, 120.0));
      final dest = Waypoint('dest', const LatLng(15.1, 120.1));
      final journey = planner.plan(origin, dest);
      expect(journey.legs.length, 1);
      expect(journey.legs.first.mode, 'walk');
    });

    test('empty routes list gives walk fallback', () {
      final planner = RoutePlanner([]);
      final origin = Waypoint('origin', const LatLng(10.0, 123.9));
      final dest = Waypoint('dest', const LatLng(10.1, 123.9));
      final journey = planner.plan(origin, dest);
      expect(journey.legs.first.mode, 'walk');
    });

    test('total distance is positive', () {
      final planner = RoutePlanner(routes);
      final origin = Waypoint('origin', const LatLng(10.0, 123.9));
      final dest = Waypoint('dest', const LatLng(10.1, 123.9));
      final journey = planner.plan(origin, dest);
      expect(journey.totalDistanceM, greaterThan(0));
    });
  });

  group('JourneyLeg', () {
    test('lengthM for walk leg', () {
      const leg = JourneyLeg(
        mode: 'walk',
        points: [LatLng(10.0, 123.9), LatLng(10.1, 123.9)],
      );
      expect(leg.lengthM, closeTo(11119.5, 100));
    });

    test('lengthM for single point is 0', () {
      const leg = JourneyLeg(
        mode: 'walk',
        points: [LatLng(10.0, 123.9)],
      );
      expect(leg.lengthM, 0);
    });

    test('lengthM for empty is 0', () {
      const leg = JourneyLeg(
        mode: 'walk',
        points: [],
      );
      expect(leg.lengthM, 0);
    });
  });

  group('RouteState', () {
    test('plan updates notifiers', () {
      final planner = RoutePlanner([]);
      final state = RouteState(planner);
      final origin = Waypoint('origin', const LatLng(10.0, 123.9));
      final dest = Waypoint('dest', const LatLng(10.1, 123.9));
      state.plan(origin, dest);
      expect(state.origin.value, origin);
      expect(state.destination.value, dest);
      expect(state.current.value, isNotNull);
    });
  });
}