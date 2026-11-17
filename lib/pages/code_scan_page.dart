import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show DeviceOrientation;
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import '../models/route.dart';
import '../services/camera_roi.dart';
import '../services/doctr_ocr.dart';
import '../services/ocr_settings.dart';
import '../services/route_database.dart';
import '../services/route_matcher.dart';
import '../services/route_loader.dart';

/// On-device OCR scanner for jeepney codes.
///
/// Opens the camera, runs ML Kit text recognition on each frame, and matches
/// recognized text against the loaded jeepney route codes. Everything the
/// recognizer sees is outlined live on the preview, together with a ranked
/// list of "possible routes" (what the scanner thinks it is looking at).
class CodeScanPage extends StatefulWidget {
  const CodeScanPage({super.key});

  @override
  State<CodeScanPage> createState() => _CodeScanPageState();
}

/// One line of text the OCR believes it saw, with its box in the coordinate
/// space of the rotated (upright) camera frame.
class _Seen {
  const _Seen({
    required this.box,
    required this.text,
    required this.confidence,
  });

  final Rect box;
  final String text;
  final double? confidence;
}

/// A route the scanner thinks it might be looking at, with a score.
class _Idea {
  const _Idea(this.route, this.score);

  final JeepneyRoute route;
  final int score;
}

