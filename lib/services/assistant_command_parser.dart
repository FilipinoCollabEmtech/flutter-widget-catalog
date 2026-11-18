/// SeeRuta Assistant command parser (Phase 0 — pure Dart, no dependencies).
///
/// Turns a raw speech-to-text transcript into a structured command for the
/// route planner. Designed for a tiny closed command set spoken by PWD
/// commuters in English, Filipino and Cebuano, e.g.
///
///   "code zero four L"   -> findRoute 04L
///   "see ruta walog B"?  -> findRoute (fuzzy-matched against real codes)
///   "asa ko"             -> whereAmI
///   "pila ang pamasahe"  -> fare
///
/// There is intentionally NO model here: the intelligence is a normalization
/// table (digit/letter words in the three languages) plus a fuzzy match
/// against the real route codes, so transcription noise ("four B" -> 04B,
/// "forty two B" -> 24B) is absorbed deterministically.
///
/// The transcript arrives AFTER wake-word capture, but assistants often keep
/// a "SeeRuta ..." fragment at the start, so leading wake-word variants are
/// stripped as well.
library;

/// What the user asked for.
enum AssistantCommandType {
  /// Find / highlight a jeepney route ("code 04L").
  findRoute,

  /// Where am I right now.
  whereAmI,

  /// Nearest route / jeepney.
  nearest,

  /// Fare question ("pila ang pamasahe", possibly for a route code).
  fare,

  /// Open the code scanner.
  scan,

  /// Repeat the last spoken response.
  repeat,

  /// Stop / cancel the current interaction.
  stop,

  /// Speak the available command list.
  help,

  /// Transcript understood as speech but no command matched.
  unknown,
}

/// The parsed result of one utterance.
class AssistantCommand {
  const AssistantCommand({
    required this.type,
    required this.transcript,
    this.routeCode,
    this.candidate,
    this.matched = true,
  });

  /// What the user asked for.
  final AssistantCommandType type;

  /// The raw transcript this was parsed from (useful for logs and debugging).
  final String transcript;

  /// Route code to act on: the matched real code for [AssistantCommandType.findRoute]
  /// and [AssistantCommandType.fare], null when nothing was matched.
  final String? routeCode;

  /// The code as spoken, normalized, when no real route matched
  /// (e.g. the user said "08G" but only "24G" exists). The caller can answer
  /// "No route zero-eight-G" or offer the closest real code.
  final String? candidate;

  /// Whether [routeCode] exists in the route database.
  /// Only false for [AssistantCommandType.findRoute] near-misses.
  final bool matched;

  @override
  String toString() =>
      'AssistantCommand(${type.name}, code: $routeCode, candidate: $candidate, matched: $matched)';
}

/// Parses transcripts into [AssistantCommand]s.
///
/// Construct once with the real route codes (from `RouteCode.code_text` /
/// `JeepneyRoute.code`) and reuse it; parsing is synchronous and allocation
/// light, so it is safe to call per utterance.
class AssistantCommandParser {
  AssistantCommandParser({required Iterable<String> routeCodes})
      : _codes = routeCodes.map((c) => c.trim().toUpperCase()).toSet();

  /// Real route codes, upper-cased (e.g. {"04L", "24G", "24", "62A"}).
  final Set<String> _codes;

