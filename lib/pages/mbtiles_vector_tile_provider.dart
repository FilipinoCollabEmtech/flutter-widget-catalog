import 'dart:typed_data';

import 'package:mbtiles/mbtiles.dart';
import 'package:vector_map_tiles/vector_map_tiles.dart';

/// Vector tile provider that reads MBTiles (`.pbf`) tiles from disk via SQLite.
class MbtilesVectorTileProvider implements VectorTileProvider {
  final MbTiles _mbtiles;
  final int maxZoom;

  MbtilesVectorTileProvider({required String mbtilesPath, this.maxZoom = 14})
      : _mbtiles = MbTiles(mbtilesPath: mbtilesPath);

  @override
  Future<Uint8List> provide(TileIdentity tile) async {
    final tmsY = ((1 << tile.z) - 1) - tile.y;
    final bytes = _mbtiles.getTile(z: tile.z, x: tile.x, y: tmsY);
    if (bytes == null) {
      throw ProviderException(
        message: 'Tile not found: z=${tile.z}, x=${tile.x}, y=$tmsY',
        retryable: Retryable.none,
        statusCode: 404,
      );
    }
    return bytes;
  }

  @override
  int get maximumZoom => maxZoom;

  @override
  int get minimumZoom => 0;

  @override
  TileProviderType get type => TileProviderType.vector;

  void dispose() {
    _mbtiles.dispose();
  }
}
