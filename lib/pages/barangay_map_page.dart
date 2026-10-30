import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:latlong2/latlong.dart';

/// A simple barangay territory map.
///
/// Loads barangay polygons from assets/maps/barangays.geojson (GeoJSON
/// FeatureCollection) and renders them as colored polygons with labels.
///
/// Place your GeoJSON file at:
///   assets/maps/barangays.geojson
///
/// Example GeoJSON structure expected:
/// {
///   "type": "FeatureCollection",
///   "features": [
///     {
///       "type": "Feature",
///       "properties": {"name": "Barangay San Roque", "code": "123"},
///       "geometry": {
///         "type": "Polygon",
///         "coordinates": [[[123.8, 10.3], [123.9, 10.3], ...]]
///       }
///     }
///   ]
/// }
class BarangayMapPage extends StatefulWidget {
  const BarangayMapPage({super.key});

  @override
  State<BarangayMapPage> createState() => _BarangayMapPageState();
}

class _BarangayMapPageState extends State<BarangayMapPage> {
  final MapController _mapController = MapController();

  List<BarangayFeature> _barangays = [];
  String? _selectedName;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadBarangays();
  }

  Future<void> _loadBarangays() async {
    try {
      final jsonString = await rootBundle.loadString(
        'assets/maps/barangays.geojson',
      );
      final decoded = jsonDecode(jsonString) as Map<String, dynamic>;

      final features = <BarangayFeature>[];
      final List<dynamic> featureList = decoded['features'] ?? [];

      for (final f in featureList) {
        final props = (f['properties'] ?? <String, dynamic>{}) as Map;
        final geom = f['geometry'] as Map<String, dynamic>;
        final type = geom['type'] as String?;
        final coords = geom['coordinates'] as List<dynamic>?;

        if (type != 'Polygon' || coords == null) continue;

        final rings = <List<LatLng>>[];
        for (final ring in coords) {
          final points = <LatLng>[];
          for (final pt in ring) {
            if (pt is List && pt.length >= 2) {
              points.add(LatLng(pt[1] as double, pt[0] as double));
            }
          }
          if (points.isNotEmpty) rings.add(points);
        }

        if (rings.isNotEmpty) {
          features.add(BarangayFeature(
            name: (props['name'] ?? props['brgy'] ?? 'Barangay').toString(),
            code: (props['code'] ?? props['psgc'] ?? '').toString(),
            polygon: rings.first, // outer ring only
          ));
        }
      }

      if (!mounted) return;

      setState(() {
        _barangays = features;
        _loading = false;
      });

      if (features.isNotEmpty) {
        // Center map on the first barangay's centroid
        final center = _centroid(features.first.polygon);
        _mapController.move(center, 13);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  LatLng _centroid(List<LatLng> points) {
    double lat = 0, lng = 0;
    for (final p in points) {
      lat += p.latitude;
      lng += p.longitude;
    }
    final n = points.length;
    return LatLng(lat / n, lng / n);
  }

  Color _barangayColor(int index) {
    final colors = [
      Colors.blue.withValues(alpha: 0.35),
      Colors.green.withValues(alpha: 0.35),
      Colors.orange.withValues(alpha: 0.35),
      Colors.red.withValues(alpha: 0.35),
      Colors.purple.withValues(alpha: 0.35),
      Colors.teal.withValues(alpha: 0.35),
      Colors.amber.withValues(alpha: 0.35),
      Colors.pink.withValues(alpha: 0.35),
    ];
    return colors[index % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 48),
              const SizedBox(height: 8),
              Text('$_error', textAlign: TextAlign.center),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadBarangays,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Barangay Map'),
        actions: [
          IconButton(
            icon: const Icon(Icons.my_location),
            onPressed: () {
              if (_barangays.isNotEmpty) {
                _mapController.move(_centroid(_barangays.first.polygon), 13);
              }
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: const LatLng(10.3157, 123.8854),
              initialZoom: 12,
              onPositionChanged: (position, hasGesture) {},
              onTap: (tapPosition, point) {
                // Simple point-in-polygon check on outer ring
                String? hitName;
                for (final b in _barangays) {
                  if (_pointInPolygon(point, b.polygon)) {
                    hitName = b.name;
                    break;
                  }
                }
                setState(() {
                  _selectedName = hitName;
                });
              },
            ),
            children: [
              TileLayer(
                urlTemplate:
                    'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.seeruta',
              ),
              // Barangay polygons
              PolygonLayer(
                polygons: [
                  for (var i = 0; i < _barangays.length; i++)
                    Polygon(
                      points: _barangays[i].polygon,
                      color: _barangayColor(i),
                      borderColor: _selectedName == _barangays[i].name
                          ? Colors.black
                          : Colors.black.withValues(alpha: 0.4),
                      borderStrokeWidth: _selectedName == _barangays[i].name
                          ? 3
                          : 1,
                    ),
                ],
              ),
              // Labels at centroid
              MarkerLayer(
                markers: [
                  for (final b in _barangays)
                    Marker(
                      point: _centroid(b.polygon),
                      width: 120,
                      height: 24,
                      child: GestureDetector(
                        onTap: () {
                          setState(() => _selectedName = b.name);
                          _mapController.move(_centroid(b.polygon), 15);
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.6),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          child: Text(
                            '${b.name}\n${b.code}',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
          // Selected readout
          if (_selectedName != null)
            Positioned(
              top: 16,
              left: 16,
              child: Material(
                color: Colors.white.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  child: Text(
                    'Selected: $_selectedName',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => setState(() => _selectedName = null),
        child: const Icon(Icons.clear),
      ),
    );
  }
}

/// Simple point-in-polygon (ray casting) test for LatLng points.
bool _pointInPolygon(LatLng point, List<LatLng> polygon) {
  bool inside = false;
  final n = polygon.length;
  for (int i = 0, j = n - 1; i < n; j = i++) {
    final pi = polygon[i];
    final pj = polygon[j];
    if ((pi.longitude > point.longitude) !=
        (pj.longitude > point.longitude)) {
      final slope =
          (pj.latitude - pi.latitude) /
          (pj.longitude - pi.longitude);
      if (point.latitude <
          pi.latitude + slope * (point.longitude - pi.longitude)) {
        inside = !inside;
      }
    }
  }
  return inside;
}

/// A single barangay feature loaded from GeoJSON.
class BarangayFeature {
  final String name;
  final String code;
  final List<LatLng> polygon;

  BarangayFeature({
    required this.name,
    required this.code,
    required this.polygon,
  });
}
