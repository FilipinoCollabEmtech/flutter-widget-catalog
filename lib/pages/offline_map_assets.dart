import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show AssetManifest, rootBundle;
import 'package:path_provider/path_provider.dart';

import 'cebu_style.dart';

/// Where MapLibre should load things from.
class OfflineMapPaths {
  const OfflineMapPaths({required this.stylePath});

  /// Absolute path of the generated style.json (pass to MapLibreMap.styleString).
  final String stylePath;
}

/// MapLibre (native) can only read files, not Flutter assets, so on first run
/// we copy the MBTiles and the glyph (font) files into app storage and write
/// a style.json whose sources point at those copies.
class OfflineMapAssets {
  static const String _mbtilesAsset = 'assets/maps/cebu_city.mbtiles';
  static const String _glyphsAssetDir = 'assets/glyphs/';

  /// Bump this when you ship a new MBTiles so devices re-copy it instead of
  /// keeping the old file.
  static const int _dataVersion = 1;

  static Future<OfflineMapPaths> prepare() async {
    final base = await getApplicationSupportDirectory();
    final dir = Directory('${base.path}/maplibre');
    await dir.create(recursive: true);

    // 1. MBTiles
    final mbtiles = File('${dir.path}/cebu_city_v$_dataVersion.mbtiles');
    if (!await mbtiles.exists()) {
      await _copyAsset(_mbtilesAsset, mbtiles);
    }

    // 2. Glyphs: every .pbf under assets/glyphs/ keeps its relative path.
    final glyphsDir = Directory('${dir.path}/glyphs');
    final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
    final glyphAssets = manifest
        .listAssets()
        .where((a) => a.startsWith(_glyphsAssetDir) && a.endsWith('.pbf'))
        .toList();

    if (glyphAssets.isEmpty) {
      debugPrint('No glyph files found under $_glyphsAssetDir - '
          'the map will draw without labels.');
    }

    for (final asset in glyphAssets) {
      final relative = asset.substring(_glyphsAssetDir.length);
      final out = File('${glyphsDir.path}/$relative');
      if (!await out.exists()) {
        await out.parent.create(recursive: true);
        await _copyAsset(asset, out);
      }
    }

    // 3. Style: rewritten on every launch so style edits need no reinstall.
    final style = buildCebuLightStyle(
      mbtilesPath: mbtiles.path,
      glyphsDir: glyphsDir.path,
    );
    final styleFile = File('${dir.path}/style.json');
    await styleFile.writeAsString(jsonEncode(style), flush: true);

    return OfflineMapPaths(stylePath: styleFile.path);
  }

  static Future<void> _copyAsset(String asset, File target) async {
    final data = await rootBundle.load(asset);
    final bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
    await target.writeAsBytes(bytes, flush: true);
  }
}
