import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';

import '../models/route.dart';

/// Loads the bundled jeepney route table (`assets/data/jeepney_routes.json`)
/// and turns it into [JeepneyRoute]s.
///
/// File format — an array of route objects:
///
/// ```json
/// [
///   {
///     "code": "04L",
///     "name": "04L Lapu-Lapu – Colon",
///     "polyline": [[123.8853, 10.3134], [123.8860, 10.3140], ...],
///     "stops": [[123.8853, 10.3134], ...],
///     "stopNames": ["Colon", " ..."]
///   }
/// ]
/// ```
///
/// Each polyline point is `[lng, lat]` — WGS84, same order as the barangay
/// GeoJSON. Routes are fixed polylines, not road graphs, so a road router
/// would give wrong answers here.
class RouteLoader {
  RouteLoader._();

  /// Parse the JSON text into routes. Malformed entries are skipped with a
  /// debugPrint so one bad route cannot break the whole network.
  static List<JeepneyRoute> fromJsonString(String raw) {
    final decoded = jsonDecode(raw);
    if (decoded is! List) return const [];

    final routes = <JeepneyRoute>[];
    for (final entry in decoded) {
      if (entry is! Map) continue;
      final map = entry.cast<String, dynamic>();
      try {
        final route = _parseRoute(map);
        if (route != null) routes.add(route);
      } catch (e) {
        debugPrint('route_loader: skipping route: $e');
      }
    }
    return routes;
  }

  static JeepneyRoute? _parseRoute(Map<String, dynamic> map) {
    final code = (map['code'] ?? '').toString().trim();
    final name = (map['name'] ?? code).toString().trim();
    if (code.isEmpty) {
      throw FormatException('route missing code: $map');
    }

    final polyline = _points(map['polyline']);
    final stops = _points(map['stops']);
    final stopNames = _strings(map['stopNames']);

    // Routes without geometry are still loaded so their codes appear in the
    // researcher dropdown and the planner can list them. Geometry is filled in
    // later via the recorder.
    return JeepneyRoute(
      code: code,
      name: name,
      polyline: polyline,
      stops: stops,
      stopNames: stopNames,
    );
  }

  static List<LatLng> _points(dynamic value) {
    if (value is! List) return const [];
    final out = <LatLng>[];
    for (final pair in value) {
      if (pair is! List || pair.length < 2) continue;
      final lng = pair[0];
      final lat = pair[1];
      if (lng is num && lat is num) {
        out.add(LatLng(lat.toDouble(), lng.toDouble()));
      }
    }
    return out;
  }

  static List<String> _strings(dynamic value) {
    if (value is! List) return const [];
    return value.map((e) => e.toString()).toList();
  }
}