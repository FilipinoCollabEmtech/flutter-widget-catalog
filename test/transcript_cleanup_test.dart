import 'package:flutter_test/flutter_test.dart';
import 'package:seeruta/services/transcript_cleanup.dart';

void main() {
  group('collapseRepeatedPhrases', () {
    test('collapses a repeated code phrase', () {
      const raw = 'code zero eight g code zero eight g code zero eight g';
      expect(collapseRepeatedPhrases(raw), 'code zero eight g');
    });

    test('collapses a repeated multi-word command', () {
      const raw = 'where am i where am i where am i';
      expect(collapseRepeatedPhrases(raw), 'where am i');
    });

    test('collapses a repeated single word', () {
      expect(collapseRepeatedPhrases('code code code 04l'), 'code 04l');
    });

    test('leaves two repeated words alone', () {
      // "zero zero four" is a legitimate way to say 004.
      expect(
        collapseRepeatedPhrases('code zero zero four l'),
        'code zero zero four l',
      );
    });

    test('leaves distinct text alone', () {
      expect(
        collapseRepeatedPhrases('code 04l pila ang pamasahe'),
        'code 04l pila ang pamasahe',
      );
    });

    test('preserves the first occurrence casing', () {
      expect(collapseRepeatedPhrases('Code 04L code 04l CODE 04L'), 'Code 04L');
    });

    test('empty and short input is unchanged', () {
      expect(collapseRepeatedPhrases(''), '');
      expect(collapseRepeatedPhrases('scan'), 'scan');
    });
  });
}
