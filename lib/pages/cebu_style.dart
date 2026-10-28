/// A trimmed, light OpenMapTiles-style MapLibre style for cebu_city.mbtiles.
///
/// Layer names match the `vector_layers` listed in the MBTiles metadata
/// (water, landcover, landuse, park, transportation, building, place, ...).
/// No icons are used, so no sprite files are needed. Text uses the glyph
/// folders NotoSansRegular / NotoSansMedium / NotoSansItalic.
///
/// NOTE: MapLibre zoom = flutter_map zoom - 1 (512px vs 256px tiles).
library;

const String _src = 'openmaptiles';

const String _fontRegular = 'NotoSansRegular';
const String _fontMedium = 'NotoSansMedium';
const String _fontItalic = 'NotoSansItalic';

// ---- Small expression helpers ----------------------------------------------

List<Object> _exp(List<num> stops, {double base = 1.4}) =>
    ['interpolate', ['exponential', base], ['zoom'], ...stops];

List<Object> _lin(List<num> stops) =>
    ['interpolate', ['linear'], ['zoom'], ...stops];

List<Object> _classIn(List<String> classes) =>
    ['match', ['get', 'class'], classes, true, false];

const List<Object> _isLine = ['==', ['geometry-type'], 'LineString'];
const List<Object> _notTunnel = ['!=', ['get', 'brunnel'], 'tunnel'];

/// Prefer the Latin transliteration when a name is in another script.
const List<Object> _nameExpr = [
  'coalesce',
  ['get', 'name:latin'],
  ['get', 'name'],
];

Map<String, dynamic> _road({
  required String id,
  required List<String> classes,
  required String color,
  required List<num> widthStops,
  num minzoom = 0,
  List<num>? dash,
}) {
  return {
    'id': id,
    'type': 'line',
    'source': _src,
    'source-layer': 'transportation',
    'minzoom': minzoom,
    'filter': ['all', _isLine, _classIn(classes), _notTunnel],
    'layout': {
      'line-cap': dash == null ? 'round' : 'butt',
      'line-join': 'round',
    },
    'paint': {
      'line-color': color,
      'line-width': _exp(widthStops),
      if (dash != null) 'line-dasharray': dash,
    },
  };
}

Map<String, dynamic> _placeLabel({
  required String id,
  required List<String> classes,
  required String font,
  required List<num> sizeStops,
  num minzoom = 0,
  String color = '#333333',
  bool upper = false,
}) {
  return {
    'id': id,
    'type': 'symbol',
    'source': _src,
    'source-layer': 'place',
    'minzoom': minzoom,
    'filter': _classIn(classes),
    'layout': {
      'text-field': _nameExpr,
      'text-font': [font],
      'text-size': _lin(sizeStops),
      'text-max-width': 8,
      'text-padding': 2,
      'text-transform': upper ? 'uppercase' : 'none',
      'text-letter-spacing': upper ? 0.1 : 0,
      'symbol-sort-key': [
        'coalesce',
        ['get', 'rank'],
        99,
      ],
    },
    'paint': {
      'text-color': color,
      'text-halo-color': '#ffffff',
      'text-halo-width': 1.5,
      'text-halo-blur': 0.5,
    },
  };
}

