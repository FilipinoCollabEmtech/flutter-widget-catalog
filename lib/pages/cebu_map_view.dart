import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart' as ll;
import 'package:maplibre_gl/maplibre_gl.dart' as ml;

import 'cebu_boundary_layer.dart' show kCebuHome, kCebuOutline;
import 'location_service.dart';

// Matches kOutsideColor (0xFFE6E8EB) from cebu_boundary_layer.dart.
const String _outsideHex = '#E6E8EB';

const String _maskSrc = 'cebu-mask';
const String _accSrc = 'user-accuracy';
const String _pointSrc = 'user-point';
const String _coneImage = 'user-cone';

const Map<String, dynamic> _emptyCollection = {
  'type': 'FeatureCollection',
  'features': <Object>[],
};

/// The offline map, drawn natively by MapLibre on the GPU.
///
/// Everything that used to be a flutter_map layer lives here:
///  - gray fade outside Cebu            (fill + blurred line layers)
///  - location dot, accuracy, heading   (driven by [location])
///  - arrow pointing back to Cebu       (Flutter overlay)
class CebuMapView extends StatefulWidget {
  const CebuMapView({
    super.key,
    required this.stylePath,
    required this.location,
    required this.cameraNotifier,
    required this.onMapReady,
    required this.onHomePressed,
    this.arrowPadding = const EdgeInsets.all(16),
  });

  /// Absolute path of the generated style.json.
  final String stylePath;

  final LocationService location;

  /// Updated whenever the camera moves (for the zoom readout and the arrow).
  final ValueNotifier<ml.CameraPosition?> cameraNotifier;

  final ValueChanged<ml.MapLibreMapController> onMapReady;

  /// Tapped when the user presses the "back to Cebu" arrow.
  final VoidCallback onHomePressed;

  final EdgeInsets arrowPadding;

  @override
  State<CebuMapView> createState() => _CebuMapViewState();
}

class _CebuMapViewState extends State<CebuMapView> {
  ml.MapLibreMapController? _controller;
  bool _styleReady = false;

  // Coalesces rapid location updates into as few platform calls as possible.
  bool _syncing = false;
  bool _dirty = false;

  @override
  void initState() {
    super.initState();
    widget.location.addListener(_requestSync);
  }

  @override
  void dispose() {
    widget.location.removeListener(_requestSync);
    _controller?.removeListener(_onCamera);
    super.dispose();
  }

  void _onMapCreated(ml.MapLibreMapController controller) {
    _controller = controller;
    controller.addListener(_onCamera);
    widget.onMapReady(controller);
  }

  void _onCamera() {
    final position = _controller?.cameraPosition;
    if (position != null) widget.cameraNotifier.value = position;
  }