class _CodeScanPageState extends State<CodeScanPage>
    with SingleTickerProviderStateMixin {
  CameraController? _camera;
  final TextRecognizer _recognizer = TextRecognizer();
  final DoctrRecognizer _doctr = DoctrRecognizer();
  List<JeepneyRoute> _routes = const [];
  JeepneyRoute? _matched;
  List<_Idea> _ideas = const [];
  String? _recognizedText;
  List<_Seen> _seen = const [];

  /// Weighted route scorer plus its per-frame vote accumulator. Together these
  /// replace the old "does a token equal the code" test with destination
  /// triangulation, so a sign whose code is unreadable can still resolve.
  RouteMatcher? _matcher;
  final RouteVoteTracker _votes = RouteVoteTracker();

  /// Result of the docTR engine (ROI crop → recognition only, no boxes).
  String? _doctrText;
  double? _doctrConfidence;

  /// Size of the last frame after ML Kit rotated it upright — the space the
  /// bounding boxes live in.
  Size _frameSize = Size.zero;

  bool _scanning = false;
  bool _busy = false;
  String? _status;
  String? _ocrError;
  DateTime _lastScan = DateTime.fromMillisecondsSinceEpoch(0);
  List<Map<String, dynamic>> _fareRules = const [];

  /// Drives the scanning reticle / sweep line.
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  )..repeat();

  @override
  void initState() {
    super.initState();
    _loadRoutes();
    _initCamera();
    OcrSettings.engine.addListener(_onEngineChanged);
  }

  /// Switching engines mid-scan must drop the previous engine's readings, or
  /// ML Kit's stale boxes stay on screen while docTR is running.
  void _onEngineChanged() {
    if (!mounted) return;
    setState(() {
      _seen = const [];
      _doctrText = null;
      _doctrConfidence = null;
      _recognizedText = null;
      _ideas = const [];
      _matched = null;
      _votes.reset();
      _ocrError = null;
      _status = 'Engine: ${OcrSettings.engine.value.label}';
    });
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

    // Destination triangulation is an enhancement, never a hard dependency: if
    // the reference data is missing, the scanner still matches plain codes.
    try {
      final matcher = await RouteMatcher.load();
      if (!mounted) return;
      setState(() => _matcher = matcher);
    } catch (_) {
      // Keep the legacy code-only path below.
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

  // ---- Frame processing -----------------------------------------------------

  Future<void> _processFrame(CameraImage image) async {
    // Skip frames while one is already being recognized, and rate-limit so we
    // do not melt the battery.
    if (!_scanning || _busy) return;
    final now = DateTime.now();
    if (now.difference(_lastScan) < const Duration(milliseconds: 300)) return;
    _busy = true;
    _lastScan = now;

    try {
      if (OcrSettings.useDoctr) {
        await _runDoctr(image);
      } else {
        final inputImage = _inputImageFromCameraImage(image);
        if (inputImage == null) return;
        final result = await _recognizer.processImage(inputImage);
        if (!mounted) return;
        _ingest(result);
      }
    } catch (e) {
      // Surface the failure instead of swallowing it — this is how the old
      // build "did nothing" without telling anyone why.
      if (!mounted) return;
      if (_ocrError != '$e') setState(() => _ocrError = '$e');
    } finally {
      _busy = false;
    }
  }

  /// docTR path: crop the reticle region, rotate it upright, run recognition.
  ///
  /// There is no text detector here on purpose — the reticle *is* the detector,
  /// which is what makes a docTR-scale model viable on a phone.
  Future<void> _runDoctr(CameraImage image) async {
    if (!_doctr.isLoaded && _status != 'Loading docTR model…') {
      setState(() => _status = 'Loading docTR model…');
    }

    final roi = extractUprightRoi(image, rotationDegrees: _rotationDegrees());
    if (roi == null) return;
    final reading = await _doctr.recognize(roi.rgb, roi.width, roi.height);
    if (!mounted || reading == null) return;

    final text = reading.text;
    final (:ideas, :matched, :vote) = _evaluate(text);

    setState(() {
      _seen = const [];
      _doctrText = text;
      _doctrConfidence = reading.confidence;
      _recognizedText = text.isEmpty ? null : text;
      _ideas = ideas;
      _matched = matched;
      _ocrError = null;
      _status = text.isEmpty && ideas.isEmpty
          ? 'docTR: nothing readable in the reticle yet'
          : _describe(ideas, matched, vote);
    });
  }

  void _ingest(RecognizedText result) {
    final text = result.text;

    final seen = <_Seen>[
      for (final block in result.blocks)
        for (final line in block.lines)
          if (line.text.trim().isNotEmpty)
            _Seen(
              box: line.boundingBox,
              text: line.text.trim(),
              confidence: line.confidence,
            ),
    ];

    final (:ideas, :matched, :vote) = _evaluate(text);

    setState(() {
      _recognizedText = text;
      _seen = seen;
      _doctrText = null;
      _doctrConfidence = null;
      _ideas = ideas;
      _matched = matched;
      _ocrError = null;
      _status = text.isEmpty && ideas.isEmpty
          ? 'Looking for a jeepney code…'
          : _describe(ideas, matched, vote);
    });
  }

  /// Scores [text] against the catalogue and folds it into the per-frame vote.
  ///
  /// Two kinds of evidence, deliberately weighted differently:
  ///   * the route code itself — 100 for an exact token, less for a near-miss;
  ///   * endpoints and landmarks — rarity-weighted, so "Carbon" (in many
  ///     routes) barely counts while "Gaisano Country Mall" (in one) decides.
  ///
  /// A match additionally requires the same route to lead two frames in a row,
  /// because a single misread character should not commit to a route.
  ({List<_Idea> ideas, JeepneyRoute? matched, RouteVote? vote}) _evaluate(
    String text,
  ) {
    final matcher = _matcher;
    if (matcher == null || matcher.isEmpty) {
      final ideas = _legacyIdeas(text);
      return (
        ideas: ideas,
        matched:
            ideas.isNotEmpty && ideas.first.score >= 80 ? ideas.first.route : null,
        vote: null,
      );
    }

    final ranked = matcher.rank(text);
    final vote = _votes.observe(ranked);
    final byCode = {for (final r in _routes) r.code.toUpperCase(): r};
    final ideas = [
      for (final c in ranked)
        if (byCode[c.code] != null) _Idea(byCode[c.code]!, c.score.round()),
    ];
    if (ideas.isEmpty) return (ideas: ideas, matched: null, vote: vote);

    final leader = ranked.first;
    final confirmed = vote != null && vote.confirmed;
    // 85 means several independent landmarks agreed; an exact code reads 100.
    final matched =
        confirmed && leader.score >= 85 ? byCode[leader.code] : null;
    return (ideas: ideas, matched: matched, vote: vote);
  }

  /// Status line shared by both engines, so ML Kit and docTR report the same
  /// way — including how many frames the current leader has survived.
  String _describe(List<_Idea> ideas, JeepneyRoute? matched, RouteVote? vote) {
    if (matched != null) {
      final agree = vote?.agreements ?? 1;
      return 'Matched ($agree frames): ${matched.code} — ${matched.name}';
    }
    if (ideas.isEmpty) {
      return vote != null
          ? 'Holding: ${vote.code} (${vote.agreements}/${_votes.confirmFrames})'
          : 'Nothing readable yet.';
    }
    final leader = ideas.first;
    final pending =
        vote != null && vote.code == leader.route.code && !vote.confirmed;
    final suffix = pending
        ? ' (${vote.agreements}/${_votes.confirmFrames} frames)'
        : '';
    return 'Possible: ${ideas.take(3).map((i) => i.route.code).join(', ')}$suffix';
  }

  /// Pre-triangulation matcher, kept as the fallback when the reference asset
  /// is unavailable: only the code itself is considered.
  List<_Idea> _legacyIdeas(String text) {
    final upper = text.toUpperCase();
    final tokens = upper
        .split(RegExp(r'[^A-Z0-9]+'))
        .where((t) => t.length >= 2)
        .toList();

    final ideas = <_Idea>[];
    for (final r in _routes) {
      final code = r.code.toUpperCase();
      if (code.length < 2) continue;
      var score = 0;
      for (final t in tokens) {
        if (t == code) {
          score = math.max(score, 100);
        } else if (t.contains(code)) {
          score = math.max(score, 80);
        } else if (code.length >= 3 && code.contains(t)) {
          score = math.max(score, 60);
        }
      }
      if (score == 0 && upper.contains(code)) score = 40;
      if (score > 0) ideas.add(_Idea(r, score));
    }

    ideas.sort((a, b) {
      final byScore = b.score.compareTo(a.score);
      return byScore != 0
          ? byScore
          : b.route.code.length.compareTo(a.route.code.length);
    });
    return ideas.take(5).toList();
  }

  // ---- Camera image → InputImage -------------------------------------------

  /// Quarters the preview texture is rotated by (same table the camera
  /// plugin's own [CameraPreview] uses), so boxes are drawn where the image
  /// actually appears.
  int _previewTurns() {
    switch (_camera?.value.deviceOrientation) {
      case DeviceOrientation.landscapeRight:
        return 1;
      case DeviceOrientation.portraitDown:
        return 2;
      case DeviceOrientation.landscapeLeft:
        return 3;
      case DeviceOrientation.portraitUp:
      case null:
        return 0;
    }
  }

  /// Degrees ML Kit must rotate the raw frame by to make it upright — the
  /// same compensation the camera plugin applies to the preview.
  int _rotationDegrees() {
    final cam = _camera;
    if (cam == null) return 0;
    final sensor = cam.description.sensorOrientation;
    final display = _previewTurns() * 90;
    if (cam.description.lensDirection == CameraLensDirection.front) {
      return (sensor + display) % 360;
    }
    return (sensor - display + 360) % 360;
  }

  InputImage? _inputImageFromCameraImage(CameraImage image) {
    if (_camera == null) return null;
    final rotation =
        InputImageRotationValue.fromRawValue(_rotationDegrees());
    if (rotation == null) return null;

    Uint8List bytes;
    InputImageFormat format;

    if (image.planes.length == 3) {
      // YUV_420_888 from the stream. The old code handed ML Kit only
      // plane[0] (the luminance plane) labelled as YUV_420_888, i.e. an image
      // with no colour data at all — recognition silently returned nothing.
      // Convert to a tightly packed NV21 buffer instead.
      final nv21 = _yuv420ToNv21(image);
      if (nv21 == null) return null;
      bytes = nv21;
      format = InputImageFormat.nv21;
    } else if (image.planes.length == 1) {
      // Already a single-plane format (NV21 / BGRA) — pass it through.
      final f = InputImageFormatValue.fromRawValue(image.format.raw);
      if (f == null) return null;
      bytes = image.planes[0].bytes;
      format = f;
    } else {
      return null;
    }

    final rotated =
        _rotationDegrees() == 90 || _rotationDegrees() == 270;
    _frameSize = rotated
        ? Size(image.height.toDouble(), image.width.toDouble())
        : Size(image.width.toDouble(), image.height.toDouble());

    return InputImage.fromBytes(
      bytes: bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: image.planes[0].bytesPerRow,
      ),
    );
  }

  /// Converts a YUV_420_888 frame to NV21 (Y plane, then interleaved V,U),
  /// honouring row and pixel stride padding.
  Uint8List? _yuv420ToNv21(CameraImage image) {
    final planes = image.planes;
    if (planes.length != 3) return null;
    final y = planes[0], u = planes[1], v = planes[2];
    final width = image.width, height = image.height;
    final ySize = width * height;
    final out = Uint8List(ySize + ySize ~/ 2);

    if (y.bytesPerRow == width) {
      out.setRange(0, math.min(ySize, y.bytes.length), y.bytes);
    } else {
      for (var row = 0; row < height; row++) {
        final start = row * y.bytesPerRow;
        if (start + width > y.bytes.length) break;
        out.setRange(row * width, row * width + width, y.bytes, start);
      }
    }

    final uvWidth = width ~/ 2, uvHeight = height ~/ 2;
    final uPx = u.bytesPerPixel ?? 1, vPx = v.bytesPerPixel ?? 1;
    var offset = ySize;
    for (var row = 0; row < uvHeight; row++) {
      final uRow = row * u.bytesPerRow;
      final vRow = row * v.bytesPerRow;
      for (var col = 0; col < uvWidth; col++) {
        final ui = uRow + col * uPx;
        final vi = vRow + col * vPx;
        out[offset++] = vi < v.bytes.length ? v.bytes[vi] : 128;
        out[offset++] = ui < u.bytes.length ? u.bytes[ui] : 128;
      }
    }
    return out;
  }

  @override
  void dispose() {
    _scanning = false;
    OcrSettings.engine.removeListener(_onEngineChanged);
    if (_camera?.value.isStreamingImages == true) {
      _camera?.stopImageStream();
    }
    _camera?.dispose();
    _recognizer.close();
    _doctr.dispose();
    _pulse.dispose();
    super.dispose();
  }

  // ---- UI -------------------------------------------------------------------

  /// Where the preview sits inside the available box (the plugin's own
  /// AspectRatio math, so the outline lands exactly on the image).
  Rect _previewRect(Size box) {
    final cam = _camera;
    if (cam == null) return Rect.zero;
    final ratio = cam.value.aspectRatio; // preview width / height
    final turns = _previewTurns();
    final aspect = turns.isEven ? 1 / ratio : ratio; // on-screen width / height
    var w = box.width;
    var h = w / aspect;
    if (h > box.height) {
      h = box.height;
      w = h * aspect;
    }
    return Rect.fromLTWH((box.width - w) / 2, (box.height - h) / 2, w, h);
  }

  bool _isHit(_Seen s) {
    final m = _matched;
    return m != null && s.text.toUpperCase().contains(m.code.toUpperCase());
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
          // Camera preview + live recognition overlay.
          Expanded(flex: 3, child: _buildCamera(scheme)),
          // Results.
          Expanded(flex: 2, child: _buildResults(scheme)),
        ],
      ),
    );
  }

  Widget _buildCamera(ColorScheme scheme) {
    final cam = _camera;
    if (cam == null || !cam.value.isInitialized) {
      return const Center(child: CircularProgressIndicator());
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final box = Size(constraints.maxWidth, constraints.maxHeight);
        final preview = _previewRect(box);
        return Stack(
          fit: StackFit.expand,
          children: [
            Positioned.fromRect(
              rect: preview,
              child: CameraPreview(cam),
            ),
            Positioned.fill(
              child: IgnorePointer(
                child: AnimatedBuilder(
                  animation: _pulse,
                  builder: (context, _) => CustomPaint(
                    painter: _ScanPainter(
                      preview: preview,
                      frameSize: _frameSize,
                      turns: _previewTurns(),
                      seen: _seen,
                      matchedCode: _matched?.code.toUpperCase(),
                      hasMatch: _matched != null,
                      phase: _pulse.value,
                    ),
                  ),
                ),
              ),
            ),
            // Live status strip along the bottom of the preview.
            // Active OCR model, top right of the preview.
            Positioned(
              top: 10,
              right: 10,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.62),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: OcrSettings.useDoctr
                        ? const Color(0xFF38BDF8)
                        : Colors.white24,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      OcrSettings.useDoctr ? Icons.memory : Icons.auto_awesome,
                      size: 12,
                      color: OcrSettings.useDoctr
                          ? const Color(0xFF38BDF8)
                          : Colors.white70,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      OcrSettings.engine.value.label,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: OcrSettings.useDoctr
                            ? const Color(0xFF38BDF8)
                            : Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              left: 12,
              right: 12,
              bottom: 12,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.65),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _ocrError != null
                      ? 'OCR error: $_ocrError'
                      : (_status ?? 'Initializing camera…'),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.3,
                    color: _ocrError != null
                        ? Colors.red.shade300
                        : _matched != null
                            ? const Color(0xFF4ADE80)
                            : Colors.white,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildResults(ColorScheme scheme) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: SingleChildScrollView(
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
            if (_doctrText != null) ...[
              Text(
                'docTR reads:',
                style: TextStyle(
                  fontSize: 12,
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  _chip(
                    _doctrText!.isEmpty ? '(nothing)' : _doctrText!,
                    color: _doctrText!.isEmpty
                        ? Colors.blueGrey
                        : _matched != null
                            ? const Color(0xFF16A34A)
                            : Colors.amber,
                    suffix: _doctrConfidence != null
                        ? '  ${(_doctrConfidence! * 100).round()}%'
                        : null,
                  ),
                ],
              ),
              const SizedBox(height: 10),
            ],
            if (_seen.isNotEmpty) ...[
              Text(
                'What it sees:',
                style: TextStyle(
                  fontSize: 12,
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final s in _seen.take(8))
                    _chip(
                      s.text,
                      color: _isHit(s) ? const Color(0xFF16A34A) : Colors.amber,
                      suffix: s.confidence != null
                          ? '  ${(s.confidence! * 100).round()}%'
                          : null,
                    ),
                ],
              ),
              const SizedBox(height: 10),
            ],
            if (_ideas.isNotEmpty) ...[
              Text(
                'Possible routes:',
                style: TextStyle(
                  fontSize: 12,
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final idea in _ideas.take(3))
                    _chip(
                      '${idea.route.code} · ${idea.route.name}',
                      color: idea.route == _matched
                          ? const Color(0xFF16A34A)
                          : scheme.primary,
                      suffix: '  ${idea.score}%',
                    ),
                ],
              ),
              const SizedBox(height: 10),
            ],
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
              const SizedBox(height: 12),
            ],
            if (_matched != null) _matchedCard(),
          ],
        ),
      ),
    );
  }

  Widget _chip(String label, {required Color color, String? suffix}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        border: Border.all(color: color.withValues(alpha: 0.7)),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$label${suffix ?? ''}',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  Widget _matchedCard() {
    return Card(
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
                    'Base ₱${(f['base_fare'] as num).toStringAsFixed(2)} '
                    'for first ${(f['base_distance_km'] as num).toStringAsFixed(0)} km, '
                    'then ₱${(f['per_km_rate'] as num).toStringAsFixed(2)}/km',
                    style: const TextStyle(fontSize: 11),
                  )),
            ],
          ],
        ),
      ),
    );
  }
}

