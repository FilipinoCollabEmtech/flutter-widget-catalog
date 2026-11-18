import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/services.dart' show rootBundle;

/// Reference data for one route code: its two endpoints plus every place the
/// route is documented to pass.
///
/// Endpoints come from commutetour.com's route-code table, landmarks from its
/// per-route "passes along" lists (see `tools/extract_route_data.py`). This is
/// scraped reference data, not field-verified — treat it as evidence, not truth.
class RouteReference {
  const RouteReference({
    required this.code,
    required this.from,
    required this.to,
    required this.landmarks,
  });

  final String code;
  final String from;
  final String to;
  final List<String> landmarks;
}

/// One scored candidate, with the evidence that produced the score.
class RouteCandidate {
  const RouteCandidate({
    required this.code,
    required this.score,
    required this.confidence,
    required this.evidence,
  });

  final String code;

  /// 0..100. 100 means the code itself was read; 85+ means several independent
  /// landmarks agreed; below ~40 means "a word happened to overlap".
  final double score;

  /// 0..1, penalised when the runner-up is close behind.
  final double confidence;

  /// Human-readable reasons, shown in the scanner so a wrong match is
  /// debuggable instead of mysterious.
  final List<String> evidence;

  @override
  String toString() => '$code ${score.toStringAsFixed(0)} '
      '(${evidence.join(', ')})';
}

/// Scores recognized text against the route catalogue using weighted evidence.
///
/// The core idea is that not every word is equally informative. "CEBU" appears
/// in a third of the catalogue, so reading it proves almost nothing; "GAISANO
/// COUNTRY MALL" appears in exactly one route, so reading it nearly decides the
/// answer. Each key is therefore weighted by rarity (inverse document
/// frequency) before it contributes.
class RouteMatcher {
  RouteMatcher._(this._refs, this._keys);

  final List<RouteReference> _refs;
  final Map<String, List<_Key>> _keys;

  /// Routes whose endpoint or landmark matched, best first.
  static const assetPath = 'assets/data/cebu_route_landmarks.json';

  bool get isEmpty => _refs.isEmpty;

  /// The reference data for [code], if this catalogue has it.
  RouteReference? refFor(String code) {
    final upper = code.toUpperCase();
    for (final r in _refs) {
      if (r.code == upper) return r;
    }
    return null;
  }

  static Future<RouteMatcher> load({String asset = assetPath}) async {
    final raw = await rootBundle.loadString(asset);
    return fromJson(raw);
  }

  static RouteMatcher fromJson(String raw) {
    final map = jsonDecode(raw) as Map<String, dynamic>;
    final list = (map['routes'] as List).cast<Map<String, dynamic>>();
    final refs = [
      for (final r in list)
        RouteReference(
          code: (r['code'] as String).toUpperCase(),
          from: r['from'] as String? ?? '',
          to: r['to'] as String? ?? '',
          landmarks: [
            for (final l in (r['landmarks'] as List? ?? const []))
              l as String,
          ],
        ),
    ];

    // ---- rarity weights -------------------------------------------------
    final df = <String, int>{};
    void count(String phrase, Set<String> seen) {
      final key = normalize(phrase);
      if (key.isEmpty) return;
      if (seen.add(key)) df[key] = (df[key] ?? 0) + 1;
    }

    final perRoute = <String, Set<String>>{};
    for (final ref in refs) {
      final seen = perRoute.putIfAbsent(ref.code, () => <String>{});
      count(ref.from, seen);
      count(ref.to, seen);
      for (final l in ref.landmarks) {
        count(l, seen);
      }
    }

    final total = math.max(refs.length, 1);
    double weightOf(String phrase) {
      final key = normalize(phrase);
      final n = df[key] ?? 1;
      // ln(1 + N/df) * 2: a word in every route scores ~1.4, a word in one
      // route scores ~7.7. Clamped so nothing dominates outright.
      return (math.log(1 + total / n) * 2).clamp(0.5, 8.0).toDouble();
    }

    final keys = <String, List<_Key>>{};
    for (final ref in refs) {
      final out = <_Key>[];
      final seen = <String>{};

      void add(String phrase, bool endpoint, double role) {
        final key = normalize(phrase);
        if (key.isEmpty || key.length < 3) return;
        if (!seen.add(key)) return;
        out.add(_Key(key, weightOf(phrase) * role, endpoint));
      }

      add(ref.from, true, 2.0);
      add(ref.to, true, 2.0);
      for (final l in ref.landmarks) {
        add(l, false, 1.0);
      }
      keys[ref.code] = out;
    }

    return RouteMatcher._(refs, keys);
  }

  /// Ranks every route against [text], best first. Returns an empty list when
  /// nothing at all matched.
  List<RouteCandidate> rank(String text) {
    final normalized = normalize(text);
    if (normalized.isEmpty) return const [];
    final padded = ' $normalized ';
    final tokens = normalized.split(' ');
    final tokensLong = [
      for (final t in tokens)
        if (t.length >= 5) t,
    ];

    final out = <RouteCandidate>[];
    for (final ref in _refs) {
      final evidence = <String>[];
      final codeScore = _codeScore(ref.code, tokens, padded);
      if (codeScore > 0) evidence.add('code ${ref.code}');

      var textScore = 0.0;
      for (final key in _keys[ref.code] ?? const <_Key>[]) {
        if (padded.contains(' ${key.phrase} ')) {
          textScore += key.weight;
          if (evidence.length < 4) evidence.add(key.phrase);
          continue;
        }
        // OCR mangles long words ("MINGLANIELLA" for "MINGLANILLA"), so allow
        // a close spelling match, but only for substantial single words.
        if (key.phrase.contains(' ') || key.phrase.length < 5) continue;
        for (final token in tokensLong) {
          if ((token.length - key.phrase.length).abs() > 2) continue;
          if (_ratio(token, key.phrase) >= 0.82) {
            textScore += key.weight * 0.6;
            if (evidence.length < 4) evidence.add('~${key.phrase}');
            break;
          }
        }
      }

      final score = math.min(100.0, codeScore + math.min(85.0, textScore * 7));
      if (score < 1) continue;
      out.add(RouteCandidate(
        code: ref.code,
        score: score,
        confidence: 0,
        evidence: evidence,
      ));
    }

    out.sort((a, b) => b.score.compareTo(a.score));
    final top = out.take(5).toList();

    // Confidence is a margin, not an absolute: 60 points means much more when
    // the runner-up sits at 10 than when it sits at 55.
    for (var i = 0; i < top.length; i++) {
      final c = top[i];
      final gap = i == 0 && top.length == 1
          ? c.score
          : (i == 0 ? c.score - top[1].score : 0.0);
      final margin = (gap / 40).clamp(0.0, 1.0);
      top[i] = RouteCandidate(
        code: c.code,
        score: c.score,
        confidence: ((c.score / 100) * (0.5 + 0.5 * margin)).clamp(0.0, 1.0),
        evidence: c.evidence,
      );
    }
    return top;
  }

  /// 100 for an exact code token, less for a near-miss like `04I` vs `04L`.
  double _codeScore(String code, List<String> tokens, String padded) {
    final bare = code.startsWith('0') ? code.substring(1) : code;
    for (final t in tokens) {
      if (t == code || t == bare) return 100;
    }
    var best = 0.0;
    for (final t in tokens) {
      if (t.length < 2 || t.length > 5) continue;
      if (t.length != code.length) continue;
      final r = _ratio(t, code);
      // 0.75 is deliberately strict: 04I vs 04L is 0.67 and must NOT match.
      if (r >= 0.75) best = math.max(best, 55 + 30 * r);
    }
    return best;
  }
}

class _Key {
  const _Key(this.phrase, this.weight, this.endpoint);
  final String phrase;
  final double weight;
  final bool endpoint;
}

// ---- text normalisation -----------------------------------------------------

const _diacritics = {
  'á': 'a', 'à': 'a', 'â': 'a', 'ä': 'a', 'ã': 'a', 'å': 'a',
  'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e',
  'í': 'i', 'ì': 'i', 'î': 'i', 'ï': 'i',
  'ó': 'o', 'ò': 'o', 'ô': 'o', 'ö': 'o', 'õ': 'o',
  'ú': 'u', 'ù': 'u', 'û': 'u', 'ü': 'u',
  'ñ': 'n', 'ç': 'c',
};

/// Uppercase, strip accents, and reduce everything else to single spaces.
///
/// Accents matter: the dataset has "Sto Niño" and "Osmeña", but OCR and users
/// both produce "NINO" and "OSMENA".
String normalize(String input) {
  final buf = StringBuffer();
  for (final rune in input.toUpperCase().runes) {
    final ch = String.fromCharCode(rune);
    // The map is lowercase, but by now everything is uppercase: "NIÑO" arrives
    // as "NIÑO" with a capital Ñ, which is not in the table. Without the
    // lowercase retry, ñ becomes a space and "Sto Niño" indexes as "STO NI O".
    final flat = _diacritics[ch] ?? _diacritics[ch.toLowerCase()];
    if (flat != null) {
      buf.write(flat.toUpperCase());
    } else if (_isAlnum(rune)) {
      buf.write(ch);
    } else {
      buf.write(' ');
    }
  }
  return buf.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
}

bool _isAlnum(int rune) =>
    (rune >= 0x30 && rune <= 0x39) || (rune >= 0x41 && rune <= 0x5A);

/// Levenshtein similarity in 0..1.
double _ratio(String a, String b) {
  if (a == b) return 1;
  if (a.isEmpty || b.isEmpty) return 0;
  final prev = List<int>.generate(b.length + 1, (i) => i);
  final cur = List<int>.filled(b.length + 1, 0);
  for (var i = 1; i <= a.length; i++) {
    cur[0] = i;
    for (var j = 1; j <= b.length; j++) {
      final cost = a.codeUnitAt(i - 1) == b.codeUnitAt(j - 1) ? 0 : 1;
      cur[j] = math.min(
        math.min(cur[j - 1] + 1, prev[j] + 1),
        prev[j - 1] + cost,
      );
    }
    prev.setAll(0, cur);
  }
  return 1 - prev[b.length] / math.max(a.length, b.length);
}
