import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';

import 'location_service.dart';

/// Drop this into FlutterMap's `children`, after the TileLayer.
/// It redraws itself whenever [service] changes and draws nothing
/// while there is no position.
class UserLocationLayer extends StatelessWidget {
  const UserLocationLayer({super.key, required this.service});

  final LocationService service;

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
                    width: 24,
                    height: 24,
                    child: const _LocationDot(),
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

class _LocationDot extends StatelessWidget {
  const _LocationDot();

  @override
  Widget build(BuildContext context) {
    return Container(
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
