/// Cleans up a raw speech-to-text transcript before it is logged or parsed.
///
/// whisper-tiny is an open-vocabulary model, so a short, code-shaped
/// utterance can occasionally send it into a repetition loop. With the
/// latency pass deliberately disabling temperature fallback, that loop is
/// returned as-is and fills Admin > Voice Recognition with the same phrase
/// over and over. Collapsing consecutive repeated phrases keeps the log
/// readable and gives the command parser one clean copy to work with.
library;

/// Collapses a phrase that repeats consecutively at least [minRepeats] times.
///
/// A "phrase" is between 1 and [maxPhraseWords] words. Matching is
/// case-insensitive, but the first occurrence is preserved verbatim.
/// Repeated single words are only collapsed at three or more, so a genuine
/// "zero zero four" (two zeros) is left alone.
String collapseRepeatedPhrases(
  String input, {
  int maxPhraseWords = 6,
  int minRepeats = 3,
}) {
  final words = input
      .trim()
      .split(RegExp(r'\s+'))
      .where((word) => word.isNotEmpty)
      .toList(growable: false);
  if (words.length < minRepeats) return words.join(' ');

  var current = words;
  var changed = true;
  while (changed) {
    changed = false;
    for (var size = 1; size <= maxPhraseWords; size++) {
      if (size * minRepeats > current.length) break;
      for (var start = 0; start + size * minRepeats <= current.length;) {
        final phrase = current.sublist(start, start + size);
        var repeats = 1;
        while (start + (repeats + 1) * size <= current.length &&
            _samePhrase(current, start + repeats * size, phrase)) {
          repeats++;
        }
        if (repeats >= minRepeats) {
          current = [
            ...current.take(start + size),
            ...current.skip(start + repeats * size),
          ];
          changed = true;
        } else {
          start++;
        }
      }
    }
  }
  return current.join(' ');
}

bool _samePhrase(List<String> words, int start, List<String> phrase) {
  for (var i = 0; i < phrase.length; i++) {
    if (words[start + i].toLowerCase() != phrase[i].toLowerCase()) {
      return false;
    }
  }
  return true;
}
