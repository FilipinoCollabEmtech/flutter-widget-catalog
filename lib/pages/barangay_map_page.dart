import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../models/barangay.dart';
import '../services/barangay_service.dart';

/// A barangay territory map.
///
/// Loads `assets/maps/barangays.geojson` through [BarangayService] — the same
/// loader the route page uses, so names, keys and MultiPolygon parts are
/// resolved identically here — and renders them as coloured polygons with
/// labels.
class BarangayMapPage extends StatefulWidget {
  const BarangayMapPage({super.key});

  @override
  State<BarangayMapPage> createState() => _BarangayMapPageState();
}

class _BarangayMapPageState extends State<BarangayMapPage> {
  final MapController _mapController = MapController();
  final BarangayService _service = BarangayService();

  String? _selectedCode;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadBarangays();
  }

  Future<void> _loadBarangays() async {
    try {
      await _service.load();
      if (!mounted) return;

      setState(() {
        _loading = false;
      });

      if (_service.all.isNotEmpty) {
        _mapController.move(_service.all.first.centroid, 13);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Barangay? get _selected {
    final code = _selectedCode;
    if (code == null) return null;
    for (final b in _service.all) {
      if (b.code == code) return b;
    }
    return null;
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

  /// One [Polygon] per outer ring, so MultiPolygon barangays are drawn in
  /// full instead of only their largest piece.
  List<Polygon> _polygons() {
    final out = <Polygon>[];
    var i = 0;
    for (final b in _service.all) {
      final selected = b.code == _selectedCode;
      for (final part in b.parts) {
        out.add(Polygon(
          points: part,
          color: _barangayColor(i),
          borderColor: selected ? Colors.black : Colors.black.withValues(alpha: 0.4),
          borderStrokeWidth: selected ? 3 : 1,
        ));
      }
      i++;
    }
    return out;
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

    final sel = _selected;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Barangay Map'),
        actions: [
          IconButton(
            icon: const Icon(Icons.my_location),
            onPressed: () {
              if (_service.all.isNotEmpty) {
                _mapController.move(_service.all.first.centroid, 13);
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
              onTap: (tapPosition, point) {
                // Point-in-polygon across every part of every barangay.
                String? hitCode;
                for (final b in _service.all) {
                  if (b.contains(point)) {
                    hitCode = b.code;
                    break;
                  }
                }
                setState(() => _selectedCode = hitCode);
              },
            ),
            children: [
              TileLayer(
                urlTemplate:
                    'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.seeruta',
              ),
              // Barangay polygons — every boundary, MultiPolygon included.
              PolygonLayer(polygons: _polygons()),
              // Labels at centroid
              MarkerLayer(
                markers: [
                  for (final b in _service.all)
                    Marker(
                      point: b.centroid,
                      width: 130,
                      height: 34,
                      child: GestureDetector(
                        onTap: () {
                          setState(() => _selectedCode = b.code);
                          _mapController.move(b.centroid, 15);
                        },
                        child: Container(
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: b.code == _selectedCode
                                ? Colors.black.withValues(alpha: 0.85)
                                : Colors.black.withValues(alpha: 0.6),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          child: Text(
                            '${b.name}\n${b.city}',
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              height: 1.1,
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
          if (sel != null)
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        sel.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        '${sel.city} · ${sel.code}',
                        style: const TextStyle(fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => setState(() => _selectedCode = null),
        child: const Icon(Icons.clear),
      ),
    );
  }
}
