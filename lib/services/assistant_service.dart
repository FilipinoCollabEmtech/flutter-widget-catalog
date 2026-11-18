import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:whisper_ggml/whisper_ggml.dart';

import 'assistant_command_parser.dart';
import 'voice_log.dart';

/// Offline voice pipeline for the SeeRuta Assistant (English + Cebuano).
///
/// mic (record, 16 kHz mono PCM16)
///   -> live whisper.cpp transcription (bundled ggml-tiny-q5_1, ~31 MB)
///   -> deterministic command grammar (AssistantCommandParser)
///
/// Everything runs on-device with no network. Whisper has no Cebuano
/// language token, so decoding runs in English mode (`lang: 'en'`, which is
/// also much faster and more deterministic than `'auto'`) and Cebuano
/// commands are absorbed by the parser's Cebuano word tables.
///
/// Speed measures: the model is warmed up in the background as soon as the
/// Assistant is enabled (first tap then skips the multi-second model load);
/// capture auto-stops ~0.8 s after speech goes quiet (no second tap), with a
/// 5 s no-speech timeout; and no "Listening" TTS is spoken into the mic.
/// The wake word ("SeeRuta", openWakeWord via flutter_onnxruntime) is a
/// later phase; for now capture starts from the Home mic button.
class AssistantService {
  AssistantService({required Set<String> routeCodes})
      : _parser = AssistantCommandParser(routeCodes: routeCodes),
        _prompt = _buildPrompt(routeCodes);

  /// Preference key shared with the Settings page toggle.
  static const assistantPrefKey = 'seeRutaAssistantEnabled';

  /// Bundled whisper.cpp model (quantized whisper-tiny, multilingual).
  static const _modelAsset = 'assets/models/whisper/ggml-tiny-q5_1.bin';

  /// Safety cap on one utterance (the Home page owns the timer).
  static const maxCapture = Duration(seconds: 8);

  // ---- Voice-activity auto-stop tuning -----------------------------------

  /// Silence after speech that ends the utterance (seconds).
  static const double _autoStopSilence = 0.8;

  /// Give up when nothing is said within this many seconds.
  static const double _noSpeechTimeout = 5.0;

  /// Voiced audio needed before auto-stop is armed (avoids a cough/click
  /// ending the capture).
  static const double _minVoiced = 0.25;

  /// Same energy-gate defaults as whisper_ggml's native gate, so the Dart
  /// auto-stop and the decoder agree on what counts as speech.
  static const double _gateRmsMin = 0.0015;
  static const double _gateVoiceRatio = 2.5;
  static const double _gateFloorCap = 0.01;

  final AssistantCommandParser _parser;
  final String _prompt;
  final WhisperController _whisper = WhisperController();
  final AudioRecorder _recorder = AudioRecorder();
  FlutterTts? _tts;

  String? _modelPath;
  bool _ready = false;
  Future<bool>? _prepareFuture;
  Future<void>? _warmUpFuture;
  WhisperLiveSession? _session;
  bool _capturing = false;

  // Voice-activity state for one capture.
  double _noiseFloor = 0.005;
  double _voicedSeconds = 0;
  double _silenceSeconds = 0;
  double _totalSeconds = 0;
  bool _heardSpeech = false;
  bool _autoStopFired = false;
  void Function()? _onAutoStop;

  /// Speech rate: 1.0 is normal on Android; slightly slower is easier to
  /// follow for screen-reader users. Shared with the Settings page so its
  /// spoken confirmation matches the assistant's voice.
  static const double speechRate = 0.55;

  /// Decoding prompt that biases whisper toward the command vocabulary and
  /// the real route codes (English + Cebuano). Lower-case and unpunctuated
  /// on purpose: decoding mimics the prompt's style, and the parser prefers
  /// raw words. Kept short because prompt tokens are re-read on every decode.
  static String _buildPrompt(Set<String> routeCodes) =>
      'SeeRuta code ${routeCodes.join(' ')} '
      'where am i nearest scan help repeat stop '
      'asa ko hain ko tabang usab undang hunong pila pamasahe plite duol';

  /// Whether a capture is in progress.
  bool get capturing => _capturing;

  /// Progressively refined transcript of the current capture (full text so
  /// far, not a delta). Empty stream while not capturing.
  Stream<String> get partials => _session?.partials ?? const Stream.empty();

  /// Copies the bundled model out of assets once and warms up TTS.
  /// Idempotent and safe to call repeatedly; returns false on failure.
  Future<bool> prepare() => _prepareFuture ??= _prepare();