  AssistantCommand parse(String raw) {
    final transcript = raw.trim();
    var tokens = _normalize(raw);
    tokens = _stripWake(tokens);
    tokens = tokens.where((w) => !_fillers.contains(w)).toList();

    // Spoken route codes, e.g. "zero four L" -> "04L", "trese B" -> "13B".
    final runs = _codeRuns(tokens);

    // 1) Exact match.
    String? matchedCode;
    for (final run in runs) {
      if (_codes.contains(run)) {
        matchedCode = run;
        break;
      }
    }

    // 2) Fuzzy match: one edit (misheard digit/letter, dropped leading zero,
    //    transposed digits). Ties prefer the code that contains the spoken
    //    run ("4B" -> "04B" over "24B"), then the lexicographically first.
    if (matchedCode == null && runs.isNotEmpty) {
      final scored = <({String code, int dist, String run})>[];
      for (final run in runs) {
        for (final code in _codes) {
          final d = _osa(run, code);
          if (d <= 1) scored.add((code: code, dist: d, run: run));
        }
      }
      if (scored.isNotEmpty) {
        scored.sort((a, b) {
          if (a.dist != b.dist) return a.dist - b.dist;
          // A candidate that extends the spoken run ("20" -> "20A") beats one
          // that substitutes interior digits ("20" -> "24").
          final aPrefix = a.code.startsWith(a.run) ? 0 : 1;
          final bPrefix = b.code.startsWith(b.run) ? 0 : 1;
          if (aPrefix != bPrefix) return aPrefix - bPrefix;
          // Prefer candidates that keep the spoken shape: "24E" should not
          // degrade to bare "24" when 24A..24I exist.
          final aShape = _shape(a.run) != _shape(a.code) ? 1 : 0;
          final bShape = _shape(b.run) != _shape(b.code) ? 1 : 0;
          if (aShape != bShape) return aShape - bShape;
          final aHas = a.code.contains(a.run);
          final bHas = b.code.contains(b.run);
          if (aHas != bHas) return aHas ? -1 : 1;
          return a.code.compareTo(b.code);
        });
        matchedCode = scored.first.code;
      }
    }

    final spokenCode = runs.isEmpty
        ? null
        : runs.reduce((a, b) => a.length >= b.length ? a : b);

    // 3) Command keywords, highest priority first. Code presence wins over
    //    generic keywords because "code 24G" contains no command words, while
    //    "pila ang 24G" must stay a fare question for route 24G.
    if (_anyWord(tokens, _stopWords)) {
      return AssistantCommand(
        type: AssistantCommandType.stop,
        transcript: transcript,
      );
    }
    if (_anyWord(tokens, _repeatWords)) {
      return AssistantCommand(
        type: AssistantCommandType.repeat,
        transcript: transcript,
      );
    }
    if (_anyWord(tokens, _helpWords)) {
      return AssistantCommand(
        type: AssistantCommandType.help,
        transcript: transcript,
      );
    }
    if (_anyWord(tokens, _scanWords)) {
      return AssistantCommand(
        type: AssistantCommandType.scan,
        transcript: transcript,
      );
    }
    if (_hasAnyPhrase(tokens, _wherePhrases)) {
      return AssistantCommand(
        type: AssistantCommandType.whereAmI,
        transcript: transcript,
      );
    }
    if (_anyWord(tokens, _fareWords) || _hasAnyPhrase(tokens, _farePhrases)) {
      return AssistantCommand(
        type: AssistantCommandType.fare,
        routeCode: matchedCode,
        candidate: matchedCode == null ? spokenCode : null,
        matched: matchedCode != null,
        transcript: transcript,
      );
    }
    if (_anyWord(tokens, _nearestWords)) {
      return AssistantCommand(
        type: AssistantCommandType.nearest,
        transcript: transcript,
      );
    }
    if (matchedCode != null) {
      return AssistantCommand(
        type: AssistantCommandType.findRoute,
        routeCode: matchedCode,
        transcript: transcript,
      );
    }
    if (runs.isNotEmpty) {
      // Spoken like a code but no real route matched (e.g. "08G").
      return AssistantCommand(
        type: AssistantCommandType.findRoute,
        routeCode: null,
        candidate: spokenCode,
        matched: false,
        transcript: transcript,
      );
    }
    // A route keyword without any understandable code: ask which code.
    if (_anyWord(tokens, _routeWords)) {
      return AssistantCommand(
        type: AssistantCommandType.unknown,
        transcript: transcript,
      );
    }
    return AssistantCommand(
      type: AssistantCommandType.unknown,
      transcript: transcript,
    );
  }

  // ---- Normalization ------------------------------------------------------

  /// Lower-case, drop punctuation (apostrophes join: "dalawampu't" ->
  /// "dalawamput"), collapse whitespace.
  static List<String> _normalize(String raw) {
    final noApostrophes = raw.toLowerCase().replaceAll(RegExp(r"['’]"), '');
    final spaced = noApostrophes.replaceAll(RegExp(r'[^a-z0-9]+'), ' ');
    return spaced
        .split(' ')
        .where((w) => w.isNotEmpty)
        .toList(growable: false);
  }

