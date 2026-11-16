import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../models/landmark.dart';

/// Loads `assets/data/landmarks.csv` and answers text queries against it.
///
/// Search is landmark-only: typing matches the name, category, barangay or
/// address of a POI. Barangay boundaries themselves are not searchable —
/// they are drawn for context and highlighted when a route crosses them.
class LandmarkService {
  static const _asset = 'assets/data/landmarks.csv';

  final List<Landmark> _landmarks = [];

  List<Landmark> get all => List.unmodifiable(_landmarks);

  /// True once [load] has completed successfully.
  bool loaded = false;

  /// Parse the bundled CSV. Rows that fail to parse are skipped with a
  /// debugPrint rather than aborting the whole load, so one bad row cannot
  /// break search for the rest.
  Future<void> load() async {
    final raw = await rootBundle.loadString(_asset);
    final lines = raw.split(RegExp(r'\r\n|\r|\n'));
    final parsed = <Landmark>[];
    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty || trimmed.startsWith('#')) continue;
      try {
        parsed.add(Landmark.fromCsv(trimmed));
      } catch (e) {
        debugPrint('landmark_service: skipping row: $e');
      }
    }
    _landmarks
      ..clear
      ..addAll(parsed);
    loaded = true;
  }

  /// Landmarks whose text contains [query], case-insensitive.
  ///
  /// Matches the name first, then category, barangay and address, so a
  /// partial query still finds "Fuente Osmeña Circle" when typed as
  /// "fuente" or "circle".
  List<Landmark> search(String query) {
    final needle = query.trim().toLowerCase();
    if (needle.isEmpty) return const [];
    return _landmarks
        .where((l) => _matches(l, needle))
        .toList();
  }

  bool _matches(Landmark l, String needle) {
    return l.name.toLowerCase().contains(needle) ||
        l.category.toLowerCase().contains(needle) ||
        (l.barangay?.toLowerCase().contains(needle) ?? false) ||
        (l.address?.toLowerCase().contains(needle) ?? false);
  }

  /// Look up a single landmark by its scan code.
  Landmark? findByCode(String code) {
    final needle = code.trim();
    if (needle.isEmpty) return null;
    for (final l in _landmarks) {
      if (l.code != null && l.code!.trim() == needle) return l;
    }
    return null;
  }
}