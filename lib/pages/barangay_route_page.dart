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
    setState(() => _onRoute = _service.intersectedBy(route));
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
      _onRoute.clear();
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

  Color _barangayColor(Barangay b) {
    if (b.seen) return Colors.green.withValues(alpha: 0.5);
    if (_onRoute.any((o) => o.code == b.code)) {
      return Colors.orange.withValues(alpha: 0.45);
    }
    return Colors.grey.withValues(alpha: 0.15);
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
                    polygons: [
                      for (var i = 0; i < _service.all.length; i++)
                        Polygon(
                          points: _service.all[i].polygon,
                          color: _barangayColor(_service.all[i]),
                          borderColor: Colors.black.withValues(alpha: 0.35),
                          borderStrokeWidth: 1,
                        ),
                    ],
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
                  return MarkerLayer(
                    markers: [
                      for (final b in _onRoute)
                        Marker(
                          point: b.centroid,
                          width: 100,
                          height: 22,
                          child: GestureDetector(
                            onTap: () => _toggleSeen(b),
                            child: Container(
                              decoration: BoxDecoration(
                                color: b.seen ? Colors.green : Colors.orange,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              child: Text(
                                b.name,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
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
