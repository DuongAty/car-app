import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_radius.dart';

/// YouTube wordmark: red play plate followed by the "YouTube" word.
class YoutubeLogo extends StatelessWidget {
  const YoutubeLogo({super.key, this.height = 62});

  final double height;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _PlayPlate(height: height),
        SizedBox(width: height * 0.24),
        Text(
          'YouTube',
          style: TextStyle(
            fontSize: height * 0.82,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
            letterSpacing: -1.2,
            height: 1,
          ),
        ),
      ],
    );
  }
}

/// Compact light chip used as the source badge on the preview player.
class YoutubeBadge extends StatelessWidget {
  const YoutubeBadge({super.key, this.height = 30});

  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: height * 0.36,
        vertical: height * 0.22,
      ),
      decoration: BoxDecoration(
        color: AppColors.textPrimary,
        borderRadius: BorderRadius.circular(AppRadius.xs),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _PlayPlate(height: height * 0.72, radiusFactor: 0.28),
          SizedBox(width: height * 0.22),
          Text(
            'YouTube',
            style: TextStyle(
              fontSize: height * 0.66,
              fontWeight: FontWeight.w700,
              color: AppColors.background,
              letterSpacing: -0.6,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
}

class _PlayPlate extends StatelessWidget {
  const _PlayPlate({required this.height, this.radiusFactor = 0.3});

  final double height;
  final double radiusFactor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: height * 1.42,
      height: height,
      decoration: BoxDecoration(
        color: AppColors.youtubeRed,
        borderRadius: BorderRadius.circular(height * radiusFactor),
      ),
      child: Center(
        child: CustomPaint(
          size: Size(height * 0.34, height * 0.4),
          painter: const _TrianglePainter(color: AppColors.textPrimary),
        ),
      ),
    );
  }
}

class _TrianglePainter extends CustomPainter {
  const _TrianglePainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, size.height / 2)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_TrianglePainter oldDelegate) =>
      oldDelegate.color != color;
}

/// SoundCloud wordmark: waveform bars flowing into a cloud, over the word.
class SoundCloudLogo extends StatelessWidget {
  const SoundCloudLogo({super.key, this.width = 240});

  final double width;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CustomPaint(
          size: Size(width, width * 0.44),
          painter: const _SoundCloudMarkPainter(color: AppColors.orange),
        ),
        SizedBox(height: width * 0.03),
        Text(
          'SOUNDCLOUD',
          style: TextStyle(
            fontSize: width * 0.155,
            fontWeight: FontWeight.w800,
            color: AppColors.orange,
            letterSpacing: 0.5,
            height: 1,
          ),
        ),
      ],
    );
  }
}

class _SoundCloudMarkPainter extends CustomPainter {
  const _SoundCloudMarkPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final baseline = size.height;

    // Waveform bars ramping up toward the cloud.
    const barCount = 15;
    final barSlot = size.width * 0.52 / barCount;
    final barWidth = barSlot * 0.58;
    const heights = <double>[
      0.30,
      0.42,
      0.34,
      0.52,
      0.46,
      0.62,
      0.55,
      0.74,
      0.66,
      0.84,
      0.78,
      0.92,
      0.86,
      0.96,
      0.90,
    ];

    for (var i = 0; i < barCount; i++) {
      final barHeight = size.height * heights[i];
      final left = i * barSlot;
      canvas.drawRRect(
        RRect.fromLTRBR(
          left,
          baseline - barHeight,
          left + barWidth,
          baseline,
          Radius.circular(barWidth / 2),
        ),
        paint,
      );
    }

    // Cloud body sitting to the right of the bars.
    final cloudLeft = size.width * 0.50;
    final cloudWidth = size.width - cloudLeft;
    final path = Path()
      ..addOval(
        Rect.fromCircle(
          center: Offset(cloudLeft + cloudWidth * 0.34, size.height * 0.42),
          radius: size.height * 0.42,
        ),
      )
      ..addOval(
        Rect.fromCircle(
          center: Offset(cloudLeft + cloudWidth * 0.74, size.height * 0.56),
          radius: size.height * 0.34,
        ),
      )
      ..addRRect(
        RRect.fromLTRBR(
          cloudLeft,
          size.height * 0.56,
          size.width,
          baseline,
          Radius.circular(size.height * 0.22),
        ),
      );

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_SoundCloudMarkPainter oldDelegate) =>
      oldDelegate.color != color;
}

/// Mixcloud wordmark.
class MixcloudLogo extends StatelessWidget {
  const MixcloudLogo({super.key, this.fontSize = 54});

  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return Text(
      'M—XCLOUD',
      style: TextStyle(
        fontSize: fontSize,
        fontWeight: FontWeight.w700,
        color: AppColors.purple,
        letterSpacing: 1.5,
        height: 1,
      ),
    );
  }
}
