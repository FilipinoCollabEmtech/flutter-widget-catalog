import 'package:flutter_test/flutter_test.dart';
import 'package:seeruta/services/voice_log.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('add keeps newest first and ignores blank text', () async {
    final log = VoiceLog();
    await log.add('code zero four L');
    await log.add('   ');
    await log.add('asa ko');
    expect(
      log.entries.value.map((e) => e.text).toList(),
      ['asa ko', 'code zero four L'],
    );
  });

  test('entries persist across instances', () async {
    final first = VoiceLog();
    await first.add('pila ang pamasahe');

    final second = VoiceLog();
    await second.ensureLoaded();
    expect(second.entries.value.single.text, 'pila ang pamasahe');
    expect(second.entries.value.single.time, isA<DateTime>());
  });

  test('clear removes entries and the persisted copy', () async {
    final log = VoiceLog();
    await log.add('tabang');
    await log.clear();
    expect(log.entries.value, isEmpty);

    final reloaded = VoiceLog();
    await reloaded.ensureLoaded();
    expect(reloaded.entries.value, isEmpty);
  });

  test('caps the log at maxEntries, dropping the oldest', () async {
    final log = VoiceLog();
    for (var i = 0; i < VoiceLog.maxEntries + 5; i++) {
      await log.add('line $i');
    }
    expect(log.entries.value.length, VoiceLog.maxEntries);
    expect(log.entries.value.first.text,
        'line ${VoiceLog.maxEntries + 4}');
    expect(log.entries.value.last.text, 'line 5');
  });

  test('corrupt persisted lines are skipped', () async {
    SharedPreferences.setMockInitialValues({
      'seeRutaVoiceLog': <String>['not json', '{"t": 1, "x": "hello"}'],
    });
    final log = VoiceLog();
    await log.ensureLoaded();
    expect(log.entries.value.single.text, 'hello');
  });
}
