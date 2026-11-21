import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_onnxruntime/flutter_onnxruntime.dart';

/// One recognition result from the PP-OCR model.
class PpOcrReading {
  const PpOcrReading(this.text, this.confidence);

  final String text;

  /// Mean character probability (0..1).
  final double confidence;

  @override
  String toString() => '$text (${(confidence * 100).round()}%)';
}

/// On-device PP-OCRv6 recognizer (PaddleOCR, ONNX).
///
/// The scanner hands this a single upright crop of the reticle, so only the
/// recognition half runs — no DB detector, no box post-processing. The reticle
/// *is* the detector, which is what keeps a recognizer this small viable.
///
/// The shipped graph is PaddleOCR's official `PP-OCRv6_small_rec` with the
/// classifier head pruned from 18,710 classes to the 64 that matter here
/// (`blank`, `0-9`, `A-Z`, `a-z`, space). That drops ~8 MB of weights, makes the
/// per-frame decode 300× smaller, and — most usefully — makes the model
/// incapable of emitting punctuation or CJK into a route code.
class PpOcrRecognizer {
  PpOcrRecognizer({
    this.modelAsset = 'assets/models/ppocr_v6_small_rec.onnx',
    this.configAsset = 'assets/models/ppocr_v6_small_rec.json',
  });

  final String modelAsset;
  final String configAsset;

  OnnxRuntime? _ort;
  OrtSession? _session;
  Future<void>? _loading;

  List<String> _vocab = const [];
  int _inH = 48;
  int _inW = 320;
  String _inputName = 'x';
  String _outputName = 'fetch_name_0';

  bool get isLoaded => _session != null;

  /// Model input size, for display.
  String get inputDescription => '$_inW×$_inH';

  Future<void> ensureLoaded() {
    if (_session != null) return Future<void>.value();
    // A hung or failed load must not be cached forever: without the reset, one
    // bad attempt disables the engine until the app is restarted, which is
    // exactly what "stuck on Loading" looked like from the outside.
    return _loading ??= _load()
        .timeout(const Duration(seconds: 45))
        .catchError((Object e) {
      _loading = null;
      throw e;
    });
  }

  Future<void> _load() async {
    final cfg = jsonDecode(await rootBundle.loadString(configAsset))
        as Map<String, dynamic>;

    final vocab = cfg['vocab'];
    if (vocab is! List || vocab.length < 2) {
      throw StateError('PP-OCR config has no vocabulary: $configAsset');
    }
    _vocab = vocab.map((e) => '$e').toList();

    final shape = cfg['input_shape'];
    if (shape is List && shape.length == 3) {
      _inH = (shape[1] as num).toInt();
      _inW = (shape[2] as num).toInt();
    }

    _ort ??= OnnxRuntime();
    final session = await _ort!.createSessionFromAsset(modelAsset);
    _session = session;
    if (session.inputNames.isNotEmpty) _inputName = session.inputNames.first;
    if (session.outputNames.isNotEmpty) _outputName = session.outputNames.first;
  }

  /// Recognizes the text in [rgb] (tightly packed RGB888, [width] × [height]).
  Future<PpOcrReading?> recognize(Uint8List rgb, int width, int height) async {
    await ensureLoaded();
    final session = _session;
    if (session == null || width <= 0 || height <= 0) return null;

    final (:tensor, :tensorWidth) = _buildTensor(rgb, width, height);
    final input = await OrtValue.fromList(tensor, [1, 3, _inH, tensorWidth]);
    OrtValue? output;
    try {
      final outputs = await session.run({_inputName: input});
      output = outputs[_outputName];
      if (output == null) return null;
      final flat = await output.asFlattenedList();
      return _decode(flat, output.shape);
    } finally {
      await input.dispose();
      await output?.dispose();
    }
  }