/// Draws the scanning reticle and the outlines of everything the OCR sees,
/// mapped from frame coordinates onto the preview.
class _ScanPainter extends CustomPainter {
  _ScanPainter({
    required this.preview,
    required this.frameSize,
    required this.turns,
    required this.seen,
    required this.matchedCode,
    required this.hasMatch,
    required this.phase,
  });

  final Rect preview;
  final Size frameSize;
  final int turns;
  final List<_Seen> seen;
  final String? matchedCode;
  final bool hasMatch;

  /// 0..1 position of the sweeping scan line (from the pulse animation).
  final double phase;

  static const _hit = Color(0xFF4ADE80);
  static const _miss = Color(0xFFFACC15);

  @override
  void paint(Canvas canvas, Size size) {
    if (preview == Rect.zero) return;
    _drawReticle(canvas, phase);
    _drawSeen(canvas);
  }

  void _drawReticle(Canvas canvas, double t) {
    final rect = Rect.fromCenter(
      center: preview.center,
      width: preview.width * 0.8,
      height: preview.height * 0.5,
    );

    // Soft, breathing frame.
    final glow = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = Color.lerp(
        Colors.white24,
        hasMatch ? _hit : Colors.white70,
        0.5 + 0.5 * math.sin(t * 2 * math.pi),
      )!;
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(16)),
      glow,
    );

    // Corner brackets — the "target acquired" look.
    const len = 26.0;
    final bracket = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = hasMatch ? _hit : Colors.white;
    final path = Path()
      ..moveTo(rect.left, rect.top + len)
      ..lineTo(rect.left, rect.top)
      ..lineTo(rect.left + len, rect.top)
      ..moveTo(rect.right - len, rect.top)
      ..lineTo(rect.right, rect.top)
      ..lineTo(rect.right, rect.top + len)
      ..moveTo(rect.right, rect.bottom - len)
      ..lineTo(rect.right, rect.bottom)
      ..lineTo(rect.right - len, rect.bottom)
      ..moveTo(rect.left + len, rect.bottom)
      ..lineTo(rect.left, rect.bottom)
      ..lineTo(rect.left, rect.bottom - len);
    canvas.drawPath(path, bracket);

    // Sweep line.
    final sweepRect = Rect.fromLTRB(
      rect.left + 8,
      rect.top,
      rect.right - 8,
      rect.bottom,
    );
    final y = sweepRect.top + sweepRect.height * t;
    final sweep = Paint()
      ..strokeWidth = 2
      ..shader = LinearGradient(
        colors: [
          Colors.transparent,
          hasMatch ? _hit : Colors.cyanAccent,
          Colors.transparent,
        ],
      ).createShader(sweepRect);
    canvas.drawLine(
      Offset(sweepRect.left, y),
      Offset(sweepRect.right, y),
      sweep,
    );
  }

  void _drawSeen(Canvas canvas) {
    for (final s in seen) {
      final r = _map(s.box);
      if (r == null || r.width < 4 || r.height < 4) continue;
      final hit =
          matchedCode != null && s.text.toUpperCase().contains(matchedCode!);
      final color = hit ? _hit : _miss;

      canvas.drawRRect(
        RRect.fromRectAndRadius(r, const Radius.circular(6)),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = hit ? 3 : 2
          ..color = color,
      );
      if (hit) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(r, const Radius.circular(6)),
          Paint()
            ..style = PaintingStyle.fill
            ..color = _hit.withValues(alpha: 0.15),
        );
      }

      var label = s.text.replaceAll(RegExp(r'\s+'), ' ');
      if (label.length > 24) label = '${label.substring(0, 23)}…';
      if (label.isEmpty) continue;

      final tp = TextPainter(
        text: TextSpan(
          text: label,
          style: TextStyle(
            color: hit ? Colors.white : Colors.black87,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
        textDirection: TextDirection.ltr,
        maxLines: 1,
        ellipsis: '…',
      )..layout(maxWidth: 180);

      final lp = Offset(r.left, r.top - tp.height - 6);
      final bg = RRect.fromRectAndRadius(
        Rect.fromLTWH(lp.dx, lp.dy, tp.width + 12, tp.height + 6),
        const Radius.circular(4),
      );
      canvas.drawRRect(
        bg,
        Paint()..color = (hit ? _hit : Colors.white).withValues(alpha: 0.92),
      );
      tp.paint(canvas, Offset(lp.dx + 6, lp.dy + 3));
    }
  }

  /// Maps a box from upright-frame coordinates to on-screen coordinates,
  /// including the preview's rotation.
  Rect? _map(Rect box) {
    if (frameSize == Size.zero ||
        frameSize.width == 0 ||
        frameSize.height == 0) {
      return null;
    }
    final unrotated = Rect.fromLTWH(
      preview.left + (box.left / frameSize.width) * preview.width,
      preview.top + (box.top / frameSize.height) * preview.height,
      (box.width / frameSize.width) * preview.width,
      (box.height / frameSize.height) * preview.height,
    );
    if (turns == 0) return unrotated;

    final c = preview.center;
    final a = turns * math.pi / 2;
    final pts = <Offset>[
      Offset(unrotated.left, unrotated.top),
      Offset(unrotated.right, unrotated.top),
      Offset(unrotated.right, unrotated.bottom),
      Offset(unrotated.left, unrotated.bottom),
    ].map((p) {
      final dx = p.dx - c.dx, dy = p.dy - c.dy;
      return Offset(
        c.dx + dx * math.cos(a) - dy * math.sin(a),
        c.dy + dx * math.sin(a) + dy * math.cos(a),
      );
    }).toList();

    final xs = pts.map((p) => p.dx).toList();
    final ys = pts.map((p) => p.dy).toList();
    return Rect.fromLTRB(
      xs.reduce(math.min),
      ys.reduce(math.min),
      xs.reduce(math.max),
      ys.reduce(math.max),
    );
  }

  @override
  bool shouldRepaint(_ScanPainter old) =>
      old.preview != preview ||
      old.frameSize != frameSize ||
      old.turns != turns ||
      old.seen != seen ||
      old.matchedCode != matchedCode ||
      old.hasMatch != hasMatch ||
      old.phase != phase;
}
