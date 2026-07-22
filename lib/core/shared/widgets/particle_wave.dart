import 'dart:math';

import 'package:flutter/material.dart';

/// Decorative flowing particle streams used behind the source cards and along
/// the edges of the app shell. Purely ornamental, never hit-testable.
class ParticleWave extends StatelessWidget {
  const ParticleWave({
    super.key,
    required this.color,
    this.seed = 7,
    this.waveCount = 5,
    this.opacity = 1,
  });

  final Color color;
  final int seed;
  final int waveCount;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(
        painter: _ParticleWavePainter(
          color: color,
          seed: seed,
          waveCount: waveCount,
          opacity: opacity,
        ),
        size: Size.infinite,
      ),
    );
  }
}

class _ParticleWavePainter extends CustomPainter {
  const _ParticleWavePainter({
    required this.color,
    required this.seed,
    required this.waveCount,
    required this.opacity,
  });

  final Color color;
  final int seed;
  final int waveCount;
  final double opacity;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) {
      return;
    }

    final random = Random(seed);
    final paint = Paint();

    for (var wave = 0; wave < waveCount; wave++) {
      final baseY = size.height * (0.32 + 0.15 * wave);
      final amplitude = size.height * (0.06 + random.nextDouble() * 0.10);
      final phase = random.nextDouble() * pi * 2;
      final frequency = 1.1 + random.nextDouble() * 0.9;
      final depthFade = 1 - wave / (waveCount + 1);
      final dotCount = max(24, (size.width / 4).round());

      for (var i = 0; i < dotCount; i++) {
        final t = i / (dotCount - 1);
        final x = t * size.width;
        final y = baseY + sin(phase + t * frequency * pi * 2) * amplitude;
        if (y < 0 || y > size.height) {
          continue;
        }

        // Fade the stream out at both horizontal ends so it dissolves into
        // the panel instead of ending on a hard edge.
        final edgeFade = sin(t * pi).clamp(0.0, 1.0);
        final alpha =
            opacity *
            edgeFade *
            depthFade *
            (0.18 + random.nextDouble() * 0.55);

        paint.color = color.withValues(alpha: alpha.clamp(0.0, 1.0));
        canvas.drawCircle(Offset(x, y), 0.7 + random.nextDouble() * 1.4, paint);
      }
    }
  }

  @override
  bool shouldRepaint(_ParticleWavePainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.seed != seed ||
        oldDelegate.waveCount != waveCount ||
        oldDelegate.opacity != opacity;
  }
}