  /// Drops leading wake-word variants ("see ruta", "siruta", "cebu roota", ...)
  /// allowing one transcription slip per token.
  static const _wakeVariants = <List<String>>[
    ['seeruta'],
    ['siruta'],
    ['see', 'ruta'],
    ['si', 'ruta'],
    ['sea', 'ruta'],
    ['see', 'roota'],
    ['cebu', 'ruta'],
    ['cebu', 'roota'],
    ['siruta', 'seeruta'],
  ];

  static List<String> _stripWake(List<String> tokens) {
    for (var n = _wakeVariants.map((v) => v.length).reduce(_max); n >= 1; n--) {
      if (tokens.length < n) continue;
      for (final variant in _wakeVariants) {
        if (variant.length != n) continue;
        var ok = true;
        for (var i = 0; i < n; i++) {
          if (tokens[i] != variant[i] && _osa(tokens[i], variant[i]) > 1) {
            ok = false;
            break;
          }
        }
        if (ok) return _stripWake(tokens.sublist(n).toList());
      }
    }
    return tokens;
  }

  /// Politeness / filler words that carry no command meaning in any of the
  /// three languages.
  static const _fillers = <String>{
    'po', 'man', 'nga', 'lang', 'ra', 'gud', 'please', 'paki', 'uy', //
    'na', 'ang', 'ung', 'yung', 'ba', 'sa', 'ng',
  };

  // ---- Digit and letter words --------------------------------------------

  /// Single-digit words -> digit. English, Filipino and Cebuano native plus
  /// the Spanish-derived forms universally used in Cebu street speech.
  static const _digitWords = <String, String>{
    // 0
    'zero': '0', 'oh': '0', 'o': '0', 'sero': '0',
    // 1
    'one': '1', 'isa': '1', 'usa': '1', 'uno': '1',
    // 2
    'two': '2', 'dalawa': '2', 'duha': '2', 'dos': '2',
    // 3
    'three': '3', 'tatlo': '3', 'tulo': '3', 'tres': '3',
    // 4
    'four': '4', 'apat': '4', 'upat': '4', 'kuwatro': '4',
    // 5
    'five': '5', 'lima': '5', 'singko': '5',
    // 6
    'six': '6', 'anim': '6', 'unom': '6', 'sais': '6',
    // 7
    'seven': '7', 'pito': '7', 'syete': '7',
    // 8
    'eight': '8', 'walo': '8', 'otso': '8',
    // 9
    'nine': '9', 'siyam': '9', 'nuwebe': '9',
  };

  /// Multi-digit number words emitted verbatim (teens used by real codes:
  /// 10H, 11A, 12L, 13B/C/H, 14D, 17B/C).
  static const _numberWords = <String, String>{
    'ten': '10', 'diyes': '10',
    'eleven': '11', 'onse': '11',
    'twelve': '12', 'dose': '12',
    'thirteen': '13', 'trese': '13',
    'fourteen': '14', 'katorse': '14',
    'fifteen': '15', 'kinse': '15',
    'sixteen': '16', 'disais': '16',
    'seventeen': '17', 'disisyete': '17', 'diesisyete': '17',
    'eighteen': '18', 'disiotso': '18', 'diesiotso': '18',
    'nineteen': '19', 'disinuwebe': '19', 'diesinuwebe': '19',
  };

  /// Tens words -> first digit; the unit digit is composed from the next
  /// token ("twenty four" -> 24, "bente singko" -> 25, "napulo ug usa" -> 11).
  /// Alone, a tens word yields D0 ("bente" -> 20, a real code).
  static const _tensWords = <String, String>{
    'twenty': '2', 'bente': '2', 'beinte': '2',
    'dalawampu': '2', 'dalawamput': '2', 'kawhaan': '2',
    'thirty': '3', 'trenta': '3',
    'forty': '4', 'kuwarenta': '4',
    'fifty': '5', 'singkuwenta': '5',
    'sixty': '6', 'sesenta': '6', 'saisenta': '6',
    'seventy': '7', 'setenta': '7',
    'eighty': '8', 'otsenta': '8',
    'ninety': '9', 'nobenta': '9',
    'napulo': '1', 'sampu': '1', 'sampo': '1',
  };

  /// Connectives skipped between a tens word and its unit.
  static const _connectives = <String>{'and', 'ug', 'at'};

  /// Letter words -> letter. Route codes only use A B C D F G H I K L Q, but
  /// every letter except O is accepted ("oh" is the digit 0, and no code has
  /// an O). Whisper may also emit the bare letter ("g") — handled directly.
  static const _letterWords = <String, String>{
    'a': 'A', 'ay': 'A',
    'bee': 'B', 'be': 'B',
    'cee': 'C', 'see': 'C', 'sea': 'C',
    'dee': 'D', 'de': 'D',
    'e': 'E',
    'ef': 'F',
    'gee': 'G', 'je': 'G', 'jee': 'G',
    'aitch': 'H', 'aych': 'H', 'etch': 'H',
    'i': 'I', 'eye': 'I', 'ai': 'I',
    'jay': 'J', 'jei': 'J',
    'kay': 'K',
    'ell': 'L', 'el': 'L',
    'em': 'M',
    'en': 'N',
    'pee': 'P',
    'cue': 'Q', 'kyu': 'Q',
    'ar': 'R',
    'ess': 'S', 'es': 'S',
    'tee': 'T',
    'you': 'U', 'yu': 'U',
    'vee': 'V',
    'ex': 'X',
    'why': 'Y', 'wai': 'Y',
    'zee': 'Z', 'zed': 'Z', 'zet': 'Z',
  };

  /// Whisper often emits "08g" / "4b" / "24" as one token.
  static final _rawCodeToken = RegExp(r'^(\d{1,2})([a-z])?$');

  /// Maps tokens to a flat stream of digit/letter items, then composes code
  /// runs: one or more digits followed by at most one letter.
  static List<String> _codeRuns(List<String> tokens) {
    // Items are single chars; a tens-word composition may push two.
    final items = <String>[];
    for (var i = 0; i < tokens.length; i++) {
      final t = tokens[i];
      final raw = _rawCodeToken.firstMatch(t);
      if (raw != null) {
        items.addAll(raw.group(1)!.split(''));
        final letter = raw.group(2);
        if (letter != null) items.add(letter.toUpperCase());
        continue;
      }
      if (_numberWords.containsKey(t)) {
        items.addAll(_numberWords[t]!.split(''));
        continue;
      }
      if (_tensWords.containsKey(t)) {
        final tens = _tensWords[t]!;
        var unit = '0';
        var j = i + 1;
        while (j < tokens.length && _connectives.contains(tokens[j])) {
          j++;
        }
        if (j < tokens.length && _digitWords.containsKey(tokens[j])) {
          unit = _digitWords[tokens[j]]!;
          i = j;
        }
        items.addAll([tens, unit]);
        continue;
      }
      if (_digitWords.containsKey(t)) {
        items.add(_digitWords[t]!);
        continue;
      }
      if (t.length == 1 && _isDigit(t)) {
        items.add(t);
        continue;
      }
      // A single letter ("g") or a letter word ("gee"). Bare "o" was already
      // consumed as the digit 0 above.
      final letter =
          _letterWords[t] ?? (t.length == 1 ? t.toUpperCase() : null);
      if (letter != null && _isLetter(letter)) {
        items.add(letter);
      }
    }

    // Compose runs: digits* letter?.
    final runs = <String>[];
    final digits = StringBuffer();
    String? letter;
    void flush() {
      if (digits.isNotEmpty) {
        runs.add(letter == null
            ? digits.toString()
            : '${digits.toString()}$letter');
      }
      digits.clear();
      letter = null;
    }

    for (final item in items) {
      if (_isDigit(item)) {
        if (letter != null) flush(); // "G" after a closed run starts anew.
        digits.write(item);
      } else if (_isLetter(item)) {
        if (letter == null) {
          letter = item;
        } else {
          flush(); // Second letter: close the run, restart with this letter.
          letter = item;
        }
      } else {
        flush();
      }
    }
    flush();
    return runs;
  }

