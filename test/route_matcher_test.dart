import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:seeruta/services/route_accumulator.dart';
import 'package:seeruta/services/route_matcher.dart';

/// Exercises the scorer against the real bundled dataset, so the test fails if
/// either the scoring or `tools/extract_route_data.py` output drifts.
void main() {
  late RouteMatcher matcher;

  setUpAll(() {
    final raw = File('assets/data/cebu_route_landmarks.json').readAsStringSync();
    matcher = RouteMatcher.fromJson(raw);
  });

  test('loads every route in the catalogue', () {
    expect(matcher.isEmpty, isFalse);
    // The four Mactan codes are intentionally absent: no map polyline exists
    // for them, so a match would be unshowable.
    final codes = matcher.rank('17B').map((c) => c.code).toSet();
    expect(codes, contains('17B'));
  });

  test('exact code is the strongest possible reading', () {
    final top = matcher.rank('17B').first;
    expect(top.code, '17B');
    expect(top.score, 100);
  });

  test('a near-miss code does not leak into its neighbour', () {
    // 04I and 04L differ by one glyph, which is exactly what OCR confuses.
    final codes = matcher.rank('04I').map((c) => c.code).toList();
    expect(codes.first, '04I');
    expect(codes, isNot(contains('04L')));
  });

  test('two endpoints are enough to triangulate without the code', () {
    final ranked = matcher.rank('APAS CARBON');
    expect(ranked, isNotEmpty);
    // 17B/17C/17D share both endpoints; any of them is a defensible answer.
    expect(ranked.first.code, anyOf('17B', '17C', '17D'));
    expect(ranked.first.score, greaterThanOrEqualTo(85));
    // Endpoints alone must not pretend to distinguish them.
    expect(ranked.first.confidence, lessThan(0.9));
  });

  test('the most common word on Cebu signs carries no weight', () {
    // "CEBU" appears across the catalogue, so reading it proves nothing. This
    // is the false-confidence case that naive clue-counting gets wrong.
    expect(matcher.rank('CEBU'), isEmpty);
    expect(matcher.rank('CEBU CITY'), isEmpty);
  });

  test('a unique landmark decides the answer', () {
    final ranked = matcher.rank('GAISANO COUNTRY MALL');
    expect(ranked.first.code, '22I');
    expect(ranked.first.confidence, greaterThan(0.5));
  });

  test('OCR spelling slips still match the landmark', () {
    final ranked = matcher.rank('GUADALUPPE');
    expect(ranked, isNotEmpty);
    expect(
      ranked.map((c) => c.code),
      anyOf(
        contains('06B'),
        contains('06C'),
        contains('06G'),
        contains('06H'),
      ),
    );
  });

  test('accents and punctuation normalise away', () {
    expect(normalize('Sto Niño Brgy. Hall'), 'STO NINO BRGY HALL');
    expect(normalize('Osmeña Blvd'), 'OSMENA BLVD');
  });

  test('reading the code is enough on its own', () {
    final acc = RouteAccumulator().add('17B', matcher.rank('17B'));
    expect(acc.code, '17B');
    expect(acc.fromCode, isTrue);
    expect(acc.ready, isTrue);
  });

  test('evidence from separate frames is combined', () {
    final acc = RouteAccumulator();
    // A full destination board, then a partial one. Neither frame alone is
    // enough; together they are.
    final first = acc.add('APAS CARBON', matcher.rank('APAS CARBON'));
    expect(first.ready, isFalse, reason: 'one reading is never enough');

    final second = acc.add('APAS', matcher.rank('APAS'));
    expect(second.observations, 2);
    expect(second.ready, isTrue);
    expect(second.code, anyOf('17B', '17C', '17D'));
    // Those three genuinely share both endpoints, so the sheet must say so.
    expect(second.isCloseCall, isTrue);
    expect(second.runnerUpCode, isNotNull);
  });

  test('the same reading twice is not new evidence', () {
    final acc = RouteAccumulator();
    acc.add('GAISANO COUNTRY MALL', matcher.rank('GAISANO COUNTRY MALL'));
    final again = acc.add(
      'GAISANO COUNTRY MALL',
      matcher.rank('GAISANO COUNTRY MALL'),
    );
    expect(again.observations, 1);
    expect(again.code, '22I');
  });

  test('a word that proves nothing never becomes ready', () {
    final acc = RouteAccumulator();
    acc.add('CEBU', matcher.rank('CEBU'));
    final after = acc.add('CEBU CITY', matcher.rank('CEBU CITY'));
    expect(after.ready, isFalse);
    expect(after.code, isNull);
  });

  test('reset clears the ledger', () {
    final acc = RouteAccumulator()..add('17B', matcher.rank('17B'));
    acc.reset();
    expect(acc.isEmpty, isTrue);
    expect(acc.current.code, isNull);
    expect(acc.current.readings, isEmpty);
  });

  test('two landmarks from one route triangulate and both are remembered', () {
    // The real complaint: scan "Basak", move to "Ibabao", and the first word
    // must still count. Basak is shared by three routes, Ibabao by exactly one,
    // so together they pin 09F.
    final acc = RouteAccumulator();

    final first = acc.add('BASAK', matcher.rank('BASAK'));
    expect(first.code, anyOf('09C', '09F', '09G'));
    expect(first.ready, isFalse, reason: 'Basak alone is shared by three');

    final second = acc.add('IBABAO', matcher.rank('IBABAO'));
    expect(second.code, '09F');
    expect(second.observations, 2);
    expect(second.readings, containsAll(<String>['BASAK', 'IBABAO']));
    expect(second.ready, isTrue);
  });

  test('holding the phone still does not pile up evidence', () {
    final acc = RouteAccumulator();
    acc.add('IBABAO', matcher.rank('IBABAO'));
    final again = acc.add('Ibabao', matcher.rank('Ibabao'));
    expect(again.observations, 1);
    expect(again.readings.length, 1);
  });
}
