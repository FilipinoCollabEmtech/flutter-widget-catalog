import 'dart:async';

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart' as ll;
import 'package:maplibre_gl/maplibre_gl.dart' as ml;

import '../models/barangay.dart';
import '../services/barangay_service.dart';
import 'cebu_boundary_layer.dart' show kCebuOutline;
import 'offline_map_assets.dart';

/// Route-aware barangay map using the same offline MapLibre map as Home.
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
  final BarangayService _service = BarangayService();
  final List<ll.LatLng> _waypoints = [];
  List<Barangay> _onRoute = [];
  final Set<String> _onRouteCodes = <String>{};
  bool _addingWaypoint = false;
  bool _loading = true;

  OfflineMapPaths? _paths;
  ml.MapLibreMapController? _controller;
  ml.Line? _routeLine;
  final List<ml.Circle> _waypointCircles = [];
  final Map<String, ml.Fill> _highlightFills = {};
  final Map<String, ml.Line> _highlightLines = {};
  final List<ml.Symbol> _labelSymbols = [];

  bool _layersAdded = false;

  static const String _maskSrc = 'cebu-mask';
  static const String _outsideHex = '#E6E8EB';

  @override
  void initState() {
    super.initState();
    _prepareMap();
    _service.barangays.addListener(_rebuildOnRoute);
    _load();
  }

  Future<void> _prepareMap() async {
    try {
      final paths = await OfflineMapAssets.prepare();
      if (!mounted) return;
      setState(() => _paths = paths);
    } catch (e) {
      debugPrint('BarangayRoutePage: prepare failed: $e');
      if (!mounted) return;
      setState(() => _paths = null);
    }
  }

  Future<void> _load() async {
    try {
      await _service.load();
    } catch (e) {
      debugPrint('Barangay load failed: $e');
    }
    if (!mounted) return;
    setState(() => _loading = false);
    _rebuildOnRoute();
    _tryAddBarangayLayers();
  }

  void _onMapCreated(ml.MapLibreMapController controller) {
    _controller = controller;
    debugPrint('BarangayRoutePage: map created');
    _tryAddBarangayLayers();
    _updateRouteOverlays();
  }

  Future<void> _onStyleLoaded() async {
    final c = _controller;
    if (c == null) return;
    try {
      await c.addGeoJsonSource(_maskSrc, _maskGeoJson());
      await c.addFillLayer(
        _maskSrc,
        'cebu-mask-fill',
        ml.FillLayerProperties(fillColor: _outsideHex, fillAntialias: true),
      );
      await c.addLineLayer(
        _maskSrc,
        'cebu-mask-feather',
        ml.LineLayerProperties(
          lineColor: _outsideHex,
          lineWidth: 28,
          lineBlur: 20,
          lineJoin: 'round',
        ),
      );
    } catch (e) {
      debugPrint('Failed to add boundary mask: $e');
    }
    // Now that the style is ready, add barangay layers if service has loaded.
    _tryAddBarangayLayers();
  }

  void _tryAddBarangayLayers() {
    if (_controller == null || _service.all.isEmpty || _layersAdded) return;
    _addBarangayLayers();
  }

  static Map<String, dynamic> _maskGeoJson() {
    final hole = _chaikin(
      [for (final p in kCebuOutline) [p.longitude, p.latitude]],
      2,
    );
    return {
      'type': 'FeatureCollection',
      'features': [
        {
          'type': 'Feature',
          'properties': <String, Object>{},
          'geometry': {
            'type': 'Polygon',
            'coordinates': [
              [
                [-180.0, -85.0],
                [180.0, -85.0],
                [180.0, 85.0],
                [-180.0, 85.0],
                [-180.0, -85.0],
              ],
              hole,
            ],
          },
        },
      ],
    };
  }

  static List<List<double>> _chaikin(List<List<double>> points, int rounds) {
    var current = points;
    for (var r = 0; r < rounds; r++) {
      final next = <List<double>>[];
      for (var i = 0; i < current.length; i++) {
        final a = current[i];
        final b = current[(i + 1) % current.length];
        next.add([0.75 * a[0] + 0.25 * b[0], 0.75 * a[1] + 0.25 * b[1]]);
        next.add([0.25 * a[0] + 0.75 * b[0], 0.25 * a[1] + 0.75 * b[1]]);
      }
      current = next;
    }
    return [...current, current.first];
  }

  Future<void> _addBarangayLayers() async {
    final c = _controller;
    if (c == null || _service.all.isEmpty || _layersAdded) return;
    _layersAdded = true;

    try {
      // Build GeoJSON.
      final features = <Map<String, dynamic>>[];
      for (final b in _service.all) {
        for (final part in b.parts) {
          features.add({
            'type': 'Feature',
            'properties': {'code': b.code, 'name': b.name},
            'geometry': {
              'type': 'Polygon',
              'coordinates': [part.map((p) => [p.longitude, p.latitude]).toList()],
            },
          });
        }
      }

      await c.addGeoJsonSource('barangays', {
        'type': 'FeatureCollection',
        'features': features,
      });

      await c.addFillLayer(
        'barangays',
        'barangay-fill',
        ml.FillLayerProperties(
          fillColor: '#808080',
          fillOpacity: 0.1,
        ),
      );

      await c.addLineLayer(
        'barangays',
        'barangay-border',
        ml.LineLayerProperties(
          lineColor: '#000000',
          lineWidth: 0.8,
          lineOpacity: 0.3,
        ),
      );
    } catch (e) {
      debugPrint('Failed to add barangay layers: $e');
      _layersAdded = false;
    }
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
    _updateHighlight();
    _updateRouteOverlays();
  }

  Future<void> _updateHighlight() async {
    final c = _controller;
    if (c == null) return;

    // Remove old highlights.
    for (final f in _highlightFills.values) { await c.removeFill(f); }
    for (final l in _highlightLines.values) { await c.removeLine(l); }
    for (final s in _labelSymbols) { await c.removeSymbol(s); }
    _highlightFills.clear();
    _highlightLines.clear();
    _labelSymbols.clear();

    // Add highlight for on-route barangays.
    for (final b in _onRoute) {
      for (final part in b.parts) {
        final mlPart = part.map((p) => ml.LatLng(p.latitude, p.longitude)).toList();
        final fill = await c.addFill(ml.FillOptions(
          geometry: [mlPart],
          fillColor: '#FF8C00',
          fillOpacity: 0.4,
        ));
        _highlightFills['${b.code}_${part.hashCode}'] = fill;

        final line = await c.addLine(ml.LineOptions(
          geometry: mlPart,
          lineColor: '#E65100',
          lineWidth: 3.5,
        ));
        _highlightLines['${b.code}_${part.hashCode}'] = line;
      }
      // Add name label at centroid.
      final symbol = await c.addSymbol(ml.SymbolOptions(
        geometry: ml.LatLng(b.centroid.latitude, b.centroid.longitude),
        textField: b.name,
        textSize: 12.0,
        textColor: '#FFFFFF',
        textHaloColor: '#000000',
        textHaloWidth: 1.5,
      ));
      _labelSymbols.add(symbol);
    }
  }

  Future<void> _updateRouteOverlays() async {
    final c = _controller;
    if (c == null) return;

    // Remove old route line.
    if (_routeLine != null) {
      await c.removeLine(_routeLine!);
      _routeLine = null;
    }
    // Remove old waypoint circles.
    for (final wc in _waypointCircles) { await c.removeCircle(wc); }
    _waypointCircles.clear();

    // Add route polyline.
    if (_waypoints.length >= 2) {
      _routeLine = await c.addLine(ml.LineOptions(
        geometry: _waypoints.map((p) => ml.LatLng(p.latitude, p.longitude)).toList(),
        lineColor: '#0000FF',
        lineWidth: 4.0,
      ));
    }

    // Add waypoint markers.
    for (final wp in _waypoints) {
      final circle = await c.addCircle(ml.CircleOptions(
        geometry: ml.LatLng(wp.latitude, wp.longitude),
        circleRadius: 8.0,
        circleColor: '#0000FF',
        circleStrokeWidth: 2.0,
        circleStrokeColor: '#FFFFFF',
      ));
      _waypointCircles.add(circle);
    }
  }

  void _toggleAdding() {
    setState(() => _addingWaypoint = !_addingWaypoint);
  }

  Future<void> _addWaypoint(ll.LatLng point) async {
    setState(() {
      _waypoints.add(point);
      _addingWaypoint = false;
    });
    _rebuildOnRoute();
  }



  Future<void> _clearRoute() async {
    setState(() {
      _waypoints.clear();
      _onRoute = [];
      _onRouteCodes.clear();
    });
    if (_controller != null) {
      for (final s in _labelSymbols) {
        await _controller!.removeSymbol(s);
      }
      _labelSymbols.clear();
    }
    await _updateHighlight();
    await _updateRouteOverlays();
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

  @override
  void dispose() {
    _service.barangays.removeListener(_rebuildOnRoute);
    _controller?.dispose();
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
          if (_paths == null)
            const Center(child: CircularProgressIndicator())
          else
            ml.MapLibreMap(
              styleString: _paths!.stylePath,
              initialCameraPosition: ml.CameraPosition(
                target: ml.LatLng(10.3157, 123.8854),
                zoom: 12,
              ),
              onMapCreated: _onMapCreated,
              onStyleLoadedCallback: _onStyleLoaded,
              featureTapsTriggersMapClick: true,
              onMapClick: (point, coords) {
                debugPrint('BarangayRoutePage: tap at ${coords.latitude}, ${coords.longitude}');
                if (_addingWaypoint) {
                  _addWaypoint(ll.LatLng(coords.latitude, coords.longitude));
                } else {
                  // Find tapped barangay.
                  String? hitCode;
                  for (final b in _service.all) {
                    if (b.contains(ll.LatLng(coords.latitude, coords.longitude))) {
                      hitCode = b.code;
                      break;
                    }
                  }
                  if (hitCode != null) {
                    debugPrint('BarangayRoutePage: hit $hitCode');
                    final b = _service.all.firstWhere((x) => x.code == hitCode);
                    _toggleSeen(b);
                  } else {
                    debugPrint('BarangayRoutePage: no barangay hit');
                  }
                }
              },
              trackCameraPosition: true,
              onCameraMove: (camera) {},
            ),
          // Labels for on-route barangays.
          ValueListenableBuilder<bool>(
            valueListenable: widget.showBarangayLabels,
            builder: (context, showLabels, _) {
              if (!showLabels || _onRoute.isEmpty) {
                return const SizedBox.shrink();
              }
              // Labels are handled by the map's symbol layer if added.
              // For now, show them as a floating list.
              return const SizedBox.shrink();
            },
          ),
          // Bottom sheet: seen list.
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
                  ListTile(
                    title: const Text(
                      'Seen barangays',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    trailing: const Text('tap polygon to mark'),
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
        ],
      ),
    );
  }
}