import 'dart:math' as math;
import 'dart:typed_data';

/// End-of-speech detection for one utterance.
///
/// Uses DC-corrected RMS (a biased ADC or a constant hum must not look like
/// speech) and a speech floor calibrated from the first [settleSeconds] of
/// room tone. An earlier version scaled the threshold with a continuously
/// adaptive noise floor; in a loud street the ambient reached the floor cap
/// first, armed "speech" on traffic noise, and the auto-stop then ended the
/// capture 0.8 s later — often before the user had said anything.
///
/// The calibration is only allowed to raise the floor to [roomFloorMax], so
/// traffic noise cannot push it above a quiet speaker, and it is frozen
/// after the settle window, so a long utterance cannot raise its own
/// threshold.
///
/// When the room is too loud for the floor, [heardSpeech] arms on the noise
/// but there is no silence for the stop to key on: [maxSpeechSeconds] ends
/// the capture so a noisy street cannot turn one command into a 12 s decode.
/// The Assistant then trims the buffer to
/// [speechStartSample]..[speechEndSample] and decodes it once with the energy
/// gate open, so loud environments cost time but never the utterance.
class VoiceActivityDetector {
  VoiceActivityDetector({
    this.sampleRate = 16000,
    this.speechRms = 0.006,
    this.ambientRatio = 1.6,
    this.roomFloorMax = 0.012,
    this.settleSeconds = 0.3,
    this.minVoicedSeconds = 0.45,
    this.endSilenceSeconds = 0.8,
    this.maxSpeechSeconds = 7.5,
    this.noSpeechSeconds = 10.0,
  });

  /// PCM rate of the chunks fed to [addChunk].
  final int sampleRate;

  /// Lowest RMS that can count as speech (0..1 full scale).
  final double speechRms;

  /// How far above the calibrated room tone speech must be.
  final double ambientRatio;

  /// Ceiling for the calibrated floor: traffic noise must not lift it into
  /// the range of a soft-spoken user.
  final double roomFloorMax;

  /// Ignore the tap/click transient right after capture starts.
  final double settleSeconds;

  /// Voiced audio needed before silence can end the utterance.
  final double minVoicedSeconds;

  /// Quiet needed after speech to end the utterance.
  final double endSilenceSeconds;

  /// Hard cap on the speech portion, measured from the first voiced chunk
  /// after the settle window. A loud street has no silence to key the normal
  /// stop on; this bounds how long the capture (and therefore the decode) can
  /// run. Set to zero or less to disable.
  final double maxSpeechSeconds;

  /// Give up when nothing was said for this long.
  final double noSpeechSeconds;

  double _totalSeconds = 0;
  double _voicedSeconds = 0;
  double _silenceSeconds = 0;
  double _peak = 0;
  double _settleMin = double.infinity;
  double _roomFloor = -1; // -1 until the settle window closes
  int _sampleCursor = 0;
  int _firstVoicedSample = -1;
  int _firstSpeechSample = -1;
  int _lastVoicedSample = 0;
  int _chunks = 0;
  bool _heardSpeech = false;
  bool _ended = false;

  /// Audio captured so far, in seconds.
  double get totalSeconds => _totalSeconds;

  /// Audio above the calibrated speech floor so far, in seconds.
  double get voicedSeconds => _voicedSeconds;

  /// Loudest DC-corrected RMS seen so far.
  double get peak => _peak;

  /// Number of chunks processed.
  int get chunks => _chunks;

  /// Sample index of the first chunk above the speech floor, or -1 when
  /// nothing crossed it. Used to trim silence before decoding.
  int get speechStartSample => _firstVoicedSample;

  /// Sample index just past the last chunk above the speech floor, or 0.
  int get speechEndSample => _lastVoicedSample;

  /// True once enough voiced audio was seen to arm the silence stop.
  bool get heardSpeech => _heardSpeech;

  /// True once the utterance should end.
  bool get ended => _ended;

  /// Feeds one chunk of 16-bit little-endian mono PCM.
  /// Returns true when the utterance should end.
  bool addChunk(Uint8List chunk) {
    if (_ended) return true;
    if (chunk.lengthInBytes < 2) return false;

    final samples = chunk.lengthInBytes ~/ 2;
    final rms = rmsOf(chunk);
    final seconds = samples / sampleRate;
    _chunks++;
    _totalSeconds += seconds;
    _peak = math.max(_peak, rms);

    // Track the speech region before the settle early-out: a word spoken
    // during the tap transient must still be in the trimmed clip.
    final floor = _roomFloor < 0 ? speechRms : _roomFloor;
    if (rms >= floor) {
      if (_firstVoicedSample < 0) _firstVoicedSample = _sampleCursor;
      _lastVoicedSample = _sampleCursor + samples;
    }

    // The mic transient from the tap itself can be loud; it must not arm
    // the silence stop before the user starts talking. The quietest chunk
    // seen here calibrates the room floor.
    if (_totalSeconds <= settleSeconds) {
      _settleMin = math.min(_settleMin, rms);
    } else {
      if (_roomFloor < 0) {
        final ambient = _settleMin.isFinite ? _settleMin : 0.0;
        _roomFloor = math.max(
          speechRms,
          math.min(ambientRatio * ambient, roomFloorMax),
        );
      }

      if (rms >= _roomFloor) {
        if (_firstSpeechSample < 0) _firstSpeechSample = _sampleCursor;
        _voicedSeconds += seconds;
        _silenceSeconds = 0;
        if (_voicedSeconds >= minVoicedSeconds) _heardSpeech = true;
      } else if (_heardSpeech) {
        _silenceSeconds += seconds;
      }

      final speechSeconds = _firstSpeechSample < 0
          ? 0.0
          : (_sampleCursor + samples - _firstSpeechSample) / sampleRate;
      if (_heardSpeech &&
          _totalSeconds >= settleSeconds + minVoicedSeconds &&
          _silenceSeconds >= endSilenceSeconds - 1e-9) {
        _ended = true;
      } else if (_heardSpeech &&
          maxSpeechSeconds > 0 &&
          speechSeconds >= maxSpeechSeconds) {
        _ended = true;
      } else if (!_heardSpeech && _totalSeconds >= noSpeechSeconds) {
        _ended = true;
      }
    }
    _sampleCursor += samples;
    return _ended;
  }

  /// DC-corrected RMS of a PCM16 little-endian chunk, in 0..1 full scale.
  static double rmsOf(Uint8List chunk) {
    var samples = _samplesOf(chunk);
    if (samples.isEmpty) return 0;

    var sum = 0.0;
    var sumSq = 0.0;
    for (var i = 0; i < samples.length; i++) {
      final v = samples[i] / 32768.0;
      sum += v;
      sumSq += v * v;
    }
    final mean = sum / samples.length;
    final variance = math.max(0.0, sumSq / samples.length - mean * mean);
    return math.sqrt(variance);
  }

  static Int16List _samplesOf(Uint8List chunk) {
    final count = chunk.lengthInBytes ~/ 2;
    // `asInt16List` needs an even byte offset; record normally hands over
    // aligned buffers, but a view into an odd-offset buffer would throw.
    if (chunk.offsetInBytes.isOdd) {
      final copy = Uint8List.fromList(chunk);
      return copy.buffer.asInt16List(0, count);
    }
    return chunk.buffer.asInt16List(chunk.offsetInBytes, count);
  }
}
