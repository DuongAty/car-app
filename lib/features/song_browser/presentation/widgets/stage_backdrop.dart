import 'dart:math';

import 'package:flutter/material.dart';

/// Painted stand-in for the music video frame: blue concert lighting, bokeh,
/// and a performer silhouette. Used because the mock catalog ships no media.
class StageBackdrop extends StatelessWidget {
  const StageBackdrop({super.key});

  @override
  Widget build(BuildContext context) {
    return const IgnorePointer(
      child: CustomPaint(painter: _StageBackdropPainter(), size: Size.infinite),
    );
  }
}

class _StageBackdropPainter extends CustomPainter {
  const _StageBackdropPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final random = Random(2024);

    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF12325E), Color(0xFF0B1B33), Color(0xFF05080F)],
          stops: [0, 0.55, 1],
        ).createShader(rect),
    );

    // Light beams fanning down from the rig.
    for (var i = 0; i < 5; i++) {
      final originX = size.width * (0.12 + i * 0.19);
      final spread = size.width * 0.09;
      final path = Path()
        ..moveTo(originX, -10)
        ..lineTo(originX - spread, size.height * 0.85)
        ..lineTo(originX + spread, size.height * 0.85)
        ..close();
      canvas.drawPath(
        path,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              const Color(0xFF6EA8FF).withValues(alpha: 0.18),
              const Color(0xFF6EA8FF).withValues(alpha: 0),
            ],
          ).createShader(Rect.fromLTWH(0, 0, size.width, size.height * 0.85))
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12),
      );
    }

    // Out-of-focus lights.
    for (var i = 0; i < 26; i++) {
      final center = Offset(
        random.nextDouble() * size.width,
        random.nextDouble() * size.height * 0.72,
      );
      final radius = size.height * (0.012 + random.nextDouble() * 0.045);
      final tint = random.nextBool()
          ? const Color(0xFF8FC2FF)
          : const Color(0xFFFFF3C4);
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..color = tint.withValues(alpha: 0.12 + random.nextDouble() * 0.32)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, radius * 0.7),
      );
    }

    _paintPerformer(canvas, size);
  }

  void _paintPerformer(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF05070C).withValues(alpha: 0.9);
    final centerX = size.width * 0.55;
    final headRadius = size.height * 0.115;
    final headCenter = Offset(centerX, size.height * 0.36);

    // Torso.
    canvas.drawPath(
      Path()
        ..moveTo(centerX - size.width * 0.14, size.height)
        ..lineTo(centerX - size.width * 0.085, size.height * 0.52)
        ..quadraticBezierTo(
          centerX,
          size.height * 0.44,
          centerX + size.width * 0.085,
          size.height * 0.52,
        )
        ..lineTo(centerX + size.width * 0.14, size.height)
        ..close(),
      paint,
    );

    canvas.drawCircle(headCenter, headRadius, paint);

    // Arm raised toward a microphone.
    canvas.drawPath(
      Path()
        ..moveTo(centerX - size.width * 0.075, size.height * 0.58)
        ..lineTo(centerX - size.width * 0.115, size.height * 0.44)
        ..lineTo(centerX - size.width * 0.075, size.height * 0.40)
        ..lineTo(centerX - size.width * 0.045, size.height * 0.56)
        ..close(),
      paint,
    );

    canvas.drawCircle(
      Offset(centerX - size.width * 0.072, size.height * 0.375),
      size.height * 0.028,
      paint,
    );
  }

  @override
  bool shouldRepaint(_StageBackdropPainter oldDelegate) => false;
}
