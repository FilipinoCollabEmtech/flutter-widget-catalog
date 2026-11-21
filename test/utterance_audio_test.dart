import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:seeruta/services/utterance_audio.dart';

Uint8List pcm16(List<int> samples) {
  final bytes = Uint8List(samples.length * 2);
  final data = ByteData.sublistView(bytes);
  for (var i = 0; i < samples.length; i++) {
    data.setInt16(i * 2, samples[i], Endian.little);
  }
  return bytes;
}

List<int> samplesOf(Uint8List bytes) {
  final data = ByteData.sublistView(bytes);
  return List<int>.generate(
    bytes.lengthInBytes ~/ 2,
    (i) => data.getInt16(i * 2, Endian.little),
  );
}

int maxAbs(List<int> samples) =>
    samples.fold(0, (peak, sample) => math.max(peak, sample.abs()));

double meanOf(List<int> samples) =>
    samples.isEmpty ? 0 : samples.reduce((a, b) => a + b) / samples.length;

/// A 0.05 full-scale square wave: quiet speech at a steady level.
List<int> quietTone() =>
    List<int>.generate(16000, (i) => i.isEven ? 1638 : -1638);

/// A 0.8 full-scale square wave: already loud enough for the decoder.
List<int> loudTone() =>
    List<int>.generate(16000, (i) => i.isEven ? 26214 : -26214);

void main() {
  test('trims to the speech region plus padding', () {
    final samples = <int>[
      ...List<int>.filled(16000, 0),
      ...List<int>.generate(16000, (i) => i.isEven ? 3277 : -3277),
      ...List<int>.filled(16000, 0),
    ];

    final out = UtteranceAudio.prepare(
      pcm16(samples),
      firstSample: 16000,
      endSample: 32000,
    );

    // 0.25 s before + 1 s speech + 0.5 s after, at 16 kHz.
    expect(out.lengthInBytes, 28000 * 2);
    final trimmed = samplesOf(out);
    expect(trimmed.take(3999).every((s) => s == 0), isTrue);
    expect(trimmed[4000].abs(), greaterThan(1000));
  });

  test('uses the whole clip when no speech region was found', () {
    final bytes = pcm16(quietTone());
    expect(UtteranceAudio.prepare(bytes).lengthInBytes, bytes.lengthInBytes);
  });

  test('uses the whole clip when the region is too short to be speech', () {
    final bytes = pcm16(quietTone());
    final out = UtteranceAudio.prepare(
      bytes,
      firstSample: 100,
      endSample: 300 + 100,
      padBefore: 0,
      padAfter: 0,
    );
    expect(out.lengthInBytes, bytes.lengthInBytes);
  });

  test('clamps the padded region to the captured buffer', () {
    final bytes = pcm16(List<int>.filled(32000, 0));
    final out = UtteranceAudio.prepare(
      bytes,
      firstSample: 30000,
      endSample: 99999,
    );
    // start = 30000 - 4000 pad, end = the buffer end: 6000 samples.
    expect(out.lengthInBytes, 6000 * 2);
  });

  test('removes a constant DC bias', () {
    final out = UtteranceAudio.prepare(pcm16(List<int>.filled(16000, 6553)));
    expect(samplesOf(out).every((s) => s == 0), isTrue);
  });

  test('removes DC before lifting a quiet clip', () {
    final biased = List<int>.generate(
      16000,
      (i) => 6553 + (i.isEven ? 1000 : -1000),
    );
    final out = samplesOf(UtteranceAudio.prepare(pcm16(biased)));
    expect(meanOf(out), closeTo(0, 1));
    expect(maxAbs(out), closeTo(4000, 2)); // 4x gain cap
  });

  test('lifts a quiet clip toward the decoder level', () {
    final out = samplesOf(UtteranceAudio.prepare(pcm16(quietTone())));
    expect(maxAbs(out), closeTo(6552, 2)); // 1638 * 4x
  });

  test('leaves an already loud clip alone', () {
    final out = samplesOf(UtteranceAudio.prepare(pcm16(loudTone())));
    expect(maxAbs(out), closeTo(26214, 1));
  });

  test('odd trailing bytes are dropped', () {
    final odd = Uint8List.fromList([...pcm16(quietTone()), 7]);
    final out = UtteranceAudio.prepare(odd);
    expect(out.lengthInBytes.isEven, isTrue);
    expect(out.lengthInBytes, 16000 * 2);
  });

  test('empty input stays empty', () {
    expect(UtteranceAudio.prepare(Uint8List(0)), isEmpty);
  });
}
