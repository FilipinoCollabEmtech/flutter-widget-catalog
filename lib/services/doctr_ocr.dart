import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_onnxruntime/flutter_onnxruntime.dart';

/// One recognition result from the docTR model.
class DoctrReading {
  const DoctrReading(this.text, this.confidence);

  final String text;

  /// Mean character probability (0..1).
  final double confidence;

  @override
  String toString() => '$text (${(confidence * 100).round()}%)';
}

/// On-device docTR text recognizer (ViPTR-tiny, ONNX).
///
/// The scanner hands this a single upright crop of the reticle, so only the
/// recognition half of docTR runs — no DB detector, no box post-processing.
/// Checkpoints exported with `export_model_to_onnx` load the same way as long
/// as their `config.json` (vocab / mean / std / input_shape) ships next to the
/// `.onnx` file.
class DoctrRecognizer {
  DoctrRecognizer({
    this.modelAsset = 'assets/models/doctr_viptr_tiny.onnx',
    this.configAsset = 'assets/models/doctr_viptr_tiny.json',
  });

  final String modelAsset;
  final String configAsset;

  OnnxRuntime? _ort;
  OrtSession? _session;
  Future<void>? _loading;

  String _vocab = '';
  List<double> _mean = const [0.694, 0.695, 0.693];
  List<double> _std = const [0.299, 0.296, 0.301];
  int _inH = 32;
  int _inW = 128;
  String _inputName = 'input';
  String _outputName = 'output';

  bool get isLoaded => _session != null;

  /// Model input size, for display.
  String get inputDescription => '$_inW×$_inH';

  Future<void> ensureLoaded() {
    if (_session != null) return Future<void>.value();
    // A hung or failed load must not be cached forever: without the reset, one
    // bad attempt disables docTR until the app is restarted, which is exactly
    // what "stuck on Loading docTR model" looked like from the outside.
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

    _vocab = cfg['vocab'] as String? ?? '';
    if (_vocab.isEmpty) {
      throw StateError('docTR config has no vocab: $configAsset');
    }
    final mean = cfg['mean'];
    final std = cfg['std'];
    if (mean is List && mean.length == 3) {
      _mean = mean.map((e) => (e as num).toDouble()).toList();
    }
    if (std is List && std.length == 3) {
      _std = std.map((e) => (e as num).toDouble()).toList();
    }
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
  Future<DoctrReading?> recognize(Uint8List rgb, int width, int height) async {
    await ensureLoaded();
    final session = _session;
    if (session == null || width <= 0 || height <= 0) return null;

    final tensor = _buildTensor(rgb, width, height);
    final input = await OrtValue.fromList(tensor, [1, 3, _inH, _inW]);
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

  /// Letterboxes the crop into the model input and normalizes it to NCHW.
  Float32List _buildTensor(Uint8List rgb, int w, int h) {
    final plane = _inW * _inH;
    final out = Float32List(3 * plane);

    // docTR pads with 0 pixels before normalizing, so the padding's normalized
    // value is (0/255 - mean) / std rather than 0.
    for (var c = 0; c < 3; c++) {
      final fill = (0.0 - _mean[c]) / _std[c];
      for (var i = 0; i < plane; i++) {
        out[c * plane + i] = fill;
      }
    }

    final scale = math.min(_inW / w, _inH / h);
    final nw = math.max(1, (w * scale).round());
    final nh = math.max(1, (h * scale).round());
    final ox = (_inW - nw) ~/ 2;
    final oy = (_inH - nh) ~/ 2;

    int at(int x, int y) => (y * w + x) * 3;

    for (var py = 0; py < nh; py++) {
      final sy = ((py + 0.5) * h / nh - 0.5).clamp(0.0, (h - 1).toDouble());
      final y0 = sy.floor();
      final y1 = math.min(y0 + 1, h - 1);
      final fy = sy - y0;
      for (var px = 0; px < nw; px++) {
        final sx = ((px + 0.5) * w / nw - 0.5).clamp(0.0, (w - 1).toDouble());
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

        final di = (oy + py) * _inW + (ox + px);
        out[di] = (r / 255 - _mean[0]) / _std[0];
        out[plane + di] = (g / 255 - _mean[1]) / _std[1];
        out[2 * plane + di] = (b / 255 - _mean[2]) / _std[2];
      }
    }
    return out;
  }

  /// CTC greedy decode: argmax per step, drop repeats and blanks.
  ///
  /// docTR appends a `<eos>` slot to the vocab, and that slot is the CTC blank,
  /// so the class count is `vocab.length + 1` and the blank index is
  /// `vocab.length`. The exported graph emits `[T, 1, C]` logits.
  DoctrReading? _decode(List flat, List<int> shape) {
    final classes = _vocab.length + 1;
    if (shape.isEmpty) return null;

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

    final blank = _vocab.length;
    final chars = <String>[];
    final probs = <double>[];
    var prev = -1;

    for (var t = 0; t < steps; t++) {
      final base = t * cls;
      var best = 0;
      var bestV = double.negativeInfinity;
      var maxV = double.negativeInfinity;
      var sum = 0.0;
      var looksLikeProb = true;
      for (var c = 0; c < cls; c++) {
        final v = (flat[base + c] as num).toDouble();
        if (v > bestV) {
          bestV = v;
          best = c;
        }
        if (v > maxV) maxV = v;
        if (v < 0 || v > 1) looksLikeProb = false;
        sum += v;
      }

      double prob;
      if (looksLikeProb && (sum - 1).abs() < 0.05) {
        prob = bestV; // graph already applied softmax
      } else {
        var denom = 0.0;
        for (var c = 0; c < cls; c++) {
          denom += math.exp((flat[base + c] as num).toDouble() - maxV);
        }
        prob = denom == 0 ? 0.0 : math.exp(bestV - maxV) / denom;
      }

      if (best != prev && best != blank) {
        if (best < _vocab.length) {
          chars.add(_vocab[best]);
          probs.add(prob);
        }
      }
      prev = best;
    }

    final text = chars.join().trim();
    if (text.isEmpty) return const DoctrReading('', 0);
    final confidence = probs.isEmpty
        ? 0.0
        : probs.reduce((a, b) => a + b) / probs.length;
    return DoctrReading(text, confidence.clamp(0.0, 1.0));
  }

  Future<void> dispose() async {
    await _session?.close();
    _session = null;
    _loading = null;
  }
}
