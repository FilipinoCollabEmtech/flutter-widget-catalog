import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// What one capture looked like, so an empty transcript can be explained from
/// the Admin panel alone (mic level, speech gate, retry, errors).
class VoiceCaptureStats {
  const VoiceCaptureStats({
    this.seconds = 0,
    this.peak = 0,
    this.voicedSeconds = 0,
    this.chunks = 0,
    this.retried = false,
    this.tailSeconds = 0,
    this.decodeMs = 0,
    this.partial = '',
    this.error,
  });

  /// Audio captured, in seconds.
  final double seconds;

  /// Loudest DC-corrected RMS, 0..1 of full scale.
  final double peak;

  /// Audio above the speech gate, in seconds.
  final double voicedSeconds;

  /// Number of PCM chunks received from the microphone.
  final int chunks;

  /// The speech-trimmed decode heard nothing, so the whole captured buffer
  /// was decoded again (still gate-free). Non-empty only when the trim may
  /// have cut a soft word.
  final bool retried;

  /// Silence after the last voiced chunk, in seconds. Together with
  /// [decodeMs] this is the time from the user's last word to the result.
  final double tailSeconds;

  /// Wall-clock time spent in the decoder, in milliseconds. Includes the
  /// full-buffer retry when [retried] is true.
  final int decodeMs;

  /// Legacy: last partial transcript from the removed live decoder. Kept so
  /// entries written by older builds still parse; new captures leave it
  /// empty.
  final String partial;

  /// Capture or decoding failure, when there was one.
  final String? error;

  /// True when the microphone delivered at least some audio.
  bool get hasAudio => chunks > 0 && seconds > 0;
}

/// One finalized capture, as heard by the Assistant.
class VoiceLogEntry {
  const VoiceLogEntry({
    required this.time,
    required this.text,
    this.stats = const VoiceCaptureStats(),
  });

  /// When the capture finished (local device time).
  final DateTime time;

  /// The final transcript returned by the recognizer. Empty when the
  /// recognizer heard nothing (still logged, with [stats]).
  final String text;

  final VoiceCaptureStats stats;

  bool get heard => text.isNotEmpty;

  Map<String, Object> toJson() => {
        't': time.millisecondsSinceEpoch,
        'x': text,
        's': stats.seconds,
        'p': stats.peak,
        'v': stats.voicedSeconds,
        'c': stats.chunks,
        'r': stats.retried,
        if (stats.tailSeconds > 0) 'g': stats.tailSeconds,
        if (stats.decodeMs > 0) 'd': stats.decodeMs,
        if (stats.partial.isNotEmpty) 'q': stats.partial,
        if (stats.error != null) 'e': stats.error!,
      };

  static VoiceLogEntry? fromJson(String raw) {
    try {
      final map = jsonDecode(raw);
      if (map is! Map) return null;
      final text = map['x'];
      final time = map['t'];
      if (text is! String || time is! int) return null;
      double number(String key) => switch (map[key]) {
            final num value => value.toDouble(),
            _ => 0,
          };
      return VoiceLogEntry(
        time: DateTime.fromMillisecondsSinceEpoch(time),
        text: text,
        stats: VoiceCaptureStats(
          seconds: number('s'),
          peak: number('p'),
          voicedSeconds: number('v'),
          chunks: switch (map['c']) {
            final int value => value,
            _ => 0,
          },
          retried: map['r'] == true,
          tailSeconds: number('g'),
          decodeMs: switch (map['d']) {
            final int value => value,
            _ => 0,
          },
          partial: map['q'] is String ? map['q'] as String : '',
          error: map['e'] is String ? map['e'] as String : null,
        ),
      );
    } catch (_) {
      return null; // Skip corrupt lines instead of losing the whole log.
    }
  }
}

/// On-device log of what the voice recognizer heard, shown in
/// Admin > Voice Recognition.
///
/// Every finished capture is recorded, including ones that heard nothing:
/// the mic level and duration in [VoiceCaptureStats] are what makes a silent
/// capture diagnosable without a debugger. Entries are newest-first, capped
/// at [maxEntries], and persisted in shared_preferences. Admin-only research
/// data: nothing leaves the device.
class VoiceLog {
  VoiceLog();

  /// App-wide instance used by the Assistant and the Admin page.
  static final VoiceLog instance = VoiceLog();

  static const _prefsKey = 'seeRutaVoiceLog';
  static const maxEntries = 100;

  /// Newest first. Listeners (Admin page) rebuild on every change.
  final ValueNotifier<List<VoiceLogEntry>> entries =
      ValueNotifier<List<VoiceLogEntry>>(const []);

  Future<void>? _loadFuture;

  /// Loads persisted transcripts once. Safe to call repeatedly.
  Future<void> ensureLoaded() => _loadFuture ??= _load();

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getStringList(_prefsKey) ?? const [];
      final loaded = <VoiceLogEntry>[];
      for (final line in raw) {
        final entry = VoiceLogEntry.fromJson(line);
        if (entry != null) loaded.add(entry);
      }
      // Persisted newest-first; sorting keeps that promise even if an old
      // build or a partial write left the list out of order.
      loaded.sort((a, b) => b.time.compareTo(a.time));
      entries.value = List.unmodifiable(loaded);
    } catch (error) {
      debugPrint('VoiceLog load failed: $error');
    }
  }

  /// Appends one finished capture (newest first).
  ///
  /// Empty transcripts are kept on purpose when they carry diagnostics.
  Future<void> add({
    required String text,
    VoiceCaptureStats stats = const VoiceCaptureStats(),
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty && !stats.hasAudio && stats.error == null) return;
    await ensureLoaded();
    final updated = <VoiceLogEntry>[
      VoiceLogEntry(
        time: DateTime.now(),
        text: trimmed,
        stats: stats,
      ),
      ...entries.value,
    ];
    if (updated.length > maxEntries) {
      updated.removeRange(maxEntries, updated.length);
    }
    entries.value = List.unmodifiable(updated);
    await _persist();
  }

  /// Removes every stored capture.
  Future<void> clear() async {
    await ensureLoaded();
    entries.value = const [];
    await _persist();
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(
        _prefsKey,
        [for (final entry in entries.value) jsonEncode(entry.toJson())],
      );
    } catch (error) {
      debugPrint('VoiceLog persist failed: $error');
    }
  }
}
