import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';

import 'location_service.dart';

/// Drop this into FlutterMap's `children`, after the TileLayer.
/// It redraws itself whenever [service] changes and draws nothing
/// while there is no position.
class UserLocationLayer extends StatelessWidget {
  const UserLocationLayer({super.key, required this.service});

  final LocationService service;

  static const double _markerSize = 88;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: service,
      builder: (context, _) {
        final position = service.position;
        if (position == null) return const SizedBox.shrink();

        final accuracy = service.accuracyMeters;

        return SizedBox.expand(
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (accuracy != null && accuracy > 0)
                CircleLayer(
                  circles: [
                    CircleMarker(
                      point: position,
                      radius: accuracy, // meters
                      useRadiusInMeter: true,
                      color: Colors.blue.withValues(alpha: 0.15),
                      borderColor: Colors.blue.withValues(alpha: 0.4),
                      borderStrokeWidth: 1,
                    ),
                  ],
                ),
              MarkerLayer(
                markers: [
                  Marker(
                    point: position,
                    width: _markerSize,
                    height: _markerSize,
                    child: _LocationMarker(heading: service.heading),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Blue dot with a translucent "flashlight" cone showing which way the
/// user is facing. The cone is hidden until a heading is known.
class _LocationMarker extends StatelessWidget {
  const _LocationMarker({required this.heading});

  final double? heading;

  @override
  Widget build(BuildContext context) {
    final currentHeading = heading;

    return Stack(
      alignment: Alignment.center,
      children: [
        if (currentHeading != null)
          TweenAnimationBuilder<double>(
            tween: Tween<double>(end: currentHeading),
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            builder: (context, degrees, child) {
              return Transform.rotate(
                angle: degrees * math.pi / 180,
                child: child,
              );
            },
            child: const CustomPaint(
              size: Size.square(UserLocationLayer._markerSize),
              painter: _ConePainter(),
            ),
          ),
        const _LocationDot(),
      ],
    );
  }
}

class _ConePainter extends CustomPainter {
  const _ConePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.width / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    const sweep = math.pi / 3; // 60 degree wide beam, pointing up (north)

    final paint = Paint()
      ..shader = RadialGradient(
        colors: [
          Colors.blue.withValues(alpha: 0.55),
          Colors.blue.withValues(alpha: 0.0),
        ],
      ).createShader(rect);

    final path = Path()
      ..moveTo(center.dx, center.dy)
      ..arcTo(rect, -math.pi / 2 - sweep / 2, sweep, false)
      ..close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _LocationDot extends StatelessWidget {
  const _LocationDot();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.blue,
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: const [
          BoxShadow(
            blurRadius: 4,
            color: Colors.black38,
            offset: Offset(0, 1),
          ),
        ],
      ),
    );
  }
}
