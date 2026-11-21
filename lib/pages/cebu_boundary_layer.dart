import 'dart:math' as math;

import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' show Distance, LatLng, LengthUnit;

/// Rough outline of "Cebu" (island + nearby water), traced by hand.
/// Everything outside it is covered by a soft light-gray fade.
/// Edit / add points to reshape it; order matters (it is a closed loop).
/// It is kept inside the area that cebu_city.mbtiles actually covers.
const List<LatLng> kCebuOutline = [
  LatLng(11.2926, 123.6156),
  LatLng(11.3569, 123.6818),
  LatLng(11.3600, 123.8308),
  LatLng(11.3600, 124.0405),
  LatLng(11.3247, 124.1619),
  LatLng(11.2014, 124.1950),
  LatLng(10.9598, 124.1950),
  LatLng(10.6913, 124.1950),
  LatLng(10.4224, 124.1950),
  LatLng(10.2341, 124.1950),
  LatLng(10.1103, 124.1232),
  LatLng(10.0457, 123.9853),
  LatLng(10.0080, 123.8639),
  LatLng(9.9110, 123.7756),
  LatLng(9.7224, 123.7370),
  LatLng(9.5337, 123.6984),
  LatLng(9.4000, 123.6266),
  LatLng(9.4000, 123.5163),
  LatLng(9.4000, 123.3508),
  LatLng(9.4000, 123.2800),
  LatLng(9.4635, 123.2800),
  LatLng(9.6415, 123.2800),
  LatLng(9.8302, 123.2800),
  LatLng(10.0349, 123.2800),
  LatLng(10.2341, 123.3673),
  LatLng(10.4224, 123.4611),
  LatLng(10.6106, 123.5328),
  LatLng(10.7987, 123.5549),
  LatLng(10.9867, 123.5328),
  LatLng(11.1745, 123.5384),
  LatLng(11.2550, 123.5770),
];

/// Where the arrow takes you when tapped.
const LatLng kCebuHome = LatLng(10.3157, 123.8854);

/// Color of the area outside Cebu.
const Color kOutsideColor = Color(0xFFE6E8EB);

/// How soft the edge is, in screen pixels (bigger = blurrier).
const double kEdgeBlur = 16;

/// Camera-relative screen position of a coordinate. Works with flutter_map
/// versions that return either `Offset` or `Point<double>`.
Offset _toScreen(MapCamera camera, LatLng p) {
  final dynamic o = camera.getOffsetFromOrigin(p);
  if (o is Offset) return o;
  return Offset((o.x as num).toDouble(), (o.y as num).toDouble());
}

/// Outline points as pixel offsets from the map CENTER (un-rotated, at the
/// current zoom). Using the center as reference means we never depend on
/// flutter_map's internal pixel origin, which changes size when rotated.
List<Offset> _outlineFromMapCenter(MapCamera camera) {
  final c = _toScreen(camera, camera.center);
  return [for (final p in kCebuOutline) _toScreen(camera, p) - c];
}

/// Puts center-relative offsets on screen: rotate by the map rotation, then
/// add the middle of the screen (the map center is always screen center).
/// This is the same math flutter_map uses for its own layers.
List<Offset> _placeOnScreen(List<Offset> fromCenter, Size size, double rad) {
  final c = size.center(Offset.zero);
  final cosA = math.cos(rad);
  final sinA = math.sin(rad);
  return [
    for (final r in fromCenter)
      Offset(
        c.dx + r.dx * cosA - r.dy * sinA,
        c.dy + r.dx * sinA + r.dy * cosA,
      ),
  ];
}

/// Bounding box of the outline on screen (map rotation included).
Rect _outlineScreenRect(MapCamera camera, Size size) {
  final pts = _placeOnScreen(
    _outlineFromMapCenter(camera),
    size,
    camera.rotationRad,
  );
  var minX = double.infinity, minY = double.infinity;
  var maxX = -double.infinity, maxY = -double.infinity;
  for (final p in pts) {
    minX = math.min(minX, p.dx);
    minY = math.min(minY, p.dy);
    maxX = math.max(maxX, p.dx);
    maxY = math.max(maxY, p.dy);
  }
  return Rect.fromLTRB(minX, minY, maxX, maxY);
}