  Future<void> _onStyleLoaded() async {
    final c = _controller;
    if (c == null) return;

    try {
      // Gray everywhere except Cebu, with a soft feathered edge.
      await c.addGeoJsonSource(_maskSrc, _maskGeoJson());
      await c.addFillLayer(
        _maskSrc,
        'cebu-mask-fill',
        ml.FillLayerProperties(
          fillColor: _outsideHex,
          fillAntialias: true,
        ),
      );
      await c.addLineLayer(
        _maskSrc,
        'cebu-mask-feather',
        ml.LineLayerProperties(
          lineColor: _outsideHex,
          lineWidth: 28,
          lineBlur: 20,
          lineJoin: 'round',
        ),
      );

      // User location: accuracy circle, heading cone, dot (bottom to top).
      await c.addGeoJsonSource(_accSrc, _emptyCollection);
      await c.addFillLayer(
        _accSrc,
        'user-accuracy-fill',
        ml.FillLayerProperties(
          fillColor: '#2196F3',
          fillOpacity: 0.15,
          fillOutlineColor: 'rgba(33,150,243,0.45)',
        ),
      );

      await c.addImage(_coneImage, await _renderConeImage());
      await c.addGeoJsonSource(_pointSrc, _emptyCollection);
      await c.addSymbolLayer(
        _pointSrc,
        'user-cone-layer',
        ml.SymbolLayerProperties(
          iconImage: _coneImage,
          iconSize: 1 / 3, // the image is drawn at 3x for sharpness
          iconRotate: ['get', 'heading'],
          iconRotationAlignment: 'map',
          iconAllowOverlap: true,
          iconIgnorePlacement: true,
        ),
        filter: ['has', 'heading'],
      );
      await c.addCircleLayer(
        _pointSrc,
        'user-dot',
        ml.CircleLayerProperties(
          circleRadius: 9,
          circleColor: '#2196F3',
          circleStrokeColor: '#FFFFFF',
          circleStrokeWidth: 3,
        ),
      );

      _styleReady = true;
      _onCamera();
      _requestSync();
    } catch (error, stackTrace) {
      debugPrint('Failed to set up map layers: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  // ---- Location -----------------------------------------------------------

  void _requestSync() {
    _dirty = true;
    if (_syncing) return;
    _runSync();
  }

  Future<void> _runSync() async {
    _syncing = true;
    try {
      while (_dirty) {
        _dirty = false;
        await _applyLocation();
      }
    } catch (error) {
      debugPrint('Failed to update location layers: $error');
    } finally {
      _syncing = false;
    }
  }

  Future<void> _applyLocation() async {
    final c = _controller;
    if (c == null || !_styleReady) return;

    final loc = widget.location;
    final pos = loc.position;

    if (pos == null) {
      await c.setGeoJsonSource(_accSrc, _emptyCollection);
      await c.setGeoJsonSource(_pointSrc, _emptyCollection);
      return;
    }

    final accuracy = loc.accuracyMeters ?? 0;
    await c.setGeoJsonSource(
      _accSrc,
      accuracy > 0 ? _circleGeoJson(pos, accuracy) : _emptyCollection,
    );

    final heading = loc.heading;
    await c.setGeoJsonSource(_pointSrc, {
      'type': 'FeatureCollection',
      'features': [
        {
          'type': 'Feature',
          // No heading property -> the cone layer's filter hides the cone.
          'properties': {if (heading != null) 'heading': heading},
          'geometry': {
            'type': 'Point',
            'coordinates': [pos.longitude, pos.latitude],
          },
        },
      ],
    });
  }

  // ---- GeoJSON helpers ------------------------------------------------------

  /// World rectangle with a Cebu-shaped hole, so the fill covers everything
  /// except Cebu.
  static Map<String, dynamic> _maskGeoJson() {
    final hole = _chaikin(
      [
        for (final p in kCebuOutline) [p.longitude, p.latitude],
      ],
      2,
    );
    return {
      'type': 'FeatureCollection',
      'features': [
        {
          'type': 'Feature',
          'properties': <String, Object>{},
          'geometry': {
            'type': 'Polygon',
            'coordinates': [
              [
                [-180.0, -85.0],
                [180.0, -85.0],
                [180.0, 85.0],
                [-180.0, 85.0],
                [-180.0, -85.0],
              ],
              hole,
            ],
          },
        },
      ],
    };
  }

  /// Rounds the corners of the hand-traced outline (closed loop).
  static List<List<double>> _chaikin(List<List<double>> points, int rounds) {
    var current = points;
    for (var r = 0; r < rounds; r++) {
      final next = <List<double>>[];
      for (var i = 0; i < current.length; i++) {
        final a = current[i];
        final b = current[(i + 1) % current.length];
        next.add([0.75 * a[0] + 0.25 * b[0], 0.75 * a[1] + 0.25 * b[1]]);
        next.add([0.25 * a[0] + 0.75 * b[0], 0.25 * a[1] + 0.75 * b[1]]);
      }
      current = next;
    }
    return [...current, current.first]; // GeoJSON rings are closed
  }

  /// Circle polygon with a radius in meters (for the GPS accuracy).
  static Map<String, dynamic> _circleGeoJson(ll.LatLng c, double radiusM) {
    const steps = 48;
    final dLat = radiusM / 111320.0;
    final dLng = radiusM / (111320.0 * math.cos(c.latitude * math.pi / 180));
    final ring = <List<double>>[
      for (var i = 0; i <= steps; i++)
        [
          c.longitude + dLng * math.cos(2 * math.pi * i / steps),
          c.latitude + dLat * math.sin(2 * math.pi * i / steps),
        ],
    ];
    return {
      'type': 'FeatureCollection',
      'features': [
        {
          'type': 'Feature',
          'properties': <String, Object>{},
          'geometry': {
            'type': 'Polygon',
            'coordinates': [ring],
          },
        },
      ],
    };
  }

  /// The translucent "flashlight" beam, pointing north. MapLibre rotates it
  /// by the heading. Drawn at 3x resolution (see iconSize above).
  static Future<Uint8List> _renderConeImage() async {
    const px = 288.0;
    const center = Offset(px / 2, px / 2);
    final rect = Rect.fromCircle(center: center, radius: px / 2);

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final paint = Paint()
      ..shader = ui.Gradient.radial(center, px / 2, const [
        Color(0x8C2196F3),
        Color(0x002196F3),
      ]);
    final path = Path()
      ..moveTo(center.dx, center.dy)
      ..arcTo(rect, -math.pi / 2 - math.pi / 6, math.pi / 3, false)
      ..close();
    canvas.drawPath(path, paint);

    final image =
        await recorder.endRecording().toImage(px.toInt(), px.toInt());
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    return data!.buffer.asUint8List();
  }

  // ---- Build ----------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        ml.MapLibreMap(
          styleString: widget.stylePath,
          // MapLibre zoom is one lower than flutter_map's: 10 here == 11 there.
          initialCameraPosition: ml.CameraPosition(
            target: ml.LatLng(kCebuHome.latitude, kCebuHome.longitude),
            zoom: 10,
          ),
          minMaxZoomPreference: ml.MinMaxZoomPreference(7, 17),
          trackCameraPosition: true,
          // North-up only for now (the arrow math assumes it).
          rotateGesturesEnabled: false,
          tiltGesturesEnabled: false,
          compassEnabled: false,
          onMapCreated: _onMapCreated,
          onStyleLoadedCallback: _onStyleLoaded,
        ),
        ValueListenableBuilder<ml.CameraPosition?>(
          valueListenable: widget.cameraNotifier,
          builder: (context, camera, _) {
            if (camera == null) return const SizedBox.shrink();
            return CebuDirectionArrowGl(
              camera: camera,
              padding: widget.arrowPadding,
              onTap: widget.onHomePressed,
            );
          },
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Direction arrow
// ---------------------------------------------------------------------------

/// Web-Mercator pixel position at a MapLibre zoom (512px world tile).
Offset _project(double lat, double lng, double zoom) {
  final world = 512.0 * math.pow(2, zoom);
  final x = (lng + 180) / 360 * world;
  final sinLat = math.sin(lat * math.pi / 180).clamp(-0.9999, 0.9999).toDouble();
  final y = (0.5 - math.log((1 + sinLat) / (1 - sinLat)) / (4 * math.pi)) * world;
  return Offset(x, y);
}

/// Bounding box of the Cebu outline, as (south, west, north, east).
final ({double s, double w, double n, double e}) _outlineBounds = () {
  var s = double.infinity, w = double.infinity;
  var n = -double.infinity, e = -double.infinity;
  for (final p in kCebuOutline) {
    s = math.min(s, p.latitude);
    n = math.max(n, p.latitude);
    w = math.min(w, p.longitude);
    e = math.max(e, p.longitude);
  }
  return (s: s, w: w, n: n, e: e);
}();

/// Double-chevron button on the screen edge pointing toward Cebu.
/// Only shows when no part of Cebu is visible. Tap to fly back.
class CebuDirectionArrowGl extends StatelessWidget {
  const CebuDirectionArrowGl({
    super.key,
    required this.camera,
    required this.onTap,
    this.padding = const EdgeInsets.all(16),
  });

  final ml.CameraPosition camera;
  final VoidCallback onTap;
  final EdgeInsets padding;

  static const double _w = 88;
  static const double _h = 70;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return SizedBox.expand(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final size = constraints.biggest;
          final viewport = Offset.zero & size;
          final c = viewport.center;

          // Outline bounding box on screen (north-up map).
          final origin = _project(
            camera.target.latitude,
            camera.target.longitude,
            camera.zoom,
          );
          final nw = _project(_outlineBounds.n, _outlineBounds.w, camera.zoom);
          final se = _project(_outlineBounds.s, _outlineBounds.e, camera.zoom);
          final rect = Rect.fromPoints(nw - origin + c, se - origin + c);

          if (rect.overlaps(viewport)) return const SizedBox.shrink();

          final d = rect.center - c;

          final inner = Rect.fromLTRB(
            padding.left + _w / 2,
            padding.top + _h / 2,
            size.width - padding.right - _w / 2,
            size.height - padding.bottom - _h / 2,
          );
          if (inner.width <= 0 || inner.height <= 0) {
            return const SizedBox.shrink();
          }

          var t = double.infinity;
          if (d.dx > 0) t = math.min(t, (inner.right - c.dx) / d.dx);
          if (d.dx < 0) t = math.min(t, (inner.left - c.dx) / d.dx);
          if (d.dy > 0) t = math.min(t, (inner.bottom - c.dy) / d.dy);
          if (d.dy < 0) t = math.min(t, (inner.top - c.dy) / d.dy);
          final pos = c + d * t;

          final km = const ll.Distance()
              .as(
                ll.LengthUnit.Kilometer,
                ll.LatLng(camera.target.latitude, camera.target.longitude),
                kCebuHome,
              )
              .round();

          return Stack(
            children: [
              Positioned(
                left: pos.dx - _w / 2,
                top: pos.dy - _h / 2,
                width: _w,
                height: _h,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: onTap,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: scheme.surfaceContainerHigh,
                          boxShadow: const [
                            BoxShadow(
                              blurRadius: 4,
                              offset: Offset(0, 2),
                              color: Colors.black26,
                            ),
                          ],
                        ),
                        child: Transform.rotate(
                          angle: math.atan2(d.dy, d.dx) + math.pi / 2,
                          child: Icon(
                            Icons.keyboard_double_arrow_up,
                            color: scheme.primary,
                            size: 30,
                          ),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Cebu · $km km',
                        maxLines: 1,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: scheme.onSurface,
                          shadows: const [
                            Shadow(blurRadius: 3, color: Colors.white),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
