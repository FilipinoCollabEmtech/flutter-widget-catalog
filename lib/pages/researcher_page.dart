import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:maplibre_gl/maplibre_gl.dart' as ml;

import '../models/route.dart';
import '../services/route_loader.dart';
import 'offline_map_assets.dart';

/// Researcher tool: ride a jeepney, select its code, hit Record, and the app
/// logs every GPS fix as an ordered polyline. Stop when done, then copy the
/// exported JSON straight into `assets/data/jeepney_routes.json`.
///
/// Uses the same offline MapLibre map as the Home tab.
class ResearcherPage extends StatefulWidget {
  const ResearcherPage({super.key});

  @override
  State<ResearcherPage> createState() => _ResearcherPageState();
}

class _ResearcherPageState extends State<ResearcherPage> {
  final List<LatLng> _recorded = [];
  final List<int> _stopIndices = []; // indices into _recorded

  OfflineMapPaths? _paths;
  ml.MapLibreMapController? _controller;
  ml.Line? _recordedLine;
  ml.Circle? _currentCircle;
  final List<ml.Circle> _stopCircles = [];

  List<JeepneyRoute> _routes = const [];
  String? _selectedCode;
  bool _recording = false;
  String? _status;
  StreamSubscription<Position>? _sub;
  double _bearing = 0;
  DateTime? _startedAt;
  Timer? _timer;
  String _elapsed = '00:00';

  @override
  void initState() {
    super.initState();
    _prepareMap();
    _loadRoutes();
  }

  Future<void> _prepareMap() async {
    final paths = await OfflineMapAssets.prepare();
    if (!mounted) return;
    setState(() => _paths = paths);
  }

