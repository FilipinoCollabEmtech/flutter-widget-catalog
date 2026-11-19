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
import 'utterance_audio.dart';
import 'voice_activity.dart';
import 'voice_log.dart';

/// Offline voice pipeline for the SeeRuta Assistant (English + Cebuano).
///
/// mic (record, 16 kHz mono PCM16)
///   -> buffered PCM, speech end detected on the fly
///   -> one whisper.cpp decode of the finished utterance
///   -> deterministic command grammar (AssistantCommandParser)
///
/// Everything runs on-device with no network. Whisper has no Cebuano
/// language token, so decoding runs in English mode (`lang: 'en'`, which is
/// also much faster and more deterministic than `'auto'`) and Cebuano
/// commands are absorbed by the parser's Cebuano word tables.
///
/// There is deliberately **no streaming decode**. whisper_ggml's live mode
/// re-decodes the whole growing window every 1.5 s of voiced audio, which
/// costs O(n²) inference on a phone: a ten-second phrase needed ~40 s of
/// decoding, so the final `stop()` sat behind that backlog and timed out
/// with an empty transcript. A finished command is only a few seconds long,
/// so one decode after the capture ends is both faster and complete.
///
/// Every chunk is buffered in memory. When the capture ends, the buffer is
/// trimmed to the speech region (silence would only cost decode time and
/// invite hallucination) and decoded once with the native energy gate fully
/// open. A quiet speaker or a loud street therefore cannot make the gate
/// drop the sentence.
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

  /// Audio kept for decoding (s); above [maxCapture] so a slow chunk
  /// boundary can never cut the end of the utterance.
  static const int _maxBufferedSeconds = 15;

  /// One decode of a 12 s worst-case clip, on a slow phone, with room to
  /// spare. A normal 2–5 s command finishes far inside this.
  static const Duration _decodeTimeout = Duration(seconds: 45);

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

  StreamSubscription<Uint8List>? _audioSub;
  bool _capturing = false;

  /// Every chunk of the current utterance, decoded once at the end.
  final BytesBuilder _audio = BytesBuilder(copy: true);
  VoiceActivityDetector _vad = VoiceActivityDetector();
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
  /// first utterance does not pay the multi-second model load when it is
  /// decoded. Call in the background once the Assistant is enabled;
  /// idempotent.
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

  /// Opens the mic and buffers audio until [stopCapture] or [onAutoStop].
  /// Returns false when the permission is missing or the recorder cannot
  /// start. [onAutoStop] fires once when the utterance ends by itself
  /// (silence after speech, or nothing said within the timeout).
  ///
  /// No decoder runs during capture, so the mic can open immediately and
  /// there is no window in which its audio is dropped. The one decode
  /// happens after the utterance ends, when the whole clip is available.
  Future<bool> startCapture({void Function()? onAutoStop}) async {
    if (!_ready || _capturing) return false;
    if (!await _recorder.hasPermission()) {
      _logFailure('Microphone permission denied');
      return false;
    }
    await _tts?.stop(); // never transcribe our own voice
    _onAutoStop = onAutoStop;
    _resetCaptureState();

    try {
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
      try {
        await _recorder.stop();
      } catch (_) {}
      _logFailure('$error');
      return false;
    }
  }

  void _resetCaptureState() {
    _audio.clear();
    _vad = VoiceActivityDetector();
    _captureError = null;
  }

  /// Buffers every chunk for the end-of-utterance decode; the detector only
  /// decides when the utterance is over.
  void _onAudioChunk(Uint8List chunk) {
    if (!_capturing) return;
    if (_audio.length < _maxBufferedSeconds * 16000 * 2) {
      _audio.add(chunk);
    }
    if (_vad.addChunk(chunk)) _fireAutoStop();
  }

  void _fireAutoStop() {
    final callback = _onAutoStop;
    if (callback == null) return;
    _onAutoStop = null; // fire once
    // Leave the audio callback before the UI tears the capture down.
    scheduleMicrotask(callback);
  }

  /// Ends capture, decodes the utterance once, and parses the transcript.
  /// Returns null when nothing intelligible was heard.
  Future<AssistantCommand?> stopCapture() async {
    if (!_capturing) return null;
    _capturing = false;
    _onAutoStop = null;

    final seconds = _vad.totalSeconds;
    final peak = _vad.peak;
    final voiced = _vad.voicedSeconds;
    final chunks = _vad.chunks;
    final speechStart = _vad.speechStartSample;
    final speechEnd = _vad.speechEndSample;
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

    var error = _captureError;
    var text = '';
    var retried = false;
    var decodeTimedOut = false;

    // Nothing above the mic noise floor: do not spend 40 s decoding room
    // tone. A tap that heard nothing is still logged with its stats.
    if (chunks > 0 && peak >= 0.002) {
      final hasSpeech = speechStart >= 0 && speechEnd > speechStart;
      final prepared = UtteranceAudio.prepare(
        buffered,
        firstSample: hasSpeech ? speechStart : null,
        endSample: hasSpeech ? speechEnd : null,
      );

      try {
        text = (await _decodeBuffered(prepared)).trim();
      } on TimeoutException catch (failure) {
        // The worker may still be decoding; do not start a second session
        // on top of it.
        decodeTimedOut = true;
        debugPrint('Assistant decode timed out: $failure');
        error ??= '$failure';
      } catch (failure) {
        debugPrint('Assistant decode failed: $failure');
        error ??= '$failure';
      }

      // The trimmed clip is what the speech detector heard. If that decoded
      // to nothing, the detector may have cut a soft word; decode the whole
      // buffer once, still gate-free.
      if (text.isEmpty &&
          !decodeTimedOut &&
          prepared.lengthInBytes < buffered.lengthInBytes) {
        retried = true;
        try {
          text = (await _decodeBuffered(UtteranceAudio.prepare(buffered)))
              .trim();
        } catch (failure) {
          debugPrint('Assistant fallback decode failed: $failure');
          error ??= '$failure';
        }
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
        error: error,
      ),
    ));

    if (text.isEmpty) return null;
    return _parser.parse(text);
  }

  /// Decodes [audio] with the native energy gate disabled.
  ///
  /// The first `feed` runs inference once, synchronously in the worker
  /// isolate, and `stop` then returns that text — there is no growing-window
  /// re-decode. The model is borrowed from the parked context, so this costs
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
    return (await session.stop().timeout(_decodeTimeout)).trim();
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
    await _recorder.dispose();
    await _whisper.releaseModel();
    _ready = false;
  }
}
