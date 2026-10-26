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

/// Bounding box of [kCebuOutline] in screen pixels.
Rect _outlineScreenRect(MapCamera camera) {
  var minLat = 90.0, maxLat = -90.0, minLng = 180.0, maxLng = -180.0;
  for (final p in kCebuOutline) {
    minLat = math.min(minLat, p.latitude);
    maxLat = math.max(maxLat, p.latitude);
    minLng = math.min(minLng, p.longitude);
    maxLng = math.max(maxLng, p.longitude);
  }
  return Rect.fromPoints(
    _toScreen(camera, LatLng(maxLat, minLng)),
    _toScreen(camera, LatLng(minLat, maxLng)),
  );
}

/// Covers everything outside Cebu with a light gray that fades out softly
/// at the edge. Put it after the tile layer in FlutterMap's `children`.
class CebuOutsideLayer extends StatelessWidget {
  const CebuOutsideLayer({super.key});

  @override
  Widget build(BuildContext context) {
    final camera = MapCamera.of(context);
    final points = [for (final p in kCebuOutline) _toScreen(camera, p)];
    return IgnorePointer(
      child: SizedBox.expand(
        child: CustomPaint(painter: _OutsidePainter(points, camera.rotation)),
      ),
    );
  }
}

class _OutsidePainter extends CustomPainter {
  _OutsidePainter(this.points, this.rotation);

  final List<Offset> points;
  final double rotation;

  /// Smooth closed curve through the outline (rounded, no sharp corners).
  Path _smoothPath() {
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
    // Align canvas with map rotation so the blur boundary stays fixed to the
    // rotated map view instead of drifting when tilted/rotated.
    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);
    canvas.rotate(rotation);
    canvas.translate(-size.width / 2, -size.height / 2);

    final viewport = Offset.zero & size;
    final fade = kEdgeBlur * 3;

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

    final path = _smoothPath();

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
    canvas.restore();  // restore saveLayer
    canvas.restore();  // restore rotation transform
  }

  @override
  bool shouldRepaint(_OutsidePainter old) =>
      !listEquals(old.points, points) || old.rotation != rotation;
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
          final rect = _outlineScreenRect(camera);

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
