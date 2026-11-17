import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:latlong2/latlong.dart';

import '../models/landmark.dart';

/// Loads Cebu City landmarks from `assets/data/landmarks.csv`.
///
/// The CSV has a header row and columns:
///   name,lat,lng,category,code,barangay,address
///
/// Fields may contain commas inside quoted values (e.g. "Plaza Sugbo, Cebu
/// City, Cebu, Philippines").  Only `name`, `lat` and `lng` are required;
/// the rest default to empty strings.  Rows that cannot be parsed are skipped.
///
/// If the asset is missing (e.g. the researcher has not added the data file
/// yet) [load] returns an empty list instead of throwing, so the rest of the
/// app keeps working.
class LandmarkService {
  static const _asset = 'assets/data/landmarks.csv';

  final List<Landmark> _all = [];

  List<Landmark> get all => List.unmodifiable(_all);

  ValueNotifier<List<Landmark>> landmarks = ValueNotifier<List<Landmark>>([]);

  /// Parse the bundled CSV.  Safe to call when the asset is absent.
  Future<void> load() async {
    _all.clear();
    try {
      final raw = await rootBundle.loadString(_asset);
      for (final line in _parseCsv(raw)) {
        if (line.isEmpty) continue;
        final fields = _splitCsvLine(line);
        if (fields.length < 3) continue;
        final name = fields[0].trim();
        final lat = double.tryParse(fields[1].trim());
        final lng = double.tryParse(fields[2].trim());
        if (name.isEmpty || lat == null || lng == null) continue;

        _all.add(Landmark(
          name: name,
          point: LatLng(lat, lng),
          category: fields.length > 3 ? fields[3].trim() : '',
          code: fields.length > 4 ? fields[4].trim() : '',
          barangay: fields.length > 5 ? fields[5].trim() : '',
          address: fields.length > 6 ? fields[6].trim() : '',
        ));
      }
    } catch (_) {
      // Asset missing or unreadable — leave the list empty.
    }
    landmarks.value = List.unmodifiable(_all);
  }

  /// Very small CSV parser that handles quoted fields containing commas.
  static List<String> _parseCsv(String raw) {
    final lines = <String>[];
    final buffer = StringBuffer();
    var inQuotes = false;
    for (var i = 0; i < raw.length; i++) {
      final ch = raw[i];
      if (ch == '"') {
        inQuotes = !inQuotes;
        buffer.write(ch);
      } else if (ch == '\n' && !inQuotes) {
        lines.add(buffer.toString());
        buffer.clear();
      } else if (ch == '\r') {
        // skip CR
      } else {
        buffer.write(ch);
      }
    }
    if (buffer.isNotEmpty) lines.add(buffer.toString());
    // Drop the header row.
    if (lines.isNotEmpty) lines.removeAt(0);
    return lines;
  }

  static List<String> _splitCsvLine(String line) {
    final fields = <String>[];
    final buffer = StringBuffer();
    var inQuotes = false;
    for (var i = 0; i < line.length; i++) {
      final ch = line[i];
      if (ch == '"') {
        inQuotes = !inQuotes;
      } else if (ch == ',' && !inQuotes) {
        fields.add(buffer.toString().replaceAll('"', ''));
        buffer.clear();
      } else {
        buffer.write(ch);
      }
    }
    fields.add(buffer.toString().replaceAll('"', ''));
    return fields;
  }
}
