import 'dart:math';

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';

/// Stand-in artwork for a song row.
///
/// The catalog is mock data with no image assets, so each row paints a stage-lit
/// silhouette seeded from the song id. That reads like a video thumbnail at list
/// size while staying inside the karaoke neon palette.
class SongThumbnail extends StatelessWidget {
  const SongThumbnail({
    super.key,
    required this.seed,
    required this.width,
    required this.height,
    this.imageUrl,
    this.badge,
    this.durationLabel,
  });

  final int seed;
  final double width;
  final double height;
  final String? imageUrl;
  final String? badge;
  final String? durationLabel;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.xs),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (imageUrl != null && imageUrl!.isNotEmpty)
              Image.network(
                imageUrl!,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => _StageThumbnailFallback(seed: seed),
              )
            else
              _StageThumbnailFallback(seed: seed),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.45),
                  ],
                ),
              ),
            ),
            if (badge != null)
              Positioned(
                top: 4,
                left: 4,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 5,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.red,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    badge!,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                      height: 1.2,
                    ),
                  ),
                ),
              ),
            if (durationLabel != null)
              Positioned(
                left: 4,
                bottom: 4,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 5,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.black70,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    durationLabel!,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textPrimary,
                      height: 1.2,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _StageThumbnailFallback extends StatelessWidget {
  const _StageThumbnailFallback({required this.seed});

  final int seed;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _StageThumbPainter(seed: seed));
  }
}

class _StageThumbPainter extends CustomPainter {
  const _StageThumbPainter({required this.seed});

  final int seed;

  static const List<Color> _stageColors = [
    Color(0xFF2563EB),
    Color(0xFF7C3AED),
    Color(0xFFBE123C),
    Color(0xFFB45309),
    Color(0xFF0E7490),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final random = Random(seed * 31 + 7);
    final stage = _stageColors[seed % _stageColors.length];
    final rect = Offset.zero & size;

    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color.lerp(stage, Colors.black, 0.45)!,
            Color.lerp(stage, Colors.black, 0.82)!,
          ],
        ).createShader(rect),
    );

    // Out-of-focus stage lights behind the performer.
    for (var i = 0; i < 5; i++) {
      final center = Offset(
        random.nextDouble() * size.width,
        random.nextDouble() * size.height * 0.7,
      );
      final radius = size.height * (0.08 + random.nextDouble() * 0.16);
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..color = stage.withValues(alpha: 0.20 + random.nextDouble() * 0.30)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
      );
    }

    // Head-and-shoulders silhouette.
    final silhouette = Paint()..color = Colors.black.withValues(alpha: 0.72);
    final headRadius = size.height * 0.17;
    final headCenter = Offset(size.width * 0.5, size.height * 0.46);
    canvas.drawCircle(headCenter, headRadius, silhouette);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(size.width * 0.5, size.height * 1.02),
        width: size.width * 0.72,
        height: size.height * 0.86,
      ),
      silhouette,
    );
  }

  @override
  bool shouldRepaint(_StageThumbPainter oldDelegate) =>
      oldDelegate.seed != seed;
}
