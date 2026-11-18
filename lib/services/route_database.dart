import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart' show rootBundle;
import 'package:latlong2/latlong.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';

import '../models/route.dart';

/// Opens the bundled `assets/data/routes.db` (copied to app storage on first
/// launch) and exposes the route catalogue as [JeepneyRoute]s.
class RouteDatabase {
  RouteDatabase._();

  static const _asset = 'assets/data/routes.db';
  static const _fileName = 'routes.db';
  static Database? _db;

  /// Copy the asset to app storage (if needed) and open it.
  ///
  /// The bundled database carries a `PRAGMA user_version`.  On every launch
  /// we compare it with the copy on disk; when they differ (i.e. a new app
  /// version shipped an updated database) the old copy is overwritten so
  /// users never keep stale route data.
  static Future<Database> open() async {
    if (_db != null) return _db!;

    final dir = await getApplicationSupportDirectory();
    final file = File('${dir.path}/$_fileName');

    // Read the asset's user_version without extracting the whole file.
    final assetData = await rootBundle.load(_asset);
    final assetBytes = assetData.buffer.asUint8List(
      assetData.offsetInBytes,
      assetData.lengthInBytes,
    );
    // Write to a temp file so sqlite3 can read the version.
    final tmp = File('${dir.path}/_routes_tmp.db');
    await tmp.writeAsBytes(assetBytes, flush: true);
    final assetDb = sqlite3.open(tmp.path);
    final assetVersion = assetDb.userVersion;
    assetDb.dispose();
    await tmp.delete();

    int diskVersion = 0;
    if (await file.exists()) {
      final diskDb = sqlite3.open(file.path);
      diskVersion = diskDb.userVersion;
      diskDb.dispose();
    }
    final needsCopy = !await file.exists() || diskVersion != assetVersion;

    if (needsCopy) {
      await file.writeAsBytes(assetBytes, flush: true);
    }

    _db = sqlite3.open(file.path);
    return _db!;
  }

  /// Load all routes from the database.
  static Future<List<JeepneyRoute>> loadRoutes() async {
    final db = await open();
    final rows = db.select('''
      SELECT r.route_id, r.route_name, r.geometry,
             rc.code_text
      FROM Route r
      JOIN RouteCode rc ON rc.route_id = r.route_id
      ORDER BY rc.code_text
    ''');

    final routes = <JeepneyRoute>[];
    for (final row in rows) {
      final code = (row['code_text'] ?? '').toString();
      final name = (row['route_name'] ?? code).toString();
      final geometryJson = (row['geometry'] ?? '[]').toString();

      List<LatLng> polyline = const [];
      try {
        final decoded = jsonDecode(geometryJson);
        if (decoded is List) {
          polyline = [
            for (final p in decoded)
              if (p is List && p.length >= 2)
                LatLng((p[1] as num).toDouble(), (p[0] as num).toDouble()),
          ];
        }
      } catch (_) {}

      // Load stops for this route.
      final stopRows = db.select('''
        SELECT s.stop_name, s.latitude, s.longitude
        FROM Stop s
        JOIN RouteStop rs ON rs.stop_id = s.stop_id
        WHERE rs.route_id = ?
        ORDER BY rs.stop_sequence
      ''', [row['route_id']]);

      final stops = <LatLng>[];
      final stopNames = <String>[];
      for (final sr in stopRows) {
        final lat = sr['latitude'];
        final lng = sr['longitude'];
        if (lat is num && lng is num) {
          stops.add(LatLng(lat.toDouble(), lng.toDouble()));
        }
        stopNames.add((sr['stop_name'] ?? '').toString());
      }

      routes.add(JeepneyRoute(
        code: code,
        name: name,
        polyline: polyline,
        stops: stops,
        stopNames: stopNames,
      ));
    }
    return routes;
  }

  static void close() {
    _db?.dispose();
    _db = null;
  }

  /// Load all fare rules from the database.
  static Future<List<Map<String, dynamic>>> loadFareRules() async {
    final db = await open();
    final rows = db.select('SELECT * FROM FareRule');
    return rows.map((r) => Map<String, dynamic>.from(r)).toList();
  }

  /// Load all discount categories from the database.
  static Future<List<Map<String, dynamic>>> loadDiscounts() async {
    final db = await open();
    final rows = db.select('SELECT * FROM DiscountCategory');
    return rows.map((r) => Map<String, dynamic>.from(r)).toList();
  }
}