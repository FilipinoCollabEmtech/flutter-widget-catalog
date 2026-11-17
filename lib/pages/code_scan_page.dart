import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import '../models/route.dart';
import '../services/route_database.dart';
import '../services/route_loader.dart';

/// On-device OCR scanner for jeepney codes.
///
/// Opens the camera, runs ML Kit text recognition on each frame, and matches
/// recognized text against the loaded jeepney route codes. When a match is
/// found the route details are shown.
class CodeScanPage extends StatefulWidget {
  const CodeScanPage({super.key});

  @override
  State<CodeScanPage> createState() => _CodeScanPageState();
}

class _CodeScanPageState extends State<CodeScanPage> {
  CameraController? _camera;
  final TextRecognizer _recognizer = TextRecognizer();
  List<JeepneyRoute> _routes = const [];
  JeepneyRoute? _matched;
  String? _recognizedText;
  bool _scanning = false;
  String? _status;
  Timer? _debounce;
  List<Map<String, dynamic>> _fareRules = const [];

  @override
  void initState() {
    super.initState();
    _loadRoutes();
    _initCamera();
  }

  Future<void> _loadRoutes() async {
    try {
      final routes = await RouteLoader.load();
      final fares = await RouteDatabase.loadFareRules();
      if (!mounted) return;
      setState(() {
        _routes = routes;
        _fareRules = fares;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _status = 'Failed to load routes: $e');
    }
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        setState(() => _status = 'No camera available.');
        return;
      }
      // Use the back camera.
      final back = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      _camera = CameraController(
        back,
        ResolutionPreset.medium,
        enableAudio: false,
      );
      await _camera!.initialize();
      if (!mounted) return;
      setState(() => _status = 'Point camera at a jeepney code.');
      _startScanning();
    } catch (e) {
      if (!mounted) return;
      setState(() => _status = 'Camera error: $e');
    }
  }

  void _startScanning() {
    if (_camera == null || !_camera!.value.isInitialized) return;
    _scanning = true;
    _camera!.startImageStream(_processFrame);
  }

  Future<void> _processFrame(CameraImage image) async {
    if (!_scanning || _debounce?.isActive == true) return;
    _debounce = Timer(const Duration(milliseconds: 500), () {});

    try {
      final inputImage = _inputImageFromCameraImage(image);
      if (inputImage == null) return;
      final result = await _recognizer.processImage(inputImage);
      if (!mounted) return;

      final text = result.text;
      if (text.isEmpty) return;

      // Match against route codes.
      final upper = text.toUpperCase();
      JeepneyRoute? match;
      for (final r in _routes) {
        if (upper.contains(r.code.toUpperCase())) {
          match = r;
          break;
        }
      }

      setState(() {
        _recognizedText = text;
        _matched = match;
        if (match != null) {
          _status = 'Matched: ${match.code} — ${match.name}';
        } else {
          _status = 'No route code recognized.';
        }
      });
    } catch (e) {
      // Silently ignore frame processing errors.
    }
  }

  InputImage? _inputImageFromCameraImage(CameraImage image) {
    final camera = _camera;
    if (camera == null) return null;
    final rotation = InputImageRotationValue.fromRawValue(
      camera.description.sensorOrientation,
    );
    if (rotation == null) return null;

    final format = InputImageFormatValue.fromRawValue(image.format.raw);
    if (format == null) return null;

    return InputImage.fromBytes(
      bytes: image.planes[0].bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: image.planes[0].bytesPerRow,
      ),
    );
  }

  @override
  void dispose() {
    _scanning = false;
    _camera?.stopImageStream();
    _camera?.dispose();
    _recognizer.close();
    _debounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan jeepney code'),
      ),
      body: Column(
        children: [
          // Camera preview.
          Expanded(
            flex: 3,
            child: _camera != null && _camera!.value.isInitialized
                ? CameraPreview(_camera!)
                : const Center(child: CircularProgressIndicator()),
          ),
          // Results.
          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    _status ?? 'Initializing camera…',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: _matched != null ? Colors.green : scheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (_recognizedText != null) ...[
                    Text(
                      'Recognized text:',
                      style: TextStyle(
                        fontSize: 12,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _recognizedText!,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 11,
                        ),
                        maxLines: 4,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  if (_matched != null) ...[
                    Card(
                      color: Colors.green.shade50,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Matched route: ${_matched!.code}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: Colors.green,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(_matched!.name),
                            if (_matched!.polyline.isNotEmpty)
                              Text(
                                '${_matched!.polyline.length} points recorded',
                                style: const TextStyle(fontSize: 12),
                              )
                            else
                              const Text(
                                'No geometry recorded yet.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.orange,
                                ),
                              ),
                            const SizedBox(height: 8),
                            if (_fareRules.isNotEmpty) ...[
                              const Text(
                                'Fare info:',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              ..._fareRules.map((f) => Text(
                                    '  ${f['vehicle_type']}: '
                                    'Base ₱${(f['base_fare'] as num).toStringAsFixed(2)} + '
                                    '₱${(f['per_km_rate'] as num).toStringAsFixed(2)}/km '
                                    '(min ₱${(f['min_fare'] as num).toStringAsFixed(2)})',
                                    style: const TextStyle(fontSize: 11),
                                  )),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}