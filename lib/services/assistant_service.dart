import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:whisper_ggml/whisper_ggml.dart';

import 'assistant_command_parser.dart';

/// Offline voice pipeline for the SeeRuta Assistant (English + Tagalog).
///
/// mic (record, 16 kHz mono PCM16)
///   -> live whisper.cpp transcription (bundled ggml-tiny-q5_1, ~31 MB)
///   -> deterministic command grammar (AssistantCommandParser)
///
/// Everything runs on-device with no network. The wake word ("SeeRuta",
/// openWakeWord via flutter_onnxruntime) is a later phase; for now capture
/// starts when the Home mic button is tapped and stops on the next tap or
/// after [_maxCapture] seconds.
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

  final AssistantCommandParser _parser;
  final String _prompt;
  final WhisperController _whisper = WhisperController();
  final AudioRecorder _recorder = AudioRecorder();
  FlutterTts? _tts;

  String? _modelPath;
  bool _ready = false;
  Future<bool>? _prepareFuture;
  WhisperLiveSession? _session;
  bool _capturing = false;

  /// Speech rate: 1.0 is normal on Android; slightly slower is easier to
  /// follow for screen-reader users. Shared with the Settings page so its
  /// spoken confirmation matches the assistant's voice.
  static const double speechRate = 0.55;

  /// Decoding prompt that biases whisper toward the command vocabulary and
  /// the real route codes. Lower-case and unpunctuated on purpose: decoding
  /// mimics the prompt's style, and the parser prefers raw words.
  static String _buildPrompt(Set<String> routeCodes) =>
      'SeeRuta code ${routeCodes.join(' ')} '
      'where am I nearest scan help repeat stop '
      'asa ko tabang ulit usab hinto undang pila pamasahe magkano';

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

  /// Starts mic capture and the live transcription session.
  /// Returns false when the mic permission is missing or the service is
  /// not ready.
  Future<bool> startCapture() async {
    if (!_ready || _capturing) return false;
    if (!await _recorder.hasPermission()) return false;
    await _tts?.stop(); // never transcribe our own voice
    final stream = await _recorder.startStream(const RecordConfig(
      encoder: AudioEncoder.pcm16bits,
      sampleRate: 16000,
      numChannels: 1,
    ));
    _session = await _whisper.transcribeLive(
      modelPath: _modelPath,
      pcm16Stream: stream,
      lang: 'auto',
      initialPrompt: _prompt,
      // Street noise can otherwise decode as "[applause]"-style tags.
      suppressNonSpeechTokens: true,
      // Park the model in native memory so the next utterance starts fast.
      keepModelLoaded: true,
    );
    _capturing = true;
    return true;
  }

  /// Ends capture and parses the transcript.
  /// Returns null when nothing intelligible was heard.
  Future<AssistantCommand?> stopCapture() async {
    final session = _session;
    if (!_capturing || session == null) return null;
    _capturing = false;
    _session = null;
    // Closing the mic stream ends the session on its own; stop() is
    // idempotent, so calling it explicitly is safe either way.
    await _recorder.stop();
    final text = (await session.stop()).trim();
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
