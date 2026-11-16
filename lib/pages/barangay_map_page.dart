import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart' as ll;
import 'package:maplibre_gl/maplibre_gl.dart' as ml;

import '../models/barangay.dart';
import '../services/barangay_service.dart';
import 'offline_map_assets.dart';

/// Barangay territory map using the same offline MapLibre map as the Home tab.
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

  final Map<String, ml.Fill> _fills = {};
  final Map<String, ml.Line> _lines = {};

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
      _addOverlays();
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
    _addOverlays();
  }

  List<ml.LatLng> _toMl(List<ll.LatLng> pts) =>
      pts.map((p) => ml.LatLng(p.latitude, p.longitude)).toList();

  Future<void> _addOverlays() async {
    final c = _controller;
    if (c == null || _service.all.isEmpty) return;

    for (final f in _fills.values) { await c.removeFill(f); }
    for (final l in _lines.values) { await c.removeLine(l); }
    _fills.clear();
    _lines.clear();

    const colors = [
      '#3366CC', '#33AA33', '#CC6633', '#CC3333',
      '#9933CC', '#339999', '#CC9933', '#CC3399',
    ];

    var i = 0;
    for (final b in _service.all) {
      final color = colors[i % colors.length];
      final selected = b.code == _selectedCode;
      for (final part in b.parts) {
        final mlPart = _toMl(part);
        final fill = await c.addFill(ml.FillOptions(
          geometry: [mlPart],
          fillColor: selected ? '#000000' : color,
          fillOpacity: selected ? 0.6 : 0.3,
        ));
        _fills['${b.code}_${part.hashCode}'] = fill;

        final line = await c.addLine(ml.LineOptions(
          geometry: mlPart,
          lineColor: '#000000',
          lineWidth: selected ? 3.0 : 1.0,
          lineOpacity: 0.6,
        ));
        _lines['${b.code}_${part.hashCode}'] = line;
      }
      i++;
    }
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
      _addOverlays();
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
          _addOverlays();
        }),
        child: const Icon(Icons.clear),
      ),
    );
  }
}