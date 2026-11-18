import 'route_matcher.dart';

/// Snapshot of everything the scanner has read so far.
class Accumulation {
  const Accumulation({
    this.code,
    this.score = 0,
    this.runnerUp = 0,
    this.runnerUpCode,
    this.observations = 0,
    this.fromCode = false,
    this.readings = const [],
  });

  /// Best route so far, or null when nothing has been read yet.
  final String? code;

  /// Sum of the evidence that supported [code].
  final double score;

  /// The same sum for the second-best route — this is what makes a tie visible.
  final double runnerUp;

  /// Second-best route, when it is close enough to be worth mentioning.
  final String? runnerUpCode;

  /// How many distinct readings contributed.
  final int observations;

  /// True when at least one frame read the code itself.
  final bool fromCode;

  /// The distinct readings behind [code], oldest first. Shown in the scanner so
  /// "it forgot what I just scanned" is visibly untrue.
  final List<String> readings;

  double get margin => score - runnerUp;

  /// Whether the runner-up is close enough that naming only [code] would be
  /// misleading (17B/17C/17D all serve Apas-Carbon, for instance).
  bool get isCloseCall => runnerUpCode != null && margin < 25;

  /// Enough to name a route.
  ///
  /// A code read is decisive on its own. Anything weaker needs two separate
  /// readings first — but *not* a margin, because several routes genuinely
  /// share a destination and no amount of scanning separates them. Refusing to
  /// answer there is a dead end; the tie is reported instead via [isCloseCall].
  bool get ready =>
      code != null &&
      (fromCode || (score >= 90 && observations >= 2));

  @override
  String toString() =>
      '${code ?? '—'} ${score.toStringAsFixed(0)}/${runnerUp.toStringAsFixed(0)}'
      ' obs=$observations${fromCode ? ' code' : ''}';
}

/// Collects evidence across frames instead of judging each one alone.
///
/// The camera never shows the same text twice: one frame gets the code, the
/// next gets the destination board, a third catches a street sign. A per-frame
/// "did this frame win" test throws nearly all of that away, which is why the
/// scanner previously needed several *identical* frames in a row.
///
/// This keeps every distinct reading and adds it to the routes it supports,
/// while ignoring an exact repeat so a stationary camera cannot inflate a score
/// by staring at one word.
class RouteAccumulator {
  /// Evidence below this is noise (one weak word overlapping).
  static const floor = 40.0;

  /// Subtracted from a frame's score so repeated weak support never adds up to
  /// a false conclusion on its own.
  static const perFramePenalty = 35.0;

  final Map<String, double> _scores = {};
  final Set<String> _seenReadings = {};
  final List<String> _readings = [];
  int _observations = 0;
  bool _fromCode = false;

  bool get isEmpty => _observations == 0;

  void reset() {
    _scores.clear();
    _seenReadings.clear();
    _readings.clear();
    _observations = 0;
    _fromCode = false;
  }

  /// Current standing, without adding anything.
  Accumulation get current {
    final readings = List<String>.unmodifiable(_readings);
    if (_scores.isEmpty) {
      return Accumulation(readings: readings, observations: _observations);
    }
    final sorted = _scores.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final best = sorted.first;
    return Accumulation(
      code: best.key,
      score: best.value,
      runnerUp: sorted.length > 1 ? sorted[1].value : 0,
      runnerUpCode: sorted.length > 1 ? sorted[1].key : null,
      observations: _observations,
      fromCode: _fromCode,
      readings: readings,
    );
  }

  /// Adds one frame's reading. Safe to call with an empty reading or a repeat.
  Accumulation add(String text, List<RouteCandidate> ranked) {
    if (ranked.isEmpty) return current;
    final key = normalize(text);
    if (key.isEmpty) return current;
    // The same reading twice is not new evidence.
    if (!_seenReadings.add(key)) return current;

    _observations++;
    final shown = text.trim();
    if (shown.isNotEmpty) {
      _readings.add(shown.length > 24 ? shown.substring(0, 24) : shown);
      if (_readings.length > 8) _readings.removeAt(0);
    }
    for (final c in ranked) {
      if (c.score < floor) continue;
      _scores[c.code] = (_scores[c.code] ?? 0) + (c.score - perFramePenalty);
      if (c.score >= 100) _fromCode = true;
    }
    return current;
  }
}
