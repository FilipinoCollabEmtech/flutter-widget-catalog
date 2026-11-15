import 'dart:math' as math;

import 'package:latlong2/latlong.dart';

/// GeoJSON parsing helpers shared by the barangay loader and the barangay map.
///
/// `assets/maps/barangays.geojson` is an ADM4/PSGC hybrid. Names live under
/// `psgc_name` (the OCHA variant is `ADM4_EN`), the unique identifier is
/// `ADM4_PCODE`, and the city/municipality is `ADM3_EN`. Earlier revisions of
/// the file used `name`/`code` (or `brgy`/`psgc`), so every lookup below still
/// tries those instead of failing to a blank value.

/// Barangay display name keys, most authoritative first.
const kNameKeys = ['psgc_name', 'name', 'brgy', 'ADM4_EN'];

/// Primary key. `ADM4_PCODE` is unique across all 1,203 features; `psgc_code`
/// is not (3 codes are shared by 7 Cebu City records), so it comes second.
const kKeyKeys = ['ADM4_PCODE', 'psgc_code', 'code', 'psgc', 'ADM4_REF'];

/// City / municipality — barangay names repeat across LGUs, so this is needed
/// to tell two identically-named barangays apart.
const kCityKeys = ['ADM3_EN', 'city', 'municipality'];

/// Returns the first key whose value is a usable non-blank string.
String? firstString(dynamic props, List<String> keys) {
  if (props is! Map) return null;
  for (final key in keys) {
    final value = props[key];
    if (value == null) continue;
    final text = value.toString().trim();
    if (text.isEmpty || text == 'null' || text == 'NULL' || text == 'None') {
      continue;
    }
    return text;
  }
  return null;
}

/// Converts a GeoJSON position `[lng, lat]` into a [LatLng].
/// Returns null for malformed or non-numeric positions instead of throwing.
LatLng? toLatLng(dynamic position) {
  if (position is! List || position.length < 2) return null;
  final lng = position[0];
  final lat = position[1];
  if (lng is! num || lat is! num) return null;
  return LatLng(lat.toDouble(), lng.toDouble());
}

/// Converts a GeoJSON linear ring (`[[lng, lat], ...]`) into [LatLng]s,
/// dropping malformed positions.
List<LatLng> ringToLatLng(dynamic ring) {
  final points = <LatLng>[];
  if (ring is! List) return points;
  for (final position in ring) {
    final point = toLatLng(position);
    if (point != null) points.add(point);
  }
  return points;
}

/// Area of a closed ring in square metres (shoelace over a local
/// equirectangular projection). Accurate enough to rank rings by size at
/// barangay scale.
double ringAreaSqM(List<LatLng> ring) {
  if (ring.length < 3) return 0;
  final meanLat =
      ring.fold<double>(0, (sum, p) => sum + p.latitude) / ring.length;
  final mPerDegLat = 111320.0;
  final mPerDegLng = 111320.0 * math.cos(meanLat * math.pi / 180);

  double area = 0;
  for (var i = 0, j = ring.length - 1; i < ring.length; j = i++) {
    final xi = ring[i].longitude * mPerDegLng;
    final yi = ring[i].latitude * mPerDegLat;
    final xj = ring[j].longitude * mPerDegLng;
    final yj = ring[j].latitude * mPerDegLat;
    area += xj * yi - xi * yj;
  }
  return (area / 2).abs();
}

/// Returns every outer ring of a GeoJSON Polygon or MultiPolygon
/// `coordinates` value, largest first. Empty when the geometry is unreadable.
///
/// Polygon:      `coordinates = [outerRing, hole, ...]`
/// MultiPolygon: `coordinates = [[outerRing, hole, ...], ...]`
///
/// Interior rings (holes) are ignored — barangay boundaries in this dataset
/// have none, and a hole must not be filled as territory.
List<List<LatLng>> outerRingsOf(String? type, dynamic coordinates) {
  if (coordinates is! List || coordinates.isEmpty) return const [];

  final List<dynamic> polygons;
  switch (type) {
    case 'Polygon':
      polygons = [coordinates];
    case 'MultiPolygon':
      polygons = coordinates;
    default:
      return const [];
  }

  final rings = <List<LatLng>>[];
  for (final polygon in polygons) {
    if (polygon is! List || polygon.isEmpty) continue;
    final ring = ringToLatLng(polygon.first);
    if (ring.length >= 3) rings.add(ring);
  }

  rings.sort((a, b) => ringAreaSqM(b).compareTo(ringAreaSqM(a)));
  return rings;
}

/// True when any [parts] ring contains [point] (ray casting).
///
/// Multi-part features must be tested against every part: a route can cross a
/// detached piece without ever touching the largest one.
bool containsInAny(List<List<LatLng>> parts, LatLng point) {
  for (final part in parts) {
    if (ringContains(part, point)) return true;
  }
  return false;
}

/// Ray-casting point-in-polygon test against a single closed ring.
bool ringContains(List<LatLng> ring, LatLng point) {
  final n = ring.length;
  if (n < 3) return false;

  bool inside = false;
  for (int i = 0, j = n - 1; i < n; j = i++) {
    final pi = ring[i];
    final pj = ring[j];
    if ((pi.longitude > point.longitude) != (pj.longitude > point.longitude)) {
      final slope = (pj.latitude - pi.latitude) / (pj.longitude - pi.longitude);
      final crossing =
          point.latitude < slope * (point.longitude - pi.longitude) + pi.latitude;
      if (crossing != inside) inside = !inside;
    }
  }
  return inside;
}
