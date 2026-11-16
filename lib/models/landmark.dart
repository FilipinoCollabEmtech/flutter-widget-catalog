import 'package:latlong2/latlong.dart';

/// A point of interest in Cebu City.
///
/// Loaded from `assets/data/landmarks.csv` — one row per POI:
///
///   name,lat,lng,category,code,barangay,address
///
/// `lat`/`lng` are WGS84 decimal degrees with at least 5 dp (~1.1 m).
/// Fields after `category` are optional. `code` is the scan payload used by
/// the code-matching step; `barangay` skips the polygon lookup if supplied.
class Landmark {
  final String name;
  final LatLng point;
  final String category;
  final String? code;
  final String? barangay;
  final String? address;

  const Landmark({
    required this.name,
    required this.point,
    required this.category,
    this.code,
    this.barangay,
    this.address,
  });

  /// Parse one CSV row. Fields after `category` are optional. Quoted fields
  /// are supported so names containing commas survive.
  factory Landmark.fromCsv(String line) {
    final fields = _splitCsv(line);
    if (fields.length < 4) {
      throw FormatException(
        'landmark row needs name,lat,lng,category: ${line.trim()}',
      );
    }
    final lat = double.tryParse(fields[1].trim());
    final lng = double.tryParse(fields[2].trim());
    if (lat == null || lng == null) {
      throw FormatException(
        'bad coordinates in landmark row: ${line.trim()}',
      );
    }
    return Landmark(
      name: fields[0].trim(),
      point: LatLng(lat, lng),
      category: fields[3].trim(),
      code: _opt(fields, 4),
      barangay: _opt(fields, 5),
      address: _opt(fields, 6),
    );
  }

  static String? _opt(List<String> fields, int index) {
    if (index >= fields.length) return null;
    final value = fields[index].trim();
    return value.isEmpty ? null : value;
  }
}

/// Splits a CSV line, honouring double-quoted fields (including "" escapes).
List<String> _splitCsv(String line) {
  final out = <String>[];
  final buffer = StringBuffer();
  var inQuotes = false;

  for (var i = 0; i < line.length; i++) {
    final char = line[i];
    if (inQuotes) {
      if (char == '"') {
        if (i + 1 < line.length && line[i + 1] == '"') {
          buffer.write('"');
          i++;
        } else {
          inQuotes = false;
        }
      } else {
        buffer.write(char);
      }
    } else {
      if (char == '"') {
        inQuotes = true;
      } else if (char == ',') {
        out.add(buffer.toString());
        buffer.clear();
      } else {
        buffer.write(char);
      }
    }
  }
  out.add(buffer.toString());
  return out;
}