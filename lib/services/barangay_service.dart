import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';

import '../models/barangay.dart';

/// Loads barangay GeoJSON and persists user "seen" tags locally.
class BarangayService {
  static const _geoJsonAsset = 'assets/maps/barangays.geojson';
  static const _seenKey = 'barangay_seen.json';

  final List<Barangay> _all = [];
  final ValueNotifier<List<Barangay>> barangays =
      ValueNotifier<List<Barangay>>([]);

  List<Barangay> get all => List.unmodifiable(_all);

  /// Load GeoJSON from assets. Expects FeatureCollection with Polygon
  /// features and properties.name / properties.code.
  Future<void> load() async {
    final raw = await rootBundle.loadString(_geoJsonAsset);
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    final features = decoded['features'] as List<dynamic>? ?? [];

    final loaded = <Barangay>[];
    final seen = await _loadSeen();

    for (final f in features) {
      final props = (f['properties'] ?? <String, dynamic>{}) as Map;
      final geom = f['geometry'] as Map<String, dynamic>;
      final type = geom['type'] as String?;
      final coords = geom['coordinates'] as List<dynamic>?;

      if (type != 'Polygon' || coords == null) continue;

      final rings = <List<LatLng>>[];
      for (final ring in coords) {
        final points = <LatLng>[];
        for (final pt in ring) {
          if (pt is List && pt.length >= 2) {
            points.add(LatLng(pt[1] as double, pt[0] as double));
          }
        }
        if (points.isNotEmpty) rings.add(points);
      }

      if (rings.isEmpty) continue;

      final name = (props['name'] ?? props['brgy'] ?? 'Barangay').toString();
      final code = (props['code'] ?? props['psgc'] ?? '').toString();
      final wasSeen = seen.containsKey(code) || seen.containsKey(name);
      final seenData = seen[code] ?? seen[name];

      loaded.add(Barangay(
        name: name,
        code: code,
        polygon: rings.first,
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
