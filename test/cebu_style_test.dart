import 'package:flutter_test/flutter_test.dart';
import 'package:seeruta/pages/cebu_style.dart';

void main() {
  group('Cebu raster style', () {
    final style = buildCebuRasterStyle(
      mbtilesPath: '/data/app/cebu_city_v3.mbtiles',
      glyphsDir: '/data/app/glyphs',
    );

    test('declares one raster source pointing at the MBTiles', () {
      final sources = style['sources'] as Map<String, dynamic>;
      expect(sources, hasLength(1));

      final source = sources['cebu-raster'] as Map<String, dynamic>;
      expect(source['type'], 'raster');
      expect(source['tileSize'], 256);
      expect(source['tiles'], ['mbtiles:///data/app/cebu_city_v3.mbtiles']);
      expect(source['minzoom'], kCebuBasemapSourceMinZoom);
      expect(source['maxzoom'], kCebuBasemapSourceMaxZoom);
      expect(source['bounds'], kCebuBasemapBounds);
    });

    test('renders the raster above an opaque background', () {
      final layers = style['layers'] as List<dynamic>;
      expect(layers.map((l) => l['id']), ['background', 'cebu-raster']);

      final raster = layers[1] as Map<String, dynamic>;
      expect(raster['type'], 'raster');
      expect(raster['source'], 'cebu-raster');
    });

    test('camera stays inside the raster coverage', () {
      expect(kCebuMapMinZoom, 12);
      expect(kCebuMapInitialZoom, 12);
      expect(kCebuMapMaxZoom, 13);
      expect(kCebuMapMinZoom, lessThanOrEqualTo(kCebuMapInitialZoom));
      expect(kCebuMapInitialZoom, lessThanOrEqualTo(kCebuMapMaxZoom));
      expect(kCebuMapMaxZoom, kCebuBasemapSourceMaxZoom);
    });

    test('Cebu City bounds are declared', () {
      expect(kCebuBasemapBounds, [123.7, 10.1, 124.0, 10.6]);
      expect(kCebuBasemapSourceMinZoom, 10);
      expect(kCebuBasemapSourceMaxZoom, 13);
    });
  });
}
