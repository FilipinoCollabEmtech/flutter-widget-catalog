import 'package:flutter_test/flutter_test.dart';
import 'package:seeruta/services/voice_log.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('add keeps newest first', () async {
    final log = VoiceLog();
    await log.add(text: 'code zero four L');
    await log.add(text: 'asa ko');
    expect(
      log.entries.value.map((e) => e.text).toList(),
      ['asa ko', 'code zero four L'],
    );
  });

  test('empty captures are kept when they carry diagnostics', () async {
    final log = VoiceLog();
    await log.add(
      text: '  ',
      stats: const VoiceCaptureStats(
        seconds: 3.2,
        peak: 0.04,
        voicedSeconds: 0.9,
        chunks: 80,
      ),
    );
    expect(log.entries.value, hasLength(1));
    expect(log.entries.value.single.heard, isFalse);
    expect(log.entries.value.single.stats.seconds, 3.2);
    expect(log.entries.value.single.stats.peak, 0.04);
  });

  test('an entirely empty capture is ignored', () async {
    final log = VoiceLog();
    await log.add(text: '   ');
    expect(log.entries.value, isEmpty);
  });

  test('captures persist across instances, with stats', () async {
    final first = VoiceLog();
    await first.add(
      text: 'pila ang pamasahe',
      stats: const VoiceCaptureStats(
        seconds: 4.5,
        peak: 0.12,
        voicedSeconds: 2.0,
        chunks: 90,
        retried: true,
        tailSeconds: 0.8,
        decodeMs: 3100,
        partial: 'pila ang',
      ),
    );

    final second = VoiceLog();
    await second.ensureLoaded();
    final entry = second.entries.value.single;
    expect(entry.text, 'pila ang pamasahe');
    expect(entry.time, isA<DateTime>());
    expect(entry.stats.seconds, 4.5);
    expect(entry.stats.peak, 0.12);
    expect(entry.stats.voicedSeconds, 2.0);
    expect(entry.stats.chunks, 90);
    expect(entry.stats.retried, isTrue);
    expect(entry.stats.tailSeconds, 0.8);
    expect(entry.stats.decodeMs, 3100);
    expect(entry.stats.partial, 'pila ang');
  });

  test('clear removes entries and the persisted copy', () async {
    final log = VoiceLog();
    await log.add(text: 'tabang');
    await log.clear();
    expect(log.entries.value, isEmpty);

    final reloaded = VoiceLog();
    await reloaded.ensureLoaded();
    expect(reloaded.entries.value, isEmpty);
  });

  test('caps the log at maxEntries, dropping the oldest', () async {
    final log = VoiceLog();
    for (var i = 0; i < VoiceLog.maxEntries + 5; i++) {
      await log.add(text: 'line $i');
    }
    expect(log.entries.value.length, VoiceLog.maxEntries);
    expect(log.entries.value.first.text,
        'line ${VoiceLog.maxEntries + 4}');
    expect(log.entries.value.last.text, 'line 5');
  });

  test('corrupt lines are skipped and legacy entries still load', () async {
    SharedPreferences.setMockInitialValues({
      'seeRutaVoiceLog': <String>[
        'not json',
        '{"t": 1, "x": "legacy entry"}',
        '{"t": 2, "x": "", "s": 2.5, "c": 40, "e": "mic stream error"}',
      ],
    });
    final log = VoiceLog();
    await log.ensureLoaded();
    expect(log.entries.value, hasLength(2));
    // Stored newest-first: the error capture precedes the legacy line.
    expect(log.entries.value.first.stats.seconds, 2.5);
    expect(log.entries.value.first.stats.error, 'mic stream error');
    expect(log.entries.value.last.text, 'legacy entry');
    expect(log.entries.value.last.stats.seconds, 0);
    expect(log.entries.value.last.stats.tailSeconds, 0);
    expect(log.entries.value.last.stats.decodeMs, 0);
  });
}
