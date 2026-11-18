import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// One finalized voice-recognition result, as heard by the Assistant.
class VoiceLogEntry {
  const VoiceLogEntry({required this.time, required this.text});

  /// When the capture finished (local device time).
  final DateTime time;

  /// The final transcript returned by the recognizer.
  final String text;

  Map<String, Object> toJson() => {
        't': time.millisecondsSinceEpoch,
        'x': text,
      };

  static VoiceLogEntry? fromJson(String raw) {
    try {
      final map = jsonDecode(raw);
      if (map is! Map) return null;
      final text = map['x'];
      final time = map['t'];
      if (text is! String || time is! int) return null;
      return VoiceLogEntry(
        time: DateTime.fromMillisecondsSinceEpoch(time),
        text: text,
      );
    } catch (_) {
      return null; // Skip corrupt lines instead of losing the whole log.
    }
  }
}

/// On-device log of what the voice recognizer heard, shown in
/// Admin > Voice Recognition.
///
/// Transcripts are kept newest-first, capped at [maxEntries], and persisted
/// in shared_preferences so they survive restarts. Admin-only research data:
/// nothing leaves the device.
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
      entries.value = List.unmodifiable(loaded);
    } catch (error) {
      debugPrint('VoiceLog load failed: $error');
    }
  }

  /// Appends one finalized transcript (newest first). Ignores blank text.
  Future<void> add(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    await ensureLoaded();
    final updated = <VoiceLogEntry>[
      VoiceLogEntry(time: DateTime.now(), text: trimmed),
      ...entries.value,
    ];
    if (updated.length > maxEntries) {
      updated.removeRange(maxEntries, updated.length);
    }
    entries.value = List.unmodifiable(updated);
    await _persist();
  }

  /// Removes every stored transcript.
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
