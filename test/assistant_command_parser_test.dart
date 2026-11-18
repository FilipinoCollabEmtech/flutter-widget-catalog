import 'package:flutter_test/flutter_test.dart';
import 'package:seeruta/services/assistant_command_parser.dart';

/// The real codes from assets/data/routes.db (RouteCode table, 2026-11-18).
const _codes = [
  '01K', '03A', '03Q', '04B', '04L', '06B', '07B', '09C', '10H', '11A',
  '12L', '13B', '13C', '13H', '14D', '17B', '17C', '20A', '20B', '21A',
  '21B', '22A', '22D', '22I', '24', '24A', '24B', '24F', '24G', '24I',
  '25', '25A', '26', '62A', '62B',
];

AssistantCommandParser _parser() => AssistantCommandParser(routeCodes: _codes);

void main() {
  group('route codes — English', () {
    test('digit-by-digit with keyword', () {
      final c = _parser().parse('code zero four L');
      expect(c.type, AssistantCommandType.findRoute);
      expect(c.routeCode, '04L');
      expect(c.matched, isTrue);
    });

    test('"oh" and letter words', () {
      final c = _parser().parse('oh four el');
      expect(c.type, AssistantCommandType.findRoute);
      expect(c.routeCode, '04L');
    });

    test('tens words compose', () {
      expect(_parser().parse('twenty four G').routeCode, '24G');
    });

    test('tens word alone is a bare code (25 exists, bare 20 does not)', () {
      expect(_parser().parse('bente singko').routeCode, '25');
      // "twenty" alone is not a real code; one-edit fuzzy match -> 20A.
      expect(_parser().parse('twenty').routeCode, '20A');
    });

    test('spanish-derived teens used by real codes', () {
      expect(_parser().parse('code trese B').routeCode, '13B');
      expect(_parser().parse('disisyete C').routeCode, '17C');
    });

    test('whisper-style single-token codes', () {
      expect(_parser().parse('04l').routeCode, '04L');
      expect(_parser().parse('24g').routeCode, '24G');
    });
  });

  group('route codes — Filipino and Cebuano', () {
    test('cebuano digit words with wake variant', () {
      final c = _parser().parse('si ruta sero apat el');
      expect(c.type, AssistantCommandType.findRoute);
      expect(c.routeCode, '04L');
    });

    test('cebuano napulo composition', () {
      expect(_parser().parse('napulo ug usa A').routeCode, '11A');
    });

    test('taglish tens', () {
      expect(_parser().parse('bente singko').routeCode, '25');
    });

    test('filipino fillers stripped', () {
      final c = _parser().parse('code po nga zero four L');
      expect(c.routeCode, '04L');
    });
  });

  group('fuzzy matching', () {
    test('dropped leading zero', () {
      // "4B" ties between 04B and 24B (both one insertion); the deterministic
      // tie-break resolves lexicographically to 04B.
      expect(_parser().parse('code upat B').routeCode, '04B');
    });

    test('transposed digits', () {
      expect(_parser().parse('forty two B').routeCode, '24B');
    });

    test('misheard letter within one edit', () {
      // "24E" is one substitution from 24B / 24F / 24G / 24I / 24A —
      // lexicographic tie-break picks 24A.
      expect(_parser().parse('twenty four E').routeCode, '24A');
    });

    test('nonexistent code reports candidate, not a wrong route', () {
      final c = _parser().parse('code zero eight G');
      expect(c.type, AssistantCommandType.findRoute);
      expect(c.matched, isFalse);
      expect(c.routeCode, isNull);
      expect(c.candidate, '08G');
    });
  });

  group('commands', () {
    test('where am I — english, filipino, cebuano', () {
      expect(_parser().parse('where am i').type, AssistantCommandType.whereAmI);
      expect(_parser().parse('nasaan ako').type, AssistantCommandType.whereAmI);
      expect(_parser().parse('asa ko').type, AssistantCommandType.whereAmI);
    });

    test('help — english, filipino, cebuano', () {
      expect(_parser().parse('help').type, AssistantCommandType.help);
      expect(_parser().parse('tulong').type, AssistantCommandType.help);
      expect(_parser().parse('tabang').type, AssistantCommandType.help);
    });

    test('repeat', () {
      expect(_parser().parse('repeat').type, AssistantCommandType.repeat);
      expect(_parser().parse('ulitin po').type, AssistantCommandType.repeat);
      expect(_parser().parse('usab').type, AssistantCommandType.repeat);
    });

    test('stop / cancel', () {
      expect(_parser().parse('stop').type, AssistantCommandType.stop);
      expect(_parser().parse('hinto').type, AssistantCommandType.stop);
      expect(_parser().parse('undang').type, AssistantCommandType.stop);
    });

    test('scan', () {
      expect(_parser().parse('scan').type, AssistantCommandType.scan);
      expect(_parser().parse('iskan').type, AssistantCommandType.scan);
    });

    test('fare — with and without a route code', () {
      final plain = _parser().parse('pila ang pamasahe');
      expect(plain.type, AssistantCommandType.fare);
      expect(plain.routeCode, isNull);

      final withCode = _parser().parse('magkano sa 24G');
      expect(withCode.type, AssistantCommandType.fare);
      expect(withCode.routeCode, '24G');
    });

    test('nearest', () {
      expect(_parser().parse('nearest jeepney').type,
          AssistantCommandType.nearest);
      expect(_parser().parse('duol').type, AssistantCommandType.nearest);
    });

    test('code keyword with no code asks back (unknown)', () {
      expect(_parser().parse('code').type, AssistantCommandType.unknown);
      expect(_parser().parse('ruta').type, AssistantCommandType.unknown);
    });

    test('unintelligible transcript', () {
      final c = _parser().parse('hello world po');
      expect(c.type, AssistantCommandType.unknown);
      expect(c.routeCode, isNull);
    });
  });

  group('wake word stripping', () {
    test('leading wake phrase removed', () {
      final c = _parser().parse('see ruta code zero four L');
      expect(c.routeCode, '04L');
    });

    test('wake with one transcription slip still removed', () {
      final c = _parser().parse('siruta asa ko');
      expect(c.type, AssistantCommandType.whereAmI);
    });

    test('route keyword mid-sentence is not treated as wake word', () {
      final c = _parser().parse('route code zero four L');
      expect(c.routeCode, '04L');
    });
  });
}
