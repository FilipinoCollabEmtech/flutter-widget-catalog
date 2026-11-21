import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';

import '../models/barangay.dart';
import 'geojson.dart';

/// Loads barangay GeoJSON and persists user "seen" tags locally.
class BarangayService {
  static const _geoJsonAsset = 'assets/maps/barangays.geojson';
  static const _seenKey = 'barangay_seen.json';

  /// Fallback name used where the PSGC join produced a collision.
  static const _altNameKeys = ['ADM4_EN', 'name', 'brgy'];

  final List<Barangay> _all = [];
  final ValueNotifier<List<Barangay>> barangays =
      ValueNotifier<List<Barangay>>([]);

  List<Barangay> get all => List.unmodifiable(_all);

  /// Load GeoJSON from assets.
  ///
  /// Expected shape is a GeoJSON FeatureCollection of Polygon or
  /// MultiPolygon features carrying ADM4/PSGC properties:
  ///
  /// ```
  /// "properties": {"psgc_name": "Basak Pardo", "ADM4_PCODE": "PH0702217005",
  ///                "ADM3_EN": "Cebu City (Capital)", "psgc_code": "0730600005"}
  /// ```
  ///
  /// Name resolution is `psgc_name` first. Where `psgc_code` repeats inside a
  /// single city/municipality the PSGC join mis-mapped the record, so those
  /// rows fall back to `ADM4_EN`, which is distinct for all of them.
  /// The primary key is `ADM4_PCODE` — unique across all 1,203 features,
  /// unlike `psgc_code` (3 codes shared by 7 Cebu City records).
  Future<void> load() async {
    final raw = await rootBundle.loadString(_geoJsonAsset);
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    final features = decoded['features'] as List<dynamic>? ?? [];

    // Pass 1 — read geometry and count (city, psgc_code) pairs so the
    // colliding rows can be recognised before any name is chosen.
    final rows = <_Row>[];
    final collisions = <String, int>{};

    for (final f in features) {
      if (f is! Map) continue;
      final props = f['properties'];
      final geom = f['geometry'];
      if (geom is! Map) continue;

      final parts = outerRingsOf(geom['type'] as String?, geom['coordinates']);
      if (parts.isEmpty) continue;

      final city = firstString(props, kCityKeys) ?? '';
      final psgc = firstString(props, const ['psgc_code']) ?? '';
      final key = '$city|$psgc';
      if (psgc.isNotEmpty) {
        collisions[key] = (collisions[key] ?? 0) + 1;
      }
      rows.add(_Row(props, city, psgc, parts));
    }

    // Pass 2 — resolve names and build the model.
    final seen = await _loadSeen();
    final loaded = <Barangay>[];

    for (final row in rows) {
      final collided =
          row.psgc.isNotEmpty && (collisions['${row.city}|${row.psgc}'] ?? 0) > 1;
      final name = (collided ? firstString(row.props, _altNameKeys) : null) ??
          firstString(row.props, kNameKeys) ??
          'Barangay';
      final code = firstString(row.props, kKeyKeys) ?? '';
      final wasSeen = seen.containsKey(code) || (code.isEmpty && seen.containsKey(name));
      final seenData = seen[code] ?? (code.isEmpty ? seen[name] : null);

      loaded.add(Barangay(
        name: name,
        code: code,
        city: row.city,
        parts: row.parts,
        seen: wasSeen,
        seenAt: seenData != null
            ? DateTime.tryParse(seenData['at'] ?? '')
            : null,
        note: seenData != null ? seenData['note'] as String? : null,
      ));
    }

    _all
      ..clear
      ..addAll(loaded);
    barangays.value = List.unmodifiable(_all);
  }

  /// Mark/unmark a barangay as seen and persist.
  Future<void> setSeen(String code, bool seen, {String? note}) async {
    final idx = _all.indexWhere((b) => b.code == code);
    if (idx == -1) return;

    final now = DateTime.now();
    final updated = _all[idx].copyWith(
      seen: seen,
      seenAt: seen ? now : null,
      note: seen ? note : null,
    );
    _all[idx] = updated;
    barangays.value = List.unmodifiable(_all);

    final seenMap = await _loadSeen();
    if (seen) {
      seenMap[updated.code] = {'at': now.toIso8601String(), 'note': note ?? ''};
    } else {
      seenMap.remove(updated.code);
    }
    await _saveSeen(seenMap);
  }

  /// Update note for a seen barangay.
  Future<void> setNote(String code, String note) async {
    final idx = _all.indexWhere((b) => b.code == code);
    if (idx == -1) return;
    final updated = _all[idx].copyWith(note: note);
    _all[idx] = updated;
    barangays.value = List.unmodifiable(_all);

    final seenMap = await _loadSeen();
    final entry = seenMap[updated.code];
    if (entry != null) {
      entry['note'] = note;
      await _saveSeen(seenMap);
    }
  }

  /// All barangays currently intersected by [route].
  List<Barangay> intersectedBy(RoutePlan route) {
    return _all.where((b) => route.passesThrough(b)).toList();
  }

  /// All seen barangays.
  List<Barangay> get seenList => _all.where((b) => b.seen).toList();

  // ---------- persistence ----------

  Future<String> _localPath() async {
    final dir = await getApplicationDocumentsDirectory();
    return '${dir.path}/$_seenKey';
  }

  Future<Map<String, dynamic>> _loadSeen() async {
    try {
      final file = File(await _localPath());
      if (!await file.exists()) return {};
      final raw = await file.readAsString();
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return {};
    }
  }

  Future<void> _saveSeen(Map<String, dynamic> data) async {
    final file = File(await _localPath());
    await file.writeAsString(jsonEncode(data));
  }
}

/// One parsed GeoJSON feature, held between the two passes of [load].
class _Row {
  final dynamic props;
  final String city;
  final String psgc;
  final List<List<LatLng>> parts;

  _Row(this.props, this.city, this.psgc, this.parts);
}
