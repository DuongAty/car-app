import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_layout.dart';
import 'particle_wave.dart';

/// Page frame for the karaoke screens.
///
/// The screens are authored against a fixed 1920x1080 canvas and scaled to fit
/// the device, which keeps the dense TV layout pixel-consistent on every
/// Android screen size and rules out render overflow.
class KaraokeShell extends StatelessWidget {
  const KaraokeShell({
    super.key,
    required this.topBar,
    required this.body,
    required this.bottomBar,
    this.showEdgeParticles = false,
  });

  final Widget topBar;
  final Widget body;
  final Widget bottomBar;

  /// Red/purple particle streams along the lower corners, used on the source
  /// picker where the background is part of the composition.
  final bool showEdgeParticles;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -0.75),
            radius: 1.15,
            colors: [
              Color(0xFF0C0D12),
              AppColors.background,
              Color(0xFF030304),
            ],
            stops: [0, 0.55, 1],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: FittedBox(
              fit: BoxFit.contain,
              child: SizedBox(
                width: AppLayout.designWidth,
                height: AppLayout.designHeight,
                child: Stack(
                  children: [
                    // Soft color pools so the glass panels have something to
                    // pick up instead of reading as flat grey.
                    const _AuroraBlob(
                      alignment: Alignment(-0.85, 0.55),
                      color: AppColors.red,
                      size: 900,
                      opacity: 0.16,
                    ),
                    const _AuroraBlob(
                      alignment: Alignment(0.9, 0.6),
                      color: AppColors.purple,
                      size: 880,
                      opacity: 0.16,
                    ),
                    const _AuroraBlob(
                      alignment: Alignment(0.1, -0.95),
                      color: AppColors.blue,
                      size: 1000,
                      opacity: 0.11,
                    ),
                    if (showEdgeParticles) ...const [
                      _EdgeParticles(
                        alignment: Alignment.bottomLeft,
                        color: AppColors.red,
                        angle: -0.36,
                        seed: 11,
                      ),
                      _EdgeParticles(
                        alignment: Alignment.bottomRight,
                        color: AppColors.purple,
                        angle: 0.32,
                        seed: 23,
                      ),
                    ],
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppLayout.shellPaddingHorizontal,
                        AppLayout.shellPaddingTop,
                        AppLayout.shellPaddingHorizontal,
                        AppLayout.shellPaddingBottom,
                      ),
                      child: Column(
                        children: [
                          topBar,
                          const SizedBox(height: AppLayout.shellBodyGap),
                          Expanded(child: body),
                          const SizedBox(height: AppLayout.shellBottomGap),
                          bottomBar,
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AuroraBlob extends StatelessWidget {
  const _AuroraBlob({
    required this.alignment,
    required this.color,
    required this.size,
    required this.opacity,
  });

  final Alignment alignment;
  final Color color;
  final double size;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Align(
        alignment: alignment,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                color.withValues(alpha: opacity),
                color.withValues(alpha: opacity * 0.35),
                color.withValues(alpha: 0),
              ],
              stops: const [0, 0.45, 1],
            ),
          ),
        ),
      ),
    );
  }
}

class _EdgeParticles extends StatelessWidget {
  const _EdgeParticles({
    required this.alignment,
    required this.color,
    required this.angle,
    required this.seed,
  });

  final Alignment alignment;
  final Color color;
  final double angle;
  final int seed;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignment,
      child: Transform.translate(
        offset: Offset(alignment.x * 70, -110),
        child: Transform.rotate(
          angle: angle * math.pi / 2,
          child: SizedBox(
            width: 560,
            height: 380,
            child: ParticleWave(
              color: color,
              seed: seed,
              waveCount: 6,
              opacity: 0.55,
            ),
          ),
        ),
      ),
    );
  }
}