  Future<void> _loadRoutes() async {
    try {
      final routes = await RouteLoader.load();
      if (!mounted) return;
      setState(() {
        _routes = routes;
        if (routes.isNotEmpty) _selectedCode = routes.first.code;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _status = 'Failed to load routes: $e');
    }
  }

  void _onMapCreated(ml.MapLibreMapController controller) {
    _controller = controller;
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
    _stopIndices.clear();
    _startedAt = DateTime.now();
    _elapsed = '00:00';
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || !_recording) return;
      final elapsed = DateTime.now().difference(_startedAt!);
      setState(() {
        _elapsed =
            '${elapsed.inMinutes.toString().padLeft(2, '0')}:${(elapsed.inSeconds % 60).toString().padLeft(2, '0')}';
      });
    });

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
        _updateOverlays();
        _controller?.animateCamera(
          ml.CameraUpdate.newLatLng(ml.LatLng(pt.latitude, pt.longitude)),
        );
      },
      onError: (Object e) {
        setState(() => _status = 'GPS error: $e');
      },
    );
  }

  Future<void> _stop() async {
    await _sub?.cancel();
    _sub = null;
    _timer?.cancel();
    _timer = null;
    setState(() {
      _recording = false;
      _status = 'Stopped — ${_recorded.length} fixes, ${_stopIndices.length} stops.';
    });
  }

  Future<void> _markStop() async {
    if (_recorded.isEmpty) {
      setState(() => _status = 'No fixes recorded yet.');
      return;
    }
    final idx = _recorded.length - 1;
    if (_stopIndices.contains(idx)) {
      setState(() => _status = 'Already marked this point as a stop.');
      return;
    }
    setState(() {
      _stopIndices.add(idx);
      _status = 'Stop #${_stopIndices.length} marked.';
    });
    await _updateOverlays();
  }

  Future<void> _updateOverlays() async {
    final c = _controller;
    if (c == null) return;

    if (_recordedLine != null) {
      await c.removeLine(_recordedLine!);
      _recordedLine = null;
    }
    if (_currentCircle != null) {
      await c.removeCircle(_currentCircle!);
      _currentCircle = null;
    }
    for (final sc in _stopCircles) {
      await c.removeCircle(sc);
    }
    _stopCircles.clear();

    if (_recorded.length >= 2) {
      _recordedLine = await c.addLine(ml.LineOptions(
        geometry: _recorded.map((p) => ml.LatLng(p.latitude, p.longitude)).toList(),
        lineColor: '#FF0000',
        lineWidth: 4.0,
      ));
    }
    if (_recorded.isNotEmpty) {
      _currentCircle = await c.addCircle(ml.CircleOptions(
        geometry: ml.LatLng(_recorded.last.latitude, _recorded.last.longitude),
        circleRadius: 8.0,
        circleColor: '#FF0000',
        circleStrokeWidth: 2.0,
        circleStrokeColor: '#FFFFFF',
      ));
    }
    for (final idx in _stopIndices) {
      if (idx < _recorded.length) {
        final sc = await c.addCircle(ml.CircleOptions(
          geometry: ml.LatLng(_recorded[idx].latitude, _recorded[idx].longitude),
          circleRadius: 10.0,
          circleColor: '#00FF00',
          circleStrokeWidth: 2.0,
          circleStrokeColor: '#FFFFFF',
        ));
        _stopCircles.add(sc);
      }
    }
  }

  double get _totalDistanceM {
    if (_recorded.length < 2) return 0;
    var total = 0.0;
    for (var i = 0; i < _recorded.length - 1; i++) {
      total += _haversine(_recorded[i], _recorded[i + 1]);
    }
    return total;
  }

  double _haversine(LatLng a, LatLng b) {
    const r = 6371000.0;
    final dLat = (b.latitude - a.latitude) * 3.141592653589793 / 180;
    final dLng = (b.longitude - a.longitude) * 3.141592653589793 / 180;
    final lat1 = a.latitude * 3.141592653589793 / 180;
    final lat2 = b.latitude * 3.141592653589793 / 180;
    final h = _sin(dLat / 2) * _sin(dLat / 2) +
        _cos(lat1) * _cos(lat2) * _sin(dLng / 2) * _sin(dLng / 2);
    return 2 * r * _asin(_sqrt(h));
  }

  double _sin(double x) => x - x * x * x / 6 + x * x * x * x * x / 120;
  double _cos(double x) => 1 - x * x / 2 + x * x * x * x / 24;
  double _asin(double x) => x + x * x * x / 6 + 3 * x * x * x * x * x / 40;
  double _sqrt(double x) => x <= 0 ? 0 : x;

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
    final stops = _stopIndices
        .where((i) => i < _recorded.length)
        .map((i) => [_recorded[i].longitude, _recorded[i].latitude])
        .toList();
    final stopNames = List<String>.filled(stops.length, '');
    final obj = {
      'code': code,
      'name': name,
      'polyline': polyline,
      'stops': stops,
      'stopNames': stopNames,
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
    if (_controller != null) {
      if (_recordedLine != null) {
        await _controller!.removeLine(_recordedLine!);
        _recordedLine = null;
      }
      if (_currentCircle != null) {
        await _controller!.removeCircle(_currentCircle!);
        _currentCircle = null;
      }
      for (final sc in _stopCircles) {
        await _controller!.removeCircle(sc);
      }
      _stopCircles.clear();
    }
    setState(() {
      _recorded.clear();
      _stopIndices.clear();
      _status = 'Cleared.';
      _elapsed = '00:00';
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _timer?.cancel();
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
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  height: 48,
                  child: DropdownButtonFormField<String>(
                    initialValue: _selectedCode,
                    isDense: true,
                    decoration: const InputDecoration(
                      labelText: 'Jeepney code',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    items: _routes
                        .map((r) => DropdownMenuItem<String>(
                              value: r.code,
                              child: Text('${r.code} — ${r.name}', style: const TextStyle(fontSize: 13)),
                            ))
                        .toList(),
                    onChanged: (v) => setState(() => _selectedCode = v),
                  ),
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
                        onPressed: _recording ? _markStop : null,
                        icon: const Icon(Icons.add_location),
                        label: const Text('Mark Stop'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
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
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _status ?? 'Select a code, then ride and hit Record.',
                      style: TextStyle(
                        fontSize: 12,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    Text(
                      _elapsed,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
                Text(
                  'Fixes: ${_recorded.length}  |  Stops: ${_stopIndices.length}  |  '
                  'Distance: ${(_totalDistanceM / 1000).toStringAsFixed(2)} km',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Stack(
              children: [
                _paths == null
                    ? const Center(child: CircularProgressIndicator())
                    : ml.MapLibreMap(
                        styleString: _paths!.stylePath,
                        initialCameraPosition: ml.CameraPosition(
                          target: ml.LatLng(10.3157, 123.8854),
                          zoom: 13,
                        ),
                        onMapCreated: _onMapCreated,
                        compassEnabled: false,
                        rotateGesturesEnabled: true,
                        trackCameraPosition: true,
                        onCameraMove: (camera) {
                          if (mounted && camera.bearing != _bearing) {
                            setState(() => _bearing = camera.bearing);
                          }
                        },
                      ),
                // Custom compass overlay.
                Positioned(
                  top: 12,
                  right: 12,
                  child: Material(
                    color: Colors.white.withValues(alpha: 0.9),
                    shape: const CircleBorder(),
                    elevation: 4,
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: () {
                        _controller?.animateCamera(
                          ml.CameraUpdate.newCameraPosition(
                            ml.CameraPosition(
                              target: _controller!.cameraPosition?.target ??
                                  ml.LatLng(10.3157, 123.8854),
                              zoom: _controller!.cameraPosition?.zoom ?? 13,
                              bearing: 0,
                            ),
                          ),
                          duration: const Duration(milliseconds: 300),
                        );
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(10),
                        child: Transform.rotate(
                          angle: -_bearing * 3.141592653589793 / 180,
                          child: const Icon(Icons.explore,
                              size: 24, color: Colors.black87),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}