import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:whisper_ggml/whisper_ggml.dart';

import 'assistant_command_parser.dart';
import 'voice_activity.dart';
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
/// Capture ordering matters: the decoder session is started *before* the
/// recorder. `record` drops chunks while its broadcast stream has no
/// listener, so opening the mic first lost everything spoken while a cold
/// model loaded — on a slow phone that was the whole utterance.
///
/// The live decoder only runs when its native energy gate sees voiced audio.
/// Every chunk is also kept in memory, so if that gate misses a loud street
/// or a quiet speaker and the live pass returns nothing, the whole buffer is
/// decoded again with the gate open. A loud environment costs a little extra
/// time; it no longer costs the sentence.
class AssistantService {
  AssistantService({required Set<String> routeCodes})
      : _parser = AssistantCommandParser(routeCodes: routeCodes),
        _prompt = _buildPrompt(routeCodes);

  /// Preference key shared with the Settings page toggle.
  static const assistantPrefKey = 'seeRutaAssistantEnabled';

  /// Bundled whisper.cpp model (quantized whisper-tiny, multilingual).
  static const _modelAsset = 'assets/models/whisper/ggml-tiny-q5_1.bin';

  /// Safety cap on one utterance (the Home page owns the timer).
  static const maxCapture = Duration(seconds: 12);

  // ---- Live decoder energy gate -------------------------------------------
  //
  // Tuned for speech in street noise: a low absolute floor keeps a quiet
  // speaker decodable, and a low voice ratio lets speech only a few dB above
  // traffic through. The final fallback decode ignores the gate entirely.

  static const double _gateRmsMin = 0.002;
  static const double _gateVoiceRatio = 1.5;
  static const double _gateNoiseFloorCap = 0.01;

  /// Audio kept for the fallback decode (s); well above [maxCapture].
  static const int _maxBufferedSeconds = 15;

  /// Microphone format whisper.cpp expects.
  static const RecordConfig _recordConfig = RecordConfig(
    encoder: AudioEncoder.pcm16bits,
    sampleRate: 16000,
    numChannels: 1,
    // Android's speech-recognition source: no AGC/noise-suppression pumping
    // that eats quiet syllables, and no device-to-device `DEFAULT` roulette.
    androidConfig: AndroidRecordConfig(
      audioSource: AndroidAudioSource.voiceRecognition,
    ),
    // A headset moving between routes must not silently pause the capture.
    audioRouteChange: AudioRouteChangeMode.follow,
  );

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
  StreamSubscription<Uint8List>? _audioSub;
  StreamSubscription<String>? _partialSub;
  bool _capturing = false;

  /// Every chunk of the current utterance, for the open-gate retry.
  final BytesBuilder _audio = BytesBuilder(copy: true);
  VoiceActivityDetector _vad = VoiceActivityDetector();
  String _lastPartial = '';
  String? _captureError;

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

  /// Starts the decoder, then the mic, and feeds one into the other.
  /// Returns false when the mic permission is missing, the model cannot be
  /// loaded, or the session cannot start. [onAutoStop] fires once when the
  /// utterance ends by itself (silence after speech, or nothing said within
  /// the timeout).
  Future<bool> startCapture({void Function()? onAutoStop}) async {
    if (!_ready || _capturing) return false;
    if (!await _recorder.hasPermission()) {
      _logFailure('Microphone permission denied');
      return false;
    }
    await _tts?.stop(); // never transcribe our own voice
    _onAutoStop = onAutoStop;
    _resetCaptureState();

    WhisperLiveSession? session;
    try {
      // Decoder first. `record` silently drops audio until its stream has a
      // listener, and a cold model load takes seconds; opening the mic first
      // meant the user's first sentence never reached the recognizer.
      session = await startWhisperLiveSession(
        modelPath: _modelPath!,
        lang: 'en',
        initialPrompt: _prompt,
        // Street noise can otherwise decode as "[applause]"-style tags.
        suppressNonSpeechTokens: true,
        // Park the model in native memory so the next utterance starts fast.
        keepModelLoaded: true,
        gateRmsMin: _gateRmsMin,
        gateVoiceRatio: _gateVoiceRatio,
        gateNoiseFloorCap: _gateNoiseFloorCap,
      );
      _session = session;
      _partialSub = session.partials.listen((text) => _lastPartial = text);

      // Mic second, and its chunks go straight to the decoder: no window
      // exists in which the recorder has audio but the decoder is not
      // listening yet.
      final stream = await _recorder.startStream(_recordConfig);
      _audioSub = stream.listen(
        _onAudioChunk,
        onError: (Object error, StackTrace stackTrace) {
          debugPrint('Assistant mic stream error: $error');
          _captureError = '$error';
          _fireAutoStop();
        },
        onDone: () {
          // The platform can end capture on its own (route lost, focus
          // taken). End the utterance instead of hanging in "listening".
          _fireAutoStop();
        },
        cancelOnError: true,
      );
      _capturing = true;
      return true;
    } catch (error, stackTrace) {
      debugPrint('Assistant capture start failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      await _audioSub?.cancel();
      _audioSub = null;
      await _partialSub?.cancel();
      _partialSub = null;
      _session = null;
      try {
        await session?.stop();
      } catch (_) {}
      await _recorder.stop();
      _logFailure('$error');
      return false;
    }
  }

  void _resetCaptureState() {
    _audio.clear();
    _vad = VoiceActivityDetector();
    _lastPartial = '';
    _captureError = null;
  }

  /// Every chunk is buffered for the fallback decode and fed to the decoder
  /// untouched; [VoiceActivityDetector] only decides when to stop.
  void _onAudioChunk(Uint8List chunk) {
    if (!_capturing) return;
    if (_audio.length < _maxBufferedSeconds * 16000 * 2) {
      _audio.add(chunk);
    }
    _session?.feed(chunk);
    if (_vad.addChunk(chunk)) _fireAutoStop();
  }

  void _fireAutoStop() {
    final callback = _onAutoStop;
    if (callback == null) return;
    _onAutoStop = null; // fire once
    // Leave the audio callback before the UI tears the capture down.
    scheduleMicrotask(callback);
  }

  /// Ends capture and parses the transcript.
  /// Returns null when nothing intelligible was heard.
  Future<AssistantCommand?> stopCapture() async {
    final session = _session;
    if (!_capturing || session == null) return null;
    _capturing = false;
    _onAutoStop = null;

    final seconds = _vad.totalSeconds;
    final peak = _vad.peak;
    final voiced = _vad.voicedSeconds;
    final chunks = _vad.chunks;
    final partial = _lastPartial;
    final buffered = _audio.takeBytes();

    // Close our side first so the recorder's own stop cannot re-enter.
    await _audioSub?.cancel();
    _audioSub = null;
    try {
      await _recorder.stop();
    } catch (error) {
      debugPrint('Assistant recorder stop failed: $error');
      _captureError ??= '$error';
    }
    await _partialSub?.cancel();
    _partialSub = null;
    _session = null;
    _lastPartial = '';

    var error = _captureError;
    var text = '';
    var retried = false;
    try {
      text = (await session
              .stop()
              .timeout(const Duration(seconds: 30)))
          .trim();
    } catch (failure) {
      debugPrint('Assistant decode failed: $failure');
      error ??= '$failure';
    }

    // The live pass only decodes what its energy gate marked as voiced. If
    // it heard nothing but the mic did deliver audio, decode it all again
    // with the gate open: loud streets and quiet speakers land here.
    if (text.isEmpty && buffered.length >= 16000 && peak >= 0.002) {
      retried = true;
      try {
        text = await _decodeBuffered(buffered);
      } catch (failure) {
        debugPrint('Assistant fallback decode failed: $failure');
        error ??= '$failure';
      }
    }

    // Admin > Voice Recognition shows every capture, including silence and
    // failures, with enough detail to tell a dead mic from a deaf gate.
    unawaited(VoiceLog.instance.add(
      text: text,
      stats: VoiceCaptureStats(
        seconds: seconds,
        peak: peak,
        voicedSeconds: voiced,
        chunks: chunks,
        retried: retried,
        partial: partial,
        error: error,
      ),
    ));

    if (text.isEmpty) return null;
    return _parser.parse(text);
  }

  /// Decodes [audio] with the native energy gate disabled. One feed is
  /// enough: every sample counts as voiced, so `stop()` decodes the whole
  /// buffer. The model is borrowed from the parked context, so this costs
  /// one decode, not another model load.
  Future<String> _decodeBuffered(Uint8List audio) async {
    final session = await startWhisperLiveSession(
      modelPath: _modelPath!,
      lang: 'en',
      initialPrompt: _prompt,
      suppressNonSpeechTokens: true,
      keepModelLoaded: true,
      gateRmsMin: 0,
      gateVoiceRatio: 0,
      gateNoiseFloorCap: 0,
    );
    session.feed(audio);
    return (await session.stop().timeout(const Duration(seconds: 30)))
        .trim();
  }

  void _logFailure(String error) {
    unawaited(VoiceLog.instance.add(
      text: '',
      stats: VoiceCaptureStats(error: error),
    ));
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
    await _audioSub?.cancel();
    _audioSub = null;
    await _partialSub?.cancel();
    _partialSub = null;
    await _recorder.dispose();
    await _whisper.releaseModel();
    _ready = false;
  }
}