/// Covers everything outside Cebu with a light gray that fades out softly
/// at the edge. Put it after the tile layer in FlutterMap's `children`.
class CebuOutsideLayer extends StatelessWidget {
  const CebuOutsideLayer({super.key});

  @override
  Widget build(BuildContext context) {
    final camera = MapCamera.of(context);
    final points = _outlineFromMapCenter(camera);
    return IgnorePointer(
      child: SizedBox.expand(
        child: CustomPaint(
          painter: _OutsidePainter(points, camera.rotationRad),
        ),
      ),
    );
  }
}

class _OutsidePainter extends CustomPainter {
  _OutsidePainter(this.rawPoints, this.rotationRad);

  /// Outline as pixel offsets from the map center (un-rotated).
  final List<Offset> rawPoints;

  /// Current map rotation in radians.
  final double rotationRad;

  /// Smooth closed curve through the outline (rounded, no sharp corners).
  Path _smoothPath(List<Offset> points) {
    final n = points.length;
    Offset mid(int a, int b) => (points[a % n] + points[b % n]) / 2;
    final start = mid(n - 1, 0);
    final path = Path()..moveTo(start.dx, start.dy);
    for (var i = 0; i < n; i++) {
      final c = points[i];
      final m = mid(i, i + 1);
      path.quadraticBezierTo(c.dx, c.dy, m.dx, m.dy);
    }
    return path..close();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final viewport = Offset.zero & size;
    final fade = kEdgeBlur * 3;

    // Rotate the OUTLINE (not the canvas) so the gray fill and the blur
    // always cover the whole screen, whatever the map rotation is.
    final points = _placeOnScreen(rawPoints, size, rotationRad);

    var minX = double.infinity, minY = double.infinity;
    var maxX = -double.infinity, maxY = -double.infinity;
    for (final p in points) {
      minX = math.min(minX, p.dx);
      minY = math.min(minY, p.dy);
      maxX = math.max(maxX, p.dx);
      maxY = math.max(maxY, p.dy);
    }
    final bounds = Rect.fromLTRB(minX, minY, maxX, maxY);

    final gray = Paint()..color = kOutsideColor;

    // Far away from Cebu: just gray.
    if (!bounds.inflate(fade).overlaps(viewport)) {
      canvas.drawRect(viewport, gray);
      return;
    }

    final path = _smoothPath(points);

    // Deep inside Cebu (edge not in view): nothing to draw. Sample a grid.
    final probe = viewport.inflate(fade);
    var allInside = true;
    for (var i = 0; i <= 6 && allInside; i++) {
      for (var j = 0; j <= 6; j++) {
        final p = Offset(
          probe.left + probe.width * i / 6,
          probe.top + probe.height * j / 6,
        );
        if (!path.contains(p)) {
          allInside = false;
          break;
        }
      }
    }
    if (allInside) return;

    // Gray everywhere, then erase Cebu with a blurred brush so the edge fades.
    final layerRect = viewport.inflate(1);
    canvas.saveLayer(layerRect, Paint());
    canvas.drawRect(layerRect, gray);
    canvas.drawPath(
      path,
      Paint()
        ..blendMode = BlendMode.clear
        ..isAntiAlias = true
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, kEdgeBlur),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_OutsidePainter old) =>
      old.rotationRad != rotationRad || !listEquals(old.rawPoints, rawPoints);
}

/// Double-chevron button on the screen edge pointing toward Cebu.
/// Only shows when no part of Cebu is visible. Tap to fly back.
class CebuDirectionArrow extends StatelessWidget {
  const CebuDirectionArrow({
    super.key,
    required this.onTap,
    this.padding = const EdgeInsets.all(16),
  });

  final VoidCallback onTap;

  /// Keep the arrow clear of floating UI (e.g. a big top value for the
  /// search bar).
  final EdgeInsets padding;

  static const double _w = 88;
  static const double _h = 70;

  @override
  Widget build(BuildContext context) {
    final camera = MapCamera.of(context);
    final scheme = Theme.of(context).colorScheme;

    return SizedBox.expand(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final size = constraints.biggest;
          final viewport = Offset.zero & size;
          final rect = _outlineScreenRect(camera, size);

          if (rect.overlaps(viewport)) return const SizedBox.shrink();

          final c = viewport.center;
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

          final km = const Distance()
              .as(LengthUnit.Kilometer, camera.center, kCebuHome)
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