  /// PaddleOCR's `RecResizeImg`: scale to 48 px tall keeping the aspect ratio,
  /// normalize to [-1, 1], then zero-pad to the model width.
  ///
  /// Two details are easy to get wrong and both were verified against the
  /// reference implementation: channels are **BGR** (PaddleOCR decodes with
  /// cv2), and padding happens *after* normalization, so the pad value is 0.0
  /// — mid-grey — not -1 (black).
  ({Float32List tensor, int tensorWidth}) _buildTensor(
    Uint8List rgb,
    int w,
    int h,
  ) {
    final ratio = w / h;
    final resizedW = (ratio * _inH).ceil().clamp(8, _inW);
    final plane = _inW * _inH;
    final out = Float32List(3 * plane); // zero-filled: the padding value.

    int at(int x, int y) => (y * w + x) * 3;

    for (var py = 0; py < _inH; py++) {
      final sy = ((py + 0.5) * h / _inH - 0.5).clamp(0.0, (h - 1).toDouble());
      final y0 = sy.floor();
      final y1 = math.min(y0 + 1, h - 1);
      final fy = sy - y0;
      for (var px = 0; px < resizedW; px++) {
        final sx = ((px + 0.5) * w / resizedW - 0.5)
            .clamp(0.0, (w - 1).toDouble());
        final x0 = sx.floor();
        final x1 = math.min(x0 + 1, w - 1);
        final fx = sx - x0;

        final i00 = at(x0, y0);
        final i10 = at(x1, y0);
        final i01 = at(x0, y1);
        final i11 = at(x1, y1);
        final w00 = (1 - fx) * (1 - fy);
        final w10 = fx * (1 - fy);
        final w01 = (1 - fx) * fy;
        final w11 = fx * fy;

        final r = rgb[i00] * w00 + rgb[i10] * w10 + rgb[i01] * w01 + rgb[i11] * w11;
        final g = rgb[i00 + 1] * w00 +
            rgb[i10 + 1] * w10 +
            rgb[i01 + 1] * w01 +
            rgb[i11 + 1] * w11;
        final b = rgb[i00 + 2] * w00 +
            rgb[i10 + 2] * w10 +
            rgb[i01 + 2] * w01 +
            rgb[i11 + 2] * w11;

        final di = py * _inW + px;
        // BGR order, then (x / 255 - 0.5) / 0.5.
        out[di] = (b / 255 - 0.5) / 0.5;
        out[plane + di] = (g / 255 - 0.5) / 0.5;
        out[2 * plane + di] = (r / 255 - 0.5) / 0.5;
      }
    }
    return (tensor: out, tensorWidth: _inW);
  }

  /// CTC greedy decode: argmax per step, drop repeats and blanks.
  ///
  /// The pruned graph emits `[1, T, C]` with C = `_vocab.length`, blank at
  /// index 0, and softmax already applied.
  PpOcrReading? _decode(List flat, List<int> shape) {
    final classes = _vocab.length;
    if (shape.isEmpty || classes == 0) return null;

    int steps;
    int cls;
    if (shape.length == 3 && shape[2] == classes) {
      steps = shape[0] * shape[1];
      cls = shape[2];
    } else if (shape.length == 3 && shape[1] == classes) {
      steps = shape[0] * shape[2];
      cls = shape[1];
    } else if (shape.length == 2 && shape[1] == classes) {
      steps = shape[0];
      cls = shape[1];
    } else {
      return null;
    }
    if (steps <= 0 || cls <= 0 || flat.length < steps * cls) return null;

    final chars = <String>[];
    final probs = <double>[];
    var prev = -1;

    for (var t = 0; t < steps; t++) {
      final base = t * cls;
      var best = 0;
      var bestV = double.negativeInfinity;
      var maxV = double.negativeInfinity;
      var sum = 0.0;
      for (var c = 0; c < cls; c++) {
        final v = (flat[base + c] as num).toDouble();
        if (v > bestV) {
          bestV = v;
          best = c;
        }
        if (v > maxV) maxV = v;
        sum += v;
      }
      // The exported graph applies softmax, so `bestV` is already the
      // probability; fall back to computing it if a future export does not.
      final prob = (sum - 1).abs() < 0.05
          ? bestV
          : (() {
              var denom = 0.0;
              for (var c = 0; c < cls; c++) {
                denom += math.exp((flat[base + c] as num).toDouble() - maxV);
              }
              return denom == 0 ? 0.0 : math.exp(bestV - maxV) / denom;
            })();

      if (best != prev && best != 0 && best < _vocab.length) {
        final ch = _vocab[best];
        if (ch.isNotEmpty) {
          chars.add(ch);
          probs.add(prob);
        }
      }
      prev = best;
    }

    final text = chars.join().trim();
    if (text.isEmpty) return const PpOcrReading('', 0);
    final confidence = probs.isEmpty
        ? 0.0
        : probs.reduce((a, b) => a + b) / probs.length;
    return PpOcrReading(text, confidence.clamp(0.0, 1.0));
  }

  Future<void> dispose() async {
    await _session?.close();
    _session = null;
    _loading = null;
  }
}