  Future<bool> _prepare() async {
    try {
      final dir = await getApplicationSupportDirectory();
      final file = File('${dir.path}/ggml-tiny-q5_1.bin');
      // Re-copy if missing or truncated (e.g. an interrupted earlier copy).
      if (!file.existsSync() || file.lengthSync() < 10 * 1024 * 1024) {
        final data = await rootBundle.load(_modelAsset);
        await file.writeAsBytes(data.buffer.asUint8List(), flush: true);
      }
      _modelPath = file.path;

      final tts = FlutterTts();
      await tts.setLanguage('en-US');
      await tts.setSpeechRate(speechRate);
      await tts.awaitSpeakCompletion(true);
      _tts = tts;
      _ready = true;
      return true;
    } catch (error, stackTrace) {
      debugPrint('AssistantService.prepare failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      _prepareFuture = null; // allow a retry
      return false;
    }
  }

  /// Loads the whisper model into native memory and parks it there, so the
  /// first mic tap does not pay the multi-second model load. Call in the
  /// background once the Assistant is enabled; idempotent.
  Future<void> warmUp() => _warmUpFuture ??= _warmUp();

  Future<void> _warmUp() async {
    try {
      if (!_ready && !await prepare()) return;
      final session = await _whisper.transcribeLive(
        modelPath: _modelPath,
        pcm16Stream: const Stream<Uint8List>.empty(),
        lang: 'en',
        keepModelLoaded: true,
      );
      // An empty stream finalizes immediately; the model is parked on stop.
      await session.stop();
    } catch (error) {
      debugPrint('AssistantService.warmUp failed: $error');
      _warmUpFuture = null; // allow a retry on the next call
    }
  }

  /// Starts mic capture and the live transcription session.
  /// Returns false when the mic permission is missing or the service is
  /// not ready. [onAutoStop] fires once when the utterance ends by itself
  /// (silence after speech, or nothing said within the timeout).
  Future<bool> startCapture({void Function()? onAutoStop}) async {
    if (!_ready || _capturing) return false;
    if (!await _recorder.hasPermission()) return false;
    await _tts?.stop(); // never transcribe our own voice
    _onAutoStop = onAutoStop;
    _resetVoiceWatch();
    final stream = await _recorder.startStream(const RecordConfig(
      encoder: AudioEncoder.pcm16bits,
      sampleRate: 16000,
      numChannels: 1,
    ));
    _session = await _whisper.transcribeLive(
      modelPath: _modelPath,
      // Watch the same chunks the decoder gets: RMS-based end-of-speech
      // detection in Dart, so the user never has to tap "stop".
      pcm16Stream: stream.map(_watchChunk),
      // English mode: auto-detect adds latency and whisper has no Cebuano
      // token anyway; Cebuano words are handled by the parser tables.
      lang: 'en',
      initialPrompt: _prompt,
      // Street noise can otherwise decode as "[applause]"-style tags.
      suppressNonSpeechTokens: true,
      // Park the model in native memory so the next utterance starts fast.
      keepModelLoaded: true,
    );
    _capturing = true;
    return true;
  }

  void _resetVoiceWatch() {
    _noiseFloor = 0.005;
    _voicedSeconds = 0;
    _silenceSeconds = 0;
    _totalSeconds = 0;
    _heardSpeech = false;
    _autoStopFired = false;
  }

  /// Passes audio through untouched while tracking speech energy. Speech
  /// ends after [_autoStopSilence] seconds of quiet; captures with no speech
  /// at all end after [_noSpeechTimeout] seconds.
  Uint8List _watchChunk(Uint8List chunk) {
    if (_autoStopFired || chunk.lengthInBytes < 2) return chunk;
    final samples = chunk.buffer.asInt16List(
      chunk.offsetInBytes,
      chunk.lengthInBytes ~/ 2,
    );
    if (samples.isEmpty) return chunk;

    var sum = 0.0;
    for (var i = 0; i < samples.length; i++) {
      final v = samples[i] / 32768.0;
      sum += v * v;
    }
    final rms = math.sqrt(sum / samples.length);
    final seconds = samples.length / 16000.0;
    _totalSeconds += seconds;

    final voiced = rms > math.max(_gateVoiceRatio * _noiseFloor, _gateRmsMin);
    if (voiced) {
      _voicedSeconds += seconds;
      _silenceSeconds = 0;
      if (_voicedSeconds >= _minVoiced) _heardSpeech = true;
    } else {
      // Adapt the ambient estimate only while the room is quiet.
      _noiseFloor = (_noiseFloor * 0.95 + rms * 0.05)
          .clamp(0.0005, _gateFloorCap);
      if (_heardSpeech) _silenceSeconds += seconds;
    }

    if (_heardSpeech && _silenceSeconds >= _autoStopSilence) {
      _fireAutoStop();
    } else if (!_heardSpeech && _totalSeconds >= _noSpeechTimeout) {
      _fireAutoStop();
    }
    return chunk;
  }

  void _fireAutoStop() {
    _autoStopFired = true;
    final callback = _onAutoStop;
    if (callback != null) {
      // Leave the audio callback before the UI tears the capture down.
      scheduleMicrotask(callback);
    }
  }

  /// Ends capture and parses the transcript.
  /// Returns null when nothing intelligible was heard.
  Future<AssistantCommand?> stopCapture() async {
    final session = _session;
    if (!_capturing || session == null) return null;
    _capturing = false;
    _session = null;
    _onAutoStop = null;
    // Closing the mic stream ends the session on its own; stop() is
    // idempotent, so calling it explicitly is safe either way.
    await _recorder.stop();
    final text = (await session.stop()).trim();
    // Admin > Voice Recognition shows what the recognizer heard.
    if (text.isNotEmpty) unawaited(VoiceLog.instance.add(text));
    if (text.isEmpty) return null;
    return _parser.parse(text);
  }

  /// Speaks feedback aloud; sequential because [FlutterTts] is configured
  /// with awaitSpeakCompletion.
  Future<void> speak(String text) async {
    if (text.isEmpty) return;
    try {
      await _tts?.speak(text);
    } catch (error) {
      debugPrint('AssistantService.speak failed: $error');
    }
  }

  /// "04L" -> "zero four L", for spoken confirmations.
  static String spokenRouteCode(String code) {
    const digits = [
      'zero', 'one', 'two', 'three', 'four', 'five', 'six', 'seven', 'eight', 'nine',
    ];
    return code
        .split('')
        .map((ch) {
          final d = int.tryParse(ch);
          return d != null ? digits[d] : ch.toUpperCase();
        })
        .join(' ');
  }

  /// Release the parked model and the recorder.
  Future<void> dispose() async {
    _onAutoStop = null;
    if (_capturing) {
      try {
        await stopCapture();
      } catch (_) {}
    }
    await _recorder.dispose();
    await _whisper.releaseModel();
    _ready = false;
  }
}
