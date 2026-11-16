import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../models/route.dart';
import '../services/route_loader.dart';

/// Researcher tool: ride a jeepney, select its code, hit Record, and the app
/// logs every GPS fix as an ordered polyline. Stop when done, then copy the
/// exported JSON straight into `assets/data/jeepney_routes.json`.
///
/// Reachable from the Admin tab.
class ResearcherPage extends StatefulWidget {
  const ResearcherPage({super.key});

  @override
  State<ResearcherPage> createState() => _ResearcherPageState();
}

class _ResearcherPageState extends State<ResearcherPage> {
  final MapController _map = MapController();
  final List<LatLng> _recorded = [];
  StreamSubscription<Position>? _sub;

  List<JeepneyRoute> _routes = const [];
  String? _selectedCode;
  bool _recording = false;
  String? _status;

  @override
  void initState() {
    super.initState();
    _loadRoutes();
  }

  Future<void> _loadRoutes() async {
    try {
      final raw = await DefaultAssetBundle.of(context)
          .loadString('assets/data/jeepney_routes.json');
      if (!mounted) return;
      setState(() {
        _routes = RouteLoader.fromJsonString(raw);
        if (_routes.isNotEmpty) _selectedCode = _routes.first.code;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _status = 'Failed to load routes: $e');
    }
  }

  Future<void> _toggleRecording() async {
    if (_recording) {
      await _stop();
      return;
    }
    await _start();
  }

  Future<void> _start() async {
    final perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied ||
        perm == LocationPermission.deniedForever) {
      final req = await Geolocator.requestPermission();
      if (req == LocationPermission.denied ||
          req == LocationPermission.deniedForever) {
        setState(() => _status = 'Location permission denied.');
        return;
      }
    }
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      setState(() => _status = 'Turn on device location services.');
      return;
    }

    _recorded.clear();
    setState(() {
      _recording = true;
      _status = 'Recording…';
    });

    const settings = LocationSettings(
      accuracy: LocationAccuracy.bestForNavigation,
      distanceFilter: 5,
    );
    _sub = Geolocator.getPositionStream(locationSettings: settings).listen(
      (pos) {
        final pt = LatLng(pos.latitude, pos.longitude);
        setState(() {
          _recorded.add(pt);
          _status = 'Recording… ${_recorded.length} fixes';
        });
        _map.move(pt, _map.camera.zoom);
      },
      onError: (Object e) {
        setState(() => _status = 'GPS error: $e');
      },
    );
  }

  Future<void> _stop() async {
    await _sub?.cancel();
    _sub = null;
    setState(() {
      _recording = false;
      _status = 'Stopped — ${_recorded.length} fixes recorded.';
    });
  }

  String _exportJson() {
    final code = _selectedCode ?? 'CODE';
    final name = _routes
            .firstWhere((r) => r.code == code,
                orElse: () => JeepneyRoute(
                      code: code,
                      name: code,
                      polyline: const [],
                      stops: const [],
                    ))
            .name;
    final polyline = _recorded
        .map((p) => [p.longitude, p.latitude])
        .toList();
    final obj = {
      'code': code,
      'name': name,
      'polyline': polyline,
      'stops': polyline,
      'stopNames': <String>[],
    };
    return const JsonEncoder.withIndent('  ').convert(obj);
  }

  Future<void> _showExport() async {
    if (_recorded.isEmpty) {
      setState(() => _status = 'Nothing recorded yet.');
      return;
    }
    final json = _exportJson();
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Export — ${_selectedCode ?? ''}'),
        content: SingleChildScrollView(
          child: SelectableText(
            json,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _clear() async {
    await _stop();
    setState(() {
      _recorded.clear();
      _status = 'Cleared.';
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _map.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Researcher — record route'),
      ),
      body: Column(
        children: [
          // ---- Route selector + controls ----
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: _selectedCode,
                  decoration: const InputDecoration(
                    labelText: 'Jeepney code',
                    border: OutlineInputBorder(),
                  ),
                  items: _routes
                      .map((r) => DropdownMenuItem<String>(
                            value: r.code,
                            child: Text('${r.code} — ${r.name}'),
                          ))
                      .toList(),
                  onChanged: (v) => setState(() => _selectedCode = v),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _toggleRecording,
                        icon: Icon(_recording ? Icons.stop : Icons.fiber_manual_record),
                        label: Text(_recording ? 'Stop' : 'Record'),
                        style: FilledButton.styleFrom(
                          backgroundColor:
                              _recording ? Colors.red : scheme.primary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _clear,
                        icon: const Icon(Icons.delete_outline),
                        label: const Text('Clear'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _showExport,
                        icon: const Icon(Icons.copy_all),
                        label: const Text('Export'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  _status ?? 'Select a code, then ride the route and hit Record.',
                  style: TextStyle(
                    fontSize: 12,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                Text(
                  'Recorded fixes: ${_recorded.length}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          // ---- Live map ----
          Expanded(
            child: FlutterMap(
              mapController: _map,
              options: const MapOptions(
                initialCenter: LatLng(10.3157, 123.8854),
                initialZoom: 13,
              ),
              children: [
                TileLayer(
                  urlTemplate:
                      'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.example.seeruta',
                ),
                if (_recorded.length >= 2)
                  PolylineLayer(
                    polylines: [
                      Polyline(
                        points: _recorded,
                        color: Colors.red,
                        strokeWidth: 4,
                      ),
                    ],
                  ),
                if (_recorded.isNotEmpty)
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: _recorded.last,
                        width: 24,
                        height: 24,
                        child: const Icon(
                          Icons.location_pin,
                          color: Colors.red,
                          size: 24,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}