import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../models/barangay.dart';
import '../services/barangay_service.dart';

/// Route-aware barangay map.
///
/// - Tap the map to add route waypoints (a blue polyline connects them).
/// - Barangays the route passes through highlight automatically.
/// - Tap a highlighted barangay to mark it "seen" (adds a note).
/// - Bottom sheet lists all seen barangays.
class BarangayRoutePage extends StatefulWidget {
  const BarangayRoutePage({
    super.key,
    required this.showBarangayPolygons,
    required this.showBarangayLabels,
    required this.showRoutePolyline,
  });

  final ValueListenable<bool> showBarangayPolygons;
  final ValueListenable<bool> showBarangayLabels;
  final ValueListenable<bool> showRoutePolyline;

  @override
  State<BarangayRoutePage> createState() => _BarangayRoutePageState();
}

class _BarangayRoutePageState extends State<BarangayRoutePage> {
  final MapController _mapController = MapController();
  final BarangayService _service = BarangayService();

  final List<LatLng> _waypoints = [];
  List<Barangay> _onRoute = [];
  final Set<String> _onRouteCodes = <String>{};
  bool _addingWaypoint = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _service.barangays.addListener(_rebuildOnRoute);
    _load();
  }

  Future<void> _load() async {
    await _service.load();
    if (!mounted) return;
    setState(() => _loading = false);
    _rebuildOnRoute();
  }

  void _rebuildOnRoute() {
    final route = RoutePlan(waypoints: _waypoints);
    final hits = _service.intersectedBy(route);
    setState(() {
      _onRoute = hits;
      _onRouteCodes
        ..clear()
        ..addAll(hits.map((b) => b.code));
    });
  }

  void _toggleAdding() {
    setState(() => _addingWaypoint = !_addingWaypoint);
  }

  void _addWaypoint(LatLng point) {
    setState(() {
      _waypoints.add(point);
      _addingWaypoint = false;
    });
    _rebuildOnRoute();
  }

  void _removeWaypoint(int index) {
    setState(() => _waypoints.removeAt(index));
    _rebuildOnRoute();
  }

  void _clearRoute() {
    setState(() {
      _waypoints.clear();
      _onRoute = [];
      _onRouteCodes.clear();
    });
  }

  Future<void> _toggleSeen(Barangay b) async {
    final note = b.seen ? null : await _promptNote(b.name);
    if (note == null && !b.seen) return;
    await _service.setSeen(b.code, !b.seen, note: note);
    _rebuildOnRoute();
  }

  Future<String?> _promptNote(String name) {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Mark "$name" as seen?'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'Note (optional)',
            labelText: 'Note',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, null),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Mark'),
          ),
        ],
      ),
    );
  }

  /// True when [b] is crossed by the current route. Keyed on `ADM4_PCODE`,
  /// which is unique — so this no longer matches everything the way the old
  /// empty `code` value did.
  bool _isOnRoute(Barangay b) => _onRouteCodes.contains(b.code);

  /// Fill for a barangay body. On-route wins over "seen" so the highlight is
  /// never hidden by a previously marked barangay.
  Color _fill(Barangay b) {
    if (_isOnRoute(b)) return Colors.orange.withValues(alpha: 0.40);
    if (b.seen) return Colors.green.withValues(alpha: 0.30);
    return Colors.grey.withValues(alpha: 0.10);
  }

  /// Outline styling. Only barangays the route passes through get a heavy
  /// border; everything else stays a hairline so the map does not turn into
  /// a wall of boxes.
  ({Color color, double width}) _outline(Barangay b) {
    if (_isOnRoute(b)) {
      return (color: const Color(0xFFE65100), width: 3.5);
    }
    if (b.seen) {
      return (color: const Color(0xFF2E7D32), width: 1.5);
    }
    return (color: Colors.black.withValues(alpha: 0.30), width: 0.8);
  }

  /// Every boundary, always drawn — faint unless the route crosses it.
  ///
  /// MultiPolygon barangays contribute one [Polygon] per part, so detached
  /// pieces are outlined too instead of silently disappearing.
  List<Polygon> _boundaryPolygons() {
    final out = <Polygon>[];
    for (final b in _service.all) {
      final outline = _outline(b);
      for (final part in b.parts) {
        out.add(Polygon(
          points: part,
          color: _fill(b),
          borderColor: outline.color,
          borderStrokeWidth: outline.width,
        ));
      }
    }
    return out;
  }

  @override
  void dispose() {
    _service.barangays.removeListener(_rebuildOnRoute);
    _mapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Barangay Route'),
        actions: [
          IconButton(
            icon: Icon(_addingWaypoint ? Icons.close : Icons.add_location),
            tooltip: _addingWaypoint ? 'Stop adding' : 'Add waypoint',
            onPressed: _toggleAdding,
          ),
          IconButton(
            icon: const Icon(Icons.clear_all),
            tooltip: 'Clear route',
            onPressed: _waypoints.isEmpty ? null : _clearRoute,
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
              // Tap the map to drop a waypoint where you tapped.
              onTap: (tapPosition, point) {
                if (_addingWaypoint) _addWaypoint(point);
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.seeruta',
              ),
              ValueListenableBuilder<bool>(
                valueListenable: widget.showBarangayPolygons,
                builder: (context, showPolygons, _) {
                  if (!showPolygons) return const SizedBox.shrink();
                  return PolygonLayer(
                    polygons: _boundaryPolygons(),
                  );
                },
              ),
              ValueListenableBuilder<bool>(
                valueListenable: widget.showRoutePolyline,
                builder: (context, showRoute, _) {
                  if (!showRoute || _waypoints.length < 2) {
                    return const SizedBox.shrink();
                  }
                  return PolylineLayer(
                    polylines: [
                      Polyline(
                        points: _waypoints,
                        color: Colors.blue,
                        strokeWidth: 4,
                      ),
                    ],
                  );
                },
              ),
              MarkerLayer(
                markers: [
                  for (var i = 0; i < _waypoints.length; i++)
                    Marker(
                      point: _waypoints[i],
                      width: 30,
                      height: 30,
                      child: GestureDetector(
                        onTap: () => _removeWaypoint(i),
                        child: const Icon(
                          Icons.location_pin,
                          color: Colors.blue,
                          size: 30,
                        ),
                      ),
                    ),
                ],
              ),
              ValueListenableBuilder<bool>(
                valueListenable: widget.showBarangayLabels,
                builder: (context, showLabels, _) {
                  if (!showLabels) return const SizedBox.shrink();
                  // Only barangays the route actually crosses are labelled.
                  return MarkerLayer(
                    markers: [
                      for (final b in _onRoute)
                        Marker(
                          point: b.centroid,
                          width: 150,
                          height: 36,
                          child: GestureDetector(
                            onTap: () => _toggleSeen(b),
                            child: Container(
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: b.seen
                                    ? const Color(0xFF2E7D32)
                                    : const Color(0xFFE65100),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                  color: Colors.white,
                                  width: 1.5,
                                ),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Colors.black45,
                                    blurRadius: 4,
                                    offset: Offset(0, 1),
                                  ),
                                ],
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 3,
                              ),
                              child: Text(
                                b.name,
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  height: 1.1,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ],
          ),
          // Bottom sheet: seen list
          Positioned(
            bottom: 16,
            left: 16,
            right: 16,
            child: Material(
              color: Colors.white.withValues(alpha: 0.95),
              borderRadius: BorderRadius.circular(12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const ListTile(
                    title: Text(
                      'Seen barangays',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    trailing: Text('tap polygon to mark'),
                  ),
                  if (_service.seenList.isEmpty)
                    const ListTile(
                      title: Text('None yet — travel the route!'),
                    )
                  else
                    ..._service.seenList.map(
                      (b) => ListTile(
                        leading: const Icon(
                          Icons.check_circle,
                          color: Colors.green,
                        ),
                        title: Text(b.name),
                        subtitle: Text(
                          '${b.code}${b.note != null ? ' — ${b.note}' : ''}',
                          style: const TextStyle(fontSize: 11),
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.remove_circle_outline),
                          onPressed: () => _service.setSeen(b.code, false),
                        ),
                      ),
                    ),
                  const Divider(),
                  ListTile(
                    title: Text(
                      'On route: ${_onRoute.length}',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      '${_waypoints.length} waypoint${_waypoints.length == 1 ? '' : 's'}',
                    ),
                  ),
                ],
              ),
            ),
          ),
          // FloatingActionButton: recenter
          FloatingActionButton(
            onPressed: () {
              if (_service.all.isNotEmpty) {
                _mapController.move(_service.all.first.centroid, 13);
              }
            },
            child: const Icon(Icons.map),
          ),
        ],
      ),
    );
  }
}
