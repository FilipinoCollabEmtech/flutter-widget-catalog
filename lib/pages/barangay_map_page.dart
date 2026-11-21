import 'package:material_ui/material_ui.dart';
import 'package:latlong2/latlong.dart' as ll;
import 'package:maplibre_gl/maplibre_gl.dart' as ml;

import '../models/barangay.dart';
import '../services/barangay_service.dart';
import 'offline_map_assets.dart';

/// Barangay territory map using the same offline MapLibre map as the Home tab.
/// Uses a single GeoJSON source + layers for GPU-accelerated rendering.
class BarangayMapPage extends StatefulWidget {
  const BarangayMapPage({super.key});

  @override
  State<BarangayMapPage> createState() => _BarangayMapPageState();
}

class _BarangayMapPageState extends State<BarangayMapPage> {
  final BarangayService _service = BarangayService();

  OfflineMapPaths? _paths;
  ml.MapLibreMapController? _controller;

  String? _selectedCode;
  bool _loading = true;
  String? _error;

  // GeoJSON source + highlight tracking.
  bool _layersAdded = false;
  ml.Fill? _highlightFill;
  ml.Line? _highlightLine;

  @override
  void initState() {
    super.initState();
    _prepareMap();
    _loadBarangays();
  }

  Future<void> _prepareMap() async {
    final paths = await OfflineMapAssets.prepare();
    if (!mounted) return;
    setState(() => _paths = paths);
  }

  Future<void> _loadBarangays() async {
    try {
      await _service.load();
      if (!mounted) return;
      setState(() => _loading = false);
      _addLayers();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  void _onMapCreated(ml.MapLibreMapController controller) {
    _controller = controller;
    _addLayers();
  }

  /// Build a GeoJSON FeatureCollection from all barangays and add it as a
  /// single source + fill/line/symbol layers. This is GPU-accelerated and
  /// much faster than adding 80 individual annotation objects.
  Future<void> _addLayers() async {
    final c = _controller;
    if (c == null || _service.all.isEmpty || _layersAdded) return;
    _layersAdded = true;

    // Build GeoJSON.
    final features = <Map<String, dynamic>>[];
    const colors = [
      '#3366CC', '#33AA33', '#CC6633', '#CC3333',
      '#9933CC', '#339999', '#CC9933', '#CC3399',
    ];
    var i = 0;
    for (final b in _service.all) {
      final color = colors[i % colors.length];
      for (final part in b.parts) {
        features.add({
          'type': 'Feature',
          'properties': {
            'code': b.code,
            'name': b.name,
            'city': b.city,
            'color': color,
          },
          'geometry': {
            'type': 'Polygon',
            'coordinates': [
              part.map((p) => [p.longitude, p.latitude]).toList(),
            ],
          },
        });
      }
      i++;
    }

    final geojson = {
      'type': 'FeatureCollection',
      'features': features,
    };

    await c.addGeoJsonSource('barangays', geojson);

    // Fill layer.
    await c.addFillLayer(
      'barangays',
      'barangay-fill',
      ml.FillLayerProperties(
        fillColor: ['get', 'color'],
        fillOpacity: 0.3,
      ),
    );

    // Border layer.
    await c.addLineLayer(
      'barangays',
      'barangay-border',
      ml.LineLayerProperties(
        lineColor: '#000000',
        lineWidth: 1.0,
        lineOpacity: 0.6,
      ),
    );

    // Label layer (name + city for all barangays).
    await c.addSymbolLayer(
      'barangays',
      'barangay-label',
      ml.SymbolLayerProperties(
        textField: ['get', 'name'],
        textSize: 10.0,
        textColor: '#FFFFFF',
        textHaloColor: '#000000',
        textHaloWidth: 1.0,
      ),
    );
  }

  void _onMapClick(dynamic point, ml.LatLng coords) {
    final llCoords = ll.LatLng(coords.latitude, coords.longitude);
    String? hitCode;
    for (final b in _service.all) {
      if (b.contains(llCoords)) {
        hitCode = b.code;
        break;
      }
    }
    if (hitCode != _selectedCode) {
      setState(() => _selectedCode = hitCode);
      _updateHighlight();
      if (hitCode != null) {
        final b = _service.all.firstWhere((x) => x.code == hitCode);
        _controller?.animateCamera(
          ml.CameraUpdate.newLatLngZoom(
            ml.LatLng(b.centroid.latitude, b.centroid.longitude),
            14,
          ),
        );
      }
    }
  }

  Future<void> _updateHighlight() async {
    final c = _controller;
    if (c == null) return;

    // Remove old highlight.
    if (_highlightFill != null) {
      await c.removeFill(_highlightFill!);
      _highlightFill = null;
    }
    if (_highlightLine != null) {
      await c.removeLine(_highlightLine!);
      _highlightLine = null;
    }

    // Add new highlight.
    final code = _selectedCode;
    if (code == null) return;
    final b = _service.all.firstWhere((x) => x.code == code,
        orElse: () => _service.all.first);
    for (final part in b.parts) {
      final mlPart = part.map((p) => ml.LatLng(p.latitude, p.longitude)).toList();
      _highlightFill = await c.addFill(ml.FillOptions(
        geometry: [mlPart],
        fillColor: '#000000',
        fillOpacity: 0.5,
      ));
      _highlightLine = await c.addLine(ml.LineOptions(
        geometry: mlPart,
        lineColor: '#FFD700',
        lineWidth: 3.0,
      ));
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

  @override
  void dispose() {
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
                _controller?.animateCamera(
                  ml.CameraUpdate.newLatLngZoom(
                    ml.LatLng(_service.all.first.centroid.latitude,
                        _service.all.first.centroid.longitude),
                    13,
                  ),
                );
              }
            },
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
              onMapClick: _onMapClick,
              annotationConsumeTapEvents: const [],
            ),
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
        onPressed: () => setState(() {
          _selectedCode = null;
          _updateHighlight();
        }),
        child: const Icon(Icons.clear),
      ),
    );
  }
}