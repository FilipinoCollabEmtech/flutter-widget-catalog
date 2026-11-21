import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:seeruta/services/voice_activity.dart';

/// 16 kHz mono PCM16 chunk, [ms] long, with white noise at [rms] (0..1).
/// [dc] adds a constant offset, like a biased microphone ADC.
Uint8List pcm({
  required double rms,
  int ms = 100,
  double dc = 0,
  int seed = 1,
}) {
  final samples = 16000 * ms ~/ 1000;
  final bytes = Uint8List(samples * 2);
  final data = ByteData.sublistView(bytes);
  final random = math.Random(seed);
  // Uniform noise in [-a, a] has RMS a/sqrt(3).
  final a = rms * math.sqrt(3);
  for (var i = 0; i < samples; i++) {
    final v = dc + (random.nextDouble() * 2 - 1) * a;
    data.setInt16(
      i * 2,
      (v * 32767).clamp(-32768, 32767).round(),
      Endian.little,
    );
  }
  return bytes;
}

void main() {
  test('quiet room tone never arms the silence stop', () {
    final vad = VoiceActivityDetector();
    var ended = false;
    for (var i = 0; i < 30; i++) {
      ended = vad.addChunk(pcm(rms: 0.002, seed: i));
    }
    expect(vad.heardSpeech, isFalse);
    expect(ended, isFalse);
    expect(vad.peak, lessThan(0.01));
  });

  test('nothing said ends at the no-speech timeout', () {
    final vad = VoiceActivityDetector();
    var ended = false;
    for (var i = 0; i < 120; i++) {
      ended = vad.addChunk(pcm(rms: 0.002, seed: i));
      if (ended) break;
    }
    expect(ended, isTrue);
    expect(vad.totalSeconds, greaterThanOrEqualTo(10));
    expect(vad.heardSpeech, isFalse);
  });

  test('speech followed by silence ends the utterance', () {
    final vad = VoiceActivityDetector();
    var ended = false;
    // 0.8 s of speech (the first 0.3 s only settles the tap transient).
    for (var i = 0; i < 8; i++) {
      ended = vad.addChunk(pcm(rms: 0.08, seed: i));
    }
    expect(ended, isFalse);
    expect(vad.heardSpeech, isTrue);

    // 1.2 s of quiet.
    for (var i = 0; i < 12; i++) {
      ended = vad.addChunk(pcm(rms: 0.001, seed: 100 + i));
    }
    expect(ended, isTrue);
  });

  test('steady loud noise does not auto-stop mid-street', () {
    final vad = VoiceActivityDetector();
    var ended = false;
    // Traffic-level noise: above the speech floor, but there is no silence
    // for the stop to key on. It must not stop before the speech cap.
    for (var i = 0; i < 60; i++) {
      ended = vad.addChunk(pcm(rms: 0.05, seed: i));
    }
    expect(ended, isFalse);
    expect(vad.heardSpeech, isTrue);
  });

  test('continuous noise ends at the speech cap, not the caller cap', () {
    final vad = VoiceActivityDetector();
    var ended = false;
    var chunks = 0;
    while (!ended && chunks < 100) {
      ended = vad.addChunk(pcm(rms: 0.05, seed: chunks));
      chunks++;
    }
    expect(ended, isTrue);
    expect(vad.heardSpeech, isTrue);
    // 0.3 s settle + 7.5 s speech cap, with 100 ms chunks.
    expect(vad.totalSeconds, greaterThanOrEqualTo(7.5));
    expect(vad.totalSeconds, lessThanOrEqualTo(8.5));
  });

  test('speech ends after 0.8 s of silence', () {
    final vad = VoiceActivityDetector();
    var ended = false;
    for (var i = 0; i < 8; i++) {
      ended = vad.addChunk(pcm(rms: 0.08, seed: i));
    }
    expect(ended, isFalse);
    expect(vad.heardSpeech, isTrue);

    // 0.7 s quiet: still inside the endpoint window.
    for (var i = 0; i < 7; i++) {
      ended = vad.addChunk(pcm(rms: 0.001, seed: 100 + i));
    }
    expect(ended, isFalse);

    ended = vad.addChunk(pcm(rms: 0.001, seed: 200));
    expect(ended, isTrue);
  });

  test('a soft speaker above the calibrated floor still arms', () {
    final vad = VoiceActivityDetector();
    // Nearly silent room during calibration.
    for (var i = 0; i < 3; i++) {
      vad.addChunk(pcm(rms: 0.001, seed: i));
    }
    // 0.6 s at 0.008: below the old 0.01 floor, above the calibrated 0.006.
    for (var i = 0; i < 6; i++) {
      vad.addChunk(pcm(rms: 0.008, seed: 10 + i));
    }
    expect(vad.heardSpeech, isTrue);
    for (var i = 0; i < 12; i++) {
      vad.addChunk(pcm(rms: 0.0005, seed: 20 + i));
    }
    expect(vad.ended, isTrue);
  });

  test('reports the speech region so the decode can trim silence', () {
    final vad = VoiceActivityDetector();
    for (var i = 0; i < 10; i++) {
      vad.addChunk(pcm(rms: 0.002, seed: i));
    }
    expect(vad.speechStartSample, -1);

    for (var i = 0; i < 5; i++) {
      vad.addChunk(pcm(rms: 0.05, seed: 100 + i));
    }
    for (var i = 0; i < 10; i++) {
      vad.addChunk(pcm(rms: 0.001, seed: 200 + i));
    }

    // 100 ms chunks at 16 kHz = 1600 samples; only the middle five are
    // above the floor, so the region is exactly those chunks.
    expect(vad.speechStartSample, 10 * 1600);
    expect(vad.speechEndSample, 15 * 1600);
  });

  test('a tap transient during settle does not arm the stop', () {
    final vad = VoiceActivityDetector();
    vad.addChunk(pcm(rms: 0.3));
    for (var i = 0; i < 20; i++) {
      vad.addChunk(pcm(rms: 0.001, seed: i + 1));
    }
    expect(vad.heardSpeech, isFalse);
    expect(vad.ended, isFalse);
  });

  test('a DC offset does not look like speech', () {
    final vad = VoiceActivityDetector();
    for (var i = 0; i < 50; i++) {
      vad.addChunk(pcm(rms: 0, dc: 0.3));
    }
    expect(vad.peak, lessThan(0.001));
    expect(vad.heardSpeech, isFalse);
    expect(vad.speechStartSample, -1);
  });

  test('rms is DC-corrected and ignores int16 alignment', () {
    final chunk = pcm(rms: 0.05, dc: 0.2);
    final rms = VoiceActivityDetector.rmsOf(chunk);
    expect(rms, closeTo(0.05, 0.01));

    // An odd-offset view must not throw.
    final padded = Uint8List(chunk.length + 1)..setRange(1, chunk.length + 1, chunk);
    expect(
      VoiceActivityDetector.rmsOf(Uint8List.sublistView(padded, 1)),
      closeTo(0.05, 0.01),
    );
  });
}
