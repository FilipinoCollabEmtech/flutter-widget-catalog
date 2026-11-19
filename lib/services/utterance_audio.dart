import 'dart:math' as math;
import 'dart:typed_data';

/// Prepares a captured PCM16 buffer for the one-shot whisper decode.
///
/// The microphone runs for as long as the user talks (and, in a loud street,
/// up to the safety cap), so the raw buffer is mostly leading/trailing
/// silence. Decoding it all is wasted time and gives whisper room to
/// hallucinate. [prepare] cuts the clip to the region the speech detector
/// marked, removes the DC bias some microphone ADCs add, and brings quiet
/// speech up to a level whisper decodes reliably.
///
/// Pure Dart on purpose: the trimming rules are the part most likely to
/// regress, and they can be tested without a device or the native library.
class UtteranceAudio {
  const UtteranceAudio._();

  static const int sampleRate = 16000;

  /// Keep a little audio before the first detected syllable so a soft
  /// leading consonant is not clipped.
  static const double padBeforeSeconds = 0.25;

  /// Keep more audio after the last one for trailing consonants and breath.
  static const double padAfterSeconds = 0.5;

  /// Peak the clip is normalised toward when it is quiet.
  static const double _targetPeak = 0.9;

  /// Never amplify more than this: it would only lift room tone.
  static const double _maxGain = 4.0;

  /// Above this sample peak the clip is already loud enough; leave it alone
  /// instead of normalising every capture.
  static const double _noGainAbove = 0.5;

  /// Returns 16 kHz mono PCM16 ready for the decoder.
  ///
  /// [firstSample] and [endSample] are sample indices from the speech
  /// detector (end exclusive). When they are missing or empty the whole
  /// buffer is used — the caller may still want the DC removal and gain.
  /// The returned buffer always starts at byte 0 and always has an even
  /// length.
  static Uint8List prepare(
    Uint8List pcm, {
    int? firstSample,
    int? endSample,
    int sampleRate = sampleRate,
    double padBefore = padBeforeSeconds,
    double padAfter = padAfterSeconds,
  }) {
    final totalSamples = pcm.lengthInBytes ~/ 2;
    if (totalSamples == 0) return Uint8List(0);

    var start = 0;
    var end = totalSamples;
    if (firstSample != null &&
        endSample != null &&
        endSample > firstSample) {
      final before = (math.max(0, padBefore) * sampleRate).round();
      final after = (math.max(0, padAfter) * sampleRate).round();
      start = math.max(0, firstSample - before);
      end = math.min(totalSamples, endSample + after);
    }
    if (end - start < sampleRate ~/ 4) {
      // Less than 250 ms: not a usable command; fall back to the whole
      // buffer rather than handing the decoder an empty clip.
      start = 0;
      end = totalSamples;
    }

    final count = end - start;
    final source = ByteData.sublistView(pcm);
    final samples = Int16List(count);
    for (var i = 0; i < count; i++) {
      samples[i] = source.getInt16((start + i) * 2, Endian.little);
    }

    // A biased ADC adds a constant that carries no speech; subtract it.
    var sum = 0.0;
    for (final sample in samples) {
      sum += sample;
    }
    final mean = sum / count;

    var peak = 0.0;
    for (var i = 0; i < count; i++) {
      final value = samples[i] - mean;
      peak = math.max(peak, value.abs());
    }

    // Quiet speaker: lift the clip; loud clip: leave it untouched. A clip
    // with only DC left after mean removal stays silent.
    final peakFraction = peak / 32768.0;
    final gain = peakFraction >= _noGainAbove
        ? 1.0
        : peakFraction < 0.001
            ? 1.0
            : math.min(_maxGain, _targetPeak / peakFraction);

    final out = Uint8List(count * 2);
    final target = ByteData.sublistView(out);
    for (var i = 0; i < count; i++) {
      final value = ((samples[i] - mean) * gain)
          .round()
          .clamp(-32768, 32767)
          .toInt();
      target.setInt16(i * 2, value, Endian.little);
    }
    return out;
  }
}