  static bool _isDigit(String s) => s.length == 1 && s.codeUnitAt(0) >= 0x30 && s.codeUnitAt(0) <= 0x39;

  static bool _isLetter(String s) =>
      s.length == 1 && s.codeUnitAt(0) >= 0x41 && s.codeUnitAt(0) <= 0x5A;

  /// 1 when the string ends in a letter (code with a letter suffix), else 0.
  static int _shape(String s) =>
      s.isNotEmpty && _isLetter(s[s.length - 1]) ? 1 : 0;

  static int _max(int a, int b) => a > b ? a : b;

  // ---- Command keywords ---------------------------------------------------

  static const _stopWords = <String>{
    'stop', 'cancel', 'kansel', 'kansela', 'hinto', 'ihinto', 'undang', 'hunong',
  };
  static const _repeatWords = <String>{
    'repeat', 'again', 'ulit', 'ulitin', 'ulita', 'usab', 'usaba', 'balik', 'balika',
  };
  static const _helpWords = <String>{
    'help', 'tulong', 'tulungan', 'tabang', 'tabangan',
  };
  static const _scanWords = <String>{
    'scan', 'skan', 'iskan', 'eskanela', 'iskanela',
  };
  static const _fareWords = <String>{
    'fare', 'pamasahe', 'pamasaje', 'magkano', 'pila',
  };
  static const _farePhrases = <List<String>>[
    ['how', 'much'],
  ];
  static const _wherePhrases = <List<String>>[
    ['where', 'am', 'i'],
    ['nasaan', 'ako'],
    ['asa', 'ko'],
    ['asa', 'ako'],
  ];
  static const _nearestWords = <String>{
    'nearest', 'closest', 'malapit', 'malapitan', 'duol', 'kalayo',
  };
  static const _routeWords = <String>{
    'code', 'kodigo', 'route', 'routa', 'ruta',
  };

  static bool _anyWord(List<String> tokens, Set<String> words) =>
      tokens.any(words.contains);

  static bool _hasAnyPhrase(List<String> tokens, List<List<String>> phrases) {
    for (final phrase in phrases) {
      for (var i = 0; i + phrase.length <= tokens.length; i++) {
        var ok = true;
        for (var j = 0; j < phrase.length; j++) {
          if (tokens[i + j] != phrase[j]) {
            ok = false;
            break;
          }
        }
        if (ok) return true;
      }
    }
    return false;
  }

  // ---- Fuzzy matching -----------------------------------------------------

  /// Optimal-string-alignment distance (Damerau-Levenshtein with adjacent
  /// transpositions counted as one edit) — "42B" vs "24B" costs one edit.
  static int _osa(String a, String b) {
    final n = a.length;
    final m = b.length;
    if (n == 0) return m;
    if (m == 0) return n;
    final d = List.generate(
      n + 1,
      (_) => List<int>.filled(m + 1, 0),
      growable: false,
    );
    for (var i = 0; i <= n; i++) {
      d[i][0] = i;
    }
    for (var j = 0; j <= m; j++) {
      d[0][j] = j;
    }
    for (var i = 1; i <= n; i++) {
      for (var j = 1; j <= m; j++) {
        final cost = a.codeUnitAt(i - 1) == b.codeUnitAt(j - 1) ? 0 : 1;
        var best = d[i - 1][j] + 1;
        final ins = d[i][j - 1] + 1;
        if (ins < best) best = ins;
        final sub = d[i - 1][j - 1] + cost;
        if (sub < best) best = sub;
        if (i > 1 &&
            j > 1 &&
            a.codeUnitAt(i - 1) == b.codeUnitAt(j - 2) &&
            a.codeUnitAt(i - 2) == b.codeUnitAt(j - 1)) {
          final trans = d[i - 2][j - 2] + 1;
          if (trans < best) best = trans;
        }
        d[i][j] = best;
      }
    }
    return d[n][m];
  }
}
