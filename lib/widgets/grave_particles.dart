import 'dart:math';

import 'package:flutter/material.dart';

/// Gray square debris bursting upward while the Demo page rises,
/// like the UI is breaking apart.
class GraveParticles extends StatefulWidget {
  const GraveParticles({super.key});

  @override
  State<GraveParticles> createState() => _GraveParticlesState();
}

class _GraveParticlesState extends State<GraveParticles>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final List<_Mote> _motes;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..forward();
    final rand = Random(7);
    _motes = List.generate(46, (_) {
      return _Mote(
        x: rand.nextDouble(),
        y: 0.55 + rand.nextDouble() * 0.45,
        size: 3 + rand.nextDouble() * 7,
        rise: 0.4 + rand.nextDouble() * 0.6,
        drift: (rand.nextDouble() - 0.5) * 0.2,
        shade: 400 + rand.nextInt(4) * 100,
      );
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (_, __) => CustomPaint(
        painter: _GravePainter(
          progress: _controller.value,
          motes: _motes,
        ),
      ),
    );
  }
}

class _Mote {
  final double x;
  final double y;
  final double size;
  final double rise;
  final double drift;
  final int shade;

  const _Mote({
    required this.x,
    required this.y,
    required this.size,
    required this.rise,
    required this.drift,
    required this.shade,
  });
}

class _GravePainter extends CustomPainter {
  final double progress;
  final List<_Mote> motes;

  const _GravePainter({required this.progress, required this.motes});

  @override
  void paint(Canvas canvas, Size size) {
    for (final m in motes) {
      final p = (progress * m.rise).clamp(0.0, 1.0);
      final dx = (m.x + m.drift * progress) * size.width;
      final dy = (m.y - p * 0.7) * size.height;
      final paint = Paint()
        ..color = Colors.grey[m.shade]!
            .withValues(alpha: (1 - progress) * 0.9);
      canvas.drawRect(
        Rect.fromCenter(
          center: Offset(dx, dy),
          width: m.size,
          height: m.size,
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _GravePainter old) =>
      old.progress != progress;
}
