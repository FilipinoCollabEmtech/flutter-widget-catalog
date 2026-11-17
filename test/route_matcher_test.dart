import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
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

  test('the same leader must survive consecutive frames', () {
    final tracker = RouteVoteTracker(confirmFrames: 3);
    final ranked = matcher.rank('17B');
    expect(tracker.observe(ranked)!.confirmed, isFalse);
    expect(tracker.observe(ranked)!.confirmed, isFalse);
    final third = tracker.observe(ranked)!;
    expect(third.confirmed, isTrue);
    expect(third.agreements, 3);
  });

  test('evidence decays, so a stale route does not win by inertia', () {
    final tracker = RouteVoteTracker(confirmFrames: 1);
    tracker.observe(matcher.rank('17B'));
    // Several empty frames later the previous leader must be gone.
    for (var i = 0; i < 12; i++) {
      tracker.observe(const []);
    }
    expect(tracker.observe(const []), isNull);
  });
}