/// Builds the style as a JSON-encodable map.
///
/// [tilesUrl] is the full tile source URL, e.g.
/// `pmtiles://file:///data/.../cebu_city.pmtiles` or
/// `mbtiles:///data/.../cebu_city.mbtiles`. [glyphsDir] is an absolute path.
Map<String, dynamic> buildCebuLightStyle({
  required String tilesUrl,
  required String glyphsDir,
}) {
  final layers = <Map<String, dynamic>>[
    // ---- Ground -------------------------------------------------------------
    {
      'id': 'background',
      'type': 'background',
      'paint': {'background-color': '#f8f4f0'},
    },
    {
      'id': 'landcover',
      'type': 'fill',
      'source': _src,
      'source-layer': 'landcover',
      'paint': {
        'fill-color': [
          'match',
          ['get', 'class'],
          'wood', '#cfe4bd',
          'grass', '#e0ecce',
          'farmland', '#e8eed7',
          'wetland', '#d6e8dc',
          'sand', '#f4ecd4',
          'ice', '#ffffff',
          '#e8eed7',
        ],
      },
    },
    {
      'id': 'landuse',
      'type': 'fill',
      'source': _src,
      'source-layer': 'landuse',
      'paint': {
        'fill-color': [
          'match',
          ['get', 'class'],
          ['residential', 'suburb', 'neighbourhood'], '#ebe7e1',
          ['commercial', 'retail'], '#f0e4dc',
          'industrial', '#e6e0e8',
          'cemetery', '#d3e3cc',
          'hospital', '#f5e0dc',
          ['school', 'university', 'college'], '#f0ebd6',
          'rgba(0,0,0,0)',
        ],
      },
    },
    {
      'id': 'park',
      'type': 'fill',
      'source': _src,
      'source-layer': 'park',
      'paint': {'fill-color': '#d2e8bd', 'fill-opacity': 0.7},
    },

    // ---- Water ----------------------------------------------------------------
    {
      'id': 'water',
      'type': 'fill',
      'source': _src,
      'source-layer': 'water',
      'paint': {'fill-color': '#a0c8f0'},
    },
    {
      'id': 'waterway',
      'type': 'line',
      'source': _src,
      'source-layer': 'waterway',
      'minzoom': 11,
      'filter': _isLine,
      'paint': {
        'line-color': '#a0c8f0',
        'line-width': _exp([11, 0.5, 16, 3]),
      },
    },

    // ---- Airport ----------------------------------------------------------------
    {
      'id': 'aeroway_area',
      'type': 'fill',
      'source': _src,
      'source-layer': 'aeroway',
      'minzoom': 10,
      'paint': {'fill-color': '#e6e4e0'},
    },
    {
      'id': 'aeroway_line',
      'type': 'line',
      'source': _src,
      'source-layer': 'aeroway',
      'minzoom': 10,
      'filter': _isLine,
      'paint': {
        'line-color': '#dddbd7',
        'line-width': _exp([10, 1, 14, 6, 18, 40]),
      },
    },

    // ---- Buildings ----------------------------------------------------------
    {
      'id': 'building',
      'type': 'fill',
      'source': _src,
      'source-layer': 'building',
      'minzoom': 13,
      'paint': {
        'fill-color': '#e0dcd6',
        'fill-outline-color': '#cdc7bd',
      },
    },

    // ---- Roads (drawn small to large so big roads overlap small ones) -------
    _road(
      id: 'road_path',
      classes: ['path', 'track', 'pedestrian'],
      color: '#b0a99f',
      widthStops: [14, 0.6, 18, 2],
      minzoom: 14,
      dash: [2, 2],
    ),
    _road(
      id: 'road_minor_casing',
      classes: ['minor', 'service'],
      color: '#cfcdca',
      widthStops: [12, 1, 14, 3, 16, 8.5, 18, 21],
      minzoom: 12,
    ),
    _road(
      id: 'road_minor',
      classes: ['minor', 'service'],
      color: '#ffffff',
      widthStops: [12, 0.5, 14, 1.8, 16, 6, 18, 18],
      minzoom: 12,
    ),
    _road(
      id: 'road_tertiary_casing',
      classes: ['tertiary'],
      color: '#cfcdca',
      widthStops: [11, 1.2, 12, 2.5, 14, 4.5, 16, 12, 18, 29],
      minzoom: 11,
    ),
    _road(
      id: 'road_tertiary',
      classes: ['tertiary'],
      color: '#ffffff',
      widthStops: [11, 0.5, 12, 1.5, 14, 3, 16, 10, 18, 26],
      minzoom: 11,
    ),
    _road(
      id: 'road_main_casing',
      classes: ['trunk', 'primary', 'secondary'],
      color: '#e9ac77',
      widthStops: [8, 1.4, 10, 2.5, 12, 3.8, 14, 5.5, 16, 14, 18, 33],
      minzoom: 8,
    ),
    _road(
      id: 'road_main',
      classes: ['trunk', 'primary', 'secondary'],
      color: '#ffeeaa',
      widthStops: [8, 0.6, 10, 1.5, 12, 2.5, 14, 4, 16, 12, 18, 30],
      minzoom: 8,
    ),
    _road(
      id: 'road_motorway_casing',
      classes: ['motorway'],
      color: '#e9ac77',
      widthStops: [6, 1.6, 10, 3, 12, 5, 14, 7, 16, 16, 18, 37],
      minzoom: 6,
    ),
    _road(
      id: 'road_motorway',
      classes: ['motorway'],
      color: '#ffcc88',
      widthStops: [6, 0.8, 10, 2, 12, 3.5, 14, 5, 16, 14, 18, 34],
      minzoom: 6,
    ),

    // ---- Labels ---------------------------------------------------------------
    {
      'id': 'label_road',
      'type': 'symbol',
      'source': _src,
      'source-layer': 'transportation_name',
      'minzoom': 12,
      'filter': ['has', 'name'],
      'layout': {
        'symbol-placement': 'line',
        'symbol-spacing': 350,
        'text-field': _nameExpr,
        'text-font': [_fontRegular],
        'text-size': _lin([12, 10, 18, 14]),
        'text-rotation-alignment': 'map',
      },
      'paint': {
        'text-color': '#555555',
        'text-halo-color': '#ffffff',
        'text-halo-width': 1.5,
      },
    },
    {
      'id': 'label_water',
      'type': 'symbol',
      'source': _src,
      'source-layer': 'water_name',
      'minzoom': 7,
      'layout': {
        'text-field': _nameExpr,
        'text-font': [_fontItalic],
        'text-size': _lin([7, 11, 14, 14]),
        'text-max-width': 8,
        'text-letter-spacing': 0.1,
      },
      'paint': {
        'text-color': '#5d60be',
        'text-halo-color': '#ffffff',
        'text-halo-width': 1.2,
      },
    },
    _placeLabel(
      id: 'label_island',
      classes: ['island'],
      font: _fontRegular,
      sizeStops: [8, 11, 14, 14],
      minzoom: 8,
      color: '#555555',
    ),
    _placeLabel(
      id: 'label_city',
      classes: ['city'],
      font: _fontMedium,
      sizeStops: [6, 12, 12, 20],
    ),
    _placeLabel(
      id: 'label_town',
      classes: ['town'],
      font: _fontMedium,
      sizeStops: [8, 11, 14, 16],
      minzoom: 8,
    ),
    _placeLabel(
      id: 'label_village',
      classes: ['village'],
      font: _fontRegular,
      sizeStops: [10, 10, 14, 13],
      minzoom: 10,
      color: '#444444',
    ),
    _placeLabel(
      id: 'label_suburb',
      classes: ['suburb', 'quarter', 'neighbourhood'],
      font: _fontRegular,
      sizeStops: [12, 10, 16, 12],
      minzoom: 12,
      color: '#666666',
      upper: true,
    ),
  ];

  return {
    'version': 8,
    'name': 'Cebu Light',
    'sources': {
      _src: {
        'type': 'vector',
        'url': tilesUrl,
        'attribution': '© MapTiler © OpenStreetMap contributors',
      },
    },
    'glyphs': 'file://$glyphsDir/{fontstack}/{range}.pbf',
    'layers': layers,
  };
}
