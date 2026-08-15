import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_radius.dart';

/// How much edge detail a surface paints.
enum LiquidGlassDetail {
  /// Blurred edge bloom plus bevel. For large surfaces: panels, cards, bars.
  full,

  /// Crisp rim and bevel only, no blur passes. For elements that appear in
  /// bulk, such as the 40 keyboard keys, where blurred strokes would add up.
  simple,

  /// No edge at all: the tinted body only. For a surface that should read as
  /// part of the background rather than as a floating panel — the page-wide
  /// content slab, which sits beside a rail that paints no edge either.
  none,
}

/// Liquid glass surface: a translucent slab with thickness.
///
/// Unlike flat glassmorphism, the edge is the point. Light collects unevenly
/// around the rim (brightest toward the top-left), a bright bevel sits just
/// inside the top edge, and a shadow sits inside the bottom edge, so the
/// surface reads as a solid piece of glass rather than a tinted rectangle.
///
/// Still no [BackdropFilter]: real refraction needs a full-screen texture read
/// per surface, which these screens cannot afford on Android TV hardware.
class LiquidGlass extends StatelessWidget {
  const LiquidGlass({
    super.key,
    required this.child,
    this.radius = AppRadius.md,
    this.capsule = false,
    this.padding = EdgeInsets.zero,
    this.tint,
    this.tintStrength = 0.16,
    this.opacity = 0.48,
    this.rimColor,
    this.rimWidth = 1.2,
    this.detail = LiquidGlassDetail.full,
    this.boxShadow,
    this.lifted = true,
    this.sheen = true,
  });

  final Widget child;

  /// Corner radius, drawn as an Apple-style superellipse. Ignored when
  /// [capsule] is set.
  final double radius;
  final bool capsule;
  final EdgeInsetsGeometry padding;

  /// Accent mixed into the glass body, e.g. a source card's brand color.
  final Color? tint;
  final double tintStrength;

  /// How solid the slab is. Raise it when a glow sits directly behind the
  /// surface and must not bleed through the face.
  final double opacity;

  /// Base color of the specular rim. Defaults to white light.
  final Color? rimColor;
  final double rimWidth;

  final LiquidGlassDetail detail;
  final List<BoxShadow>? boxShadow;

  /// Soft drop shadow so the slab floats above the background.
  final bool lifted;

  /// Diagonal light sweep across the face of the glass.
  ///
  /// This is what sells "you are looking through something" without a
  /// [BackdropFilter]: a real frost pass would read the whole screen texture
  /// per surface, which these boxes cannot afford, while a second gradient in
  /// the same [ShapeDecoration] costs nothing measurable. Turn it off for
  /// surfaces that carry busy imagery of their own (thumbnails, video).
  final bool sheen;

  @override
  Widget build(BuildContext context) {
    final shape = capsule
        ? const StadiumBorder()
        : RoundedSuperellipseBorder(
            borderRadius: BorderRadius.circular(radius),
          );

    final base = tint == null
        ? AppColors.backgroundSecondary
        : Color.lerp(AppColors.backgroundSecondary, tint!, tintStrength)!;
    final lit = Color.lerp(base, Colors.white, 0.14)!;

    final shadows = <BoxShadow>[
      if (lifted)
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.38),
          blurRadius: 12,
          offset: const Offset(0, 8),
        ),
      ...?boxShadow,
    ];

    final edge = detail == LiquidGlassDetail.none
        ? null
        : _LiquidEdgePainter(
            shape: shape,
            rimColor: rimColor ?? Colors.white,
            rimWidth: rimWidth,
            detail: detail,
          );

    return DecoratedBox(
      decoration: ShapeDecoration(
        shape: shape,
        shadows: shadows,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            lit.withValues(alpha: (opacity + 0.14).clamp(0.0, 1.0)),
            base.withValues(alpha: opacity),
            base.withValues(alpha: (opacity + 0.06).clamp(0.0, 1.0)),
          ],
          stops: const [0, 0.5, 1],
        ),
      ),
      child: ClipPath(
        clipper: ShapeBorderClipper(shape: shape),
        child: Stack(
          // Pass the surface's constraints through, otherwise a child shorter
          // than the surface is pinned to the top edge instead of filling it.
          fit: StackFit.passthrough,
          children: [
            // Under the content, so text keeps its full contrast.
            if (sheen)
              Positioned.fill(
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: const Alignment(-1, -1.4),
                        end: const Alignment(0.7, 1),
                        colors: [
                          Colors.white.withValues(alpha: 0.09),
                          Colors.white.withValues(alpha: 0.02),
                          Colors.transparent,
                        ],
                        stops: const [0, 0.34, 0.62],
                      ),
                    ),
                  ),
                ),
              ),
            Padding(padding: padding, child: child),
            // Painted last so the rim stays crisp over the content. Isolated on
            // its own layer so the shader/blur edge rasterizes once and is
            // reused instead of being redrawn every time the child content (or
            // a parent focus animation) repaints — the edge itself only changes
            // when the surface's own paint inputs change.
            if (edge != null)
              Positioned.fill(
                child: IgnorePointer(
                  child: RepaintBoundary(child: CustomPaint(painter: edge)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _LiquidEdgePainter extends CustomPainter {
  const _LiquidEdgePainter({
    required this.shape,
    required this.rimColor,
    required this.rimWidth,
    required this.detail,
  });

  final ShapeBorder shape;
  final Color rimColor;
  final double rimWidth;
  final LiquidGlassDetail detail;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) {
      return;
    }

    final rect = Offset.zero & size;
    final path = shape.getOuterPath(rect);

    // Everything here is drawn inside a clip of the same shape, so a stroke
    // nudged off-center keeps only the half that falls within the surface.
    if (detail == LiquidGlassDetail.full) {
      // Light pooling in the body of the glass, just inside the edge.
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 10
          ..color = rimColor.withValues(alpha: 0.07)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
      );

      // Shadow inside the bottom edge reads as slab thickness.
      canvas.save();
      canvas.translate(0, -3.5);
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 5
          ..color = Colors.black.withValues(alpha: 0.34)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1),
      );
      canvas.restore();
    }

    // Bright bevel inside the top edge.
    canvas.save();
    canvas.translate(0, 1.6);
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..color = rimColor.withValues(alpha: 0.26),
    );
    canvas.restore();

    // Specular rim: light gathers toward the top-left with a weaker catch on
    // the opposite side, which is what separates liquid glass from a plain
    // uniform border.
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = rimWidth
        ..shader = SweepGradient(
          transform: const GradientRotation(math.pi * 1.25),
          colors: [
            rimColor.withValues(alpha: 0.72),
            rimColor.withValues(alpha: 0.16),
            rimColor.withValues(alpha: 0.38),
            rimColor.withValues(alpha: 0.12),
            rimColor.withValues(alpha: 0.72),
          ],
          stops: const [0, 0.28, 0.5, 0.78, 1],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(_LiquidEdgePainter oldDelegate) {
    return oldDelegate.shape != shape ||
        oldDelegate.rimColor != rimColor ||
        oldDelegate.rimWidth != rimWidth ||
        oldDelegate.detail != detail;
  }
}
