import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_layout.dart';
import 'particle_wave.dart';

/// Page frame for the karaoke screens.
///
/// The shell fills the available Android display and applies bounded responsive
/// padding so the same karaoke UI can run on TV boxes, car head units, and
/// smaller Android fallback screens without relying on one fixed canvas.
///
/// Chrome is a single left [navRail], never a top or bottom bar: on a car head
/// unit and a landscape karaoke box the screen is short and wide, so anything
/// stacked above or below the body comes straight out of the video stage's
/// height. A rail costs width, which is the dimension there is spare of.
class KaraokeShell extends StatelessWidget {
  const KaraokeShell({
    super.key,
    required this.body,
    this.navRail,
    this.showEdgeParticles = false,
    this.chromeVisible = true,
  });

  final Widget body;

  /// Left navigation rail. Null on the screens that have no navigation at all
  /// (splash, license gate).
  final Widget? navRail;

  /// Red/purple particle streams along the lower corners, used on the source
  /// picker where the background is part of the composition.
  final bool showEdgeParticles;

  /// When false the rail is not built at all, giving the body the whole shell.
  /// Used by the player's fullscreen mode.
  final bool chromeVisible;

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
          child: LayoutBuilder(
            builder: (context, constraints) {
              // Portrait is a fallback, not a supported layout: fit a whole
              // landscape canvas into it and accept the letterboxing.
              final isPortrait = constraints.maxWidth < constraints.maxHeight;
              // Below the landscape floor the UI is scaled down rather than
              // allowed to overflow. The canvas is then sized to the display's
              // OWN aspect ratio, not to a fixed 1366x768 — fitting a fixed
              // canvas into a display of a different ratio (e.g. a 1280x720
              // head unit) left black bars down both sides, which read as the
              // nav rail being pushed away from the screen edge.
              final scale = math.min(
                constraints.maxWidth / AppLayout.minimumLandscapeWidth,
                constraints.maxHeight / AppLayout.minimumLandscapeHeight,
              );

              return Stack(
                children: [
                  // Static decorative background (color pools + optional edge
                  // particles). Isolated on its own layer so foreground focus
                  // animations do not force it to repaint.
                  Positioned.fill(
                    child: RepaintBoundary(
                      child: Stack(
                        children: [
                          _AuroraBlob(
                            alignment: const Alignment(-0.85, 0.55),
                            color: AppColors.red,
                            size: constraints.biggest.shortestSide * 0.84,
                            opacity: 0.16,
                          ),
                          _AuroraBlob(
                            alignment: const Alignment(0.9, 0.6),
                            color: AppColors.purple,
                            size: constraints.biggest.shortestSide * 0.82,
                            opacity: 0.16,
                          ),
                          _AuroraBlob(
                            alignment: const Alignment(0.1, -0.95),
                            color: AppColors.blue,
                            size: constraints.biggest.shortestSide * 0.92,
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
                        ],
                      ),
                    ),
                  ),
                  Positioned.fill(
                    child: isPortrait
                        ? Center(
                            child: FittedBox(
                              fit: BoxFit.contain,
                              child: SizedBox(
                                width: AppLayout.minimumLandscapeWidth,
                                height: AppLayout.minimumLandscapeHeight,
                                child: _ShellContent(
                                  navRail: navRail,
                                  body: body,
                                  chromeVisible: chromeVisible,
                                ),
                              ),
                            ),
                          )
                        : scale >= 1
                        ? _ShellContent(
                            navRail: navRail,
                            body: body,
                            chromeVisible: chromeVisible,
                          )
                        : FittedBox(
                            // The child's ratio is the display's ratio by
                            // construction, so `fill` scales it uniformly and
                            // covers the display exactly — no bars, no stretch.
                            fit: BoxFit.fill,
                            child: SizedBox(
                              width: constraints.maxWidth / scale,
                              height: constraints.maxHeight / scale,
                              child: _ShellContent(
                                navRail: navRail,
                                body: body,
                                chromeVisible: chromeVisible,
                              ),
                            ),
                          ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _ShellContent extends StatelessWidget {
  const _ShellContent({
    required this.navRail,
    required this.body,
    required this.chromeVisible,
  });

  final Widget? navRail;
  final Widget body;
  final bool chromeVisible;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final horizontalPadding = AppLayout.shellHorizontalPaddingFor(
          constraints.maxWidth,
        );
        final topPadding = AppLayout.shellTopPaddingFor(constraints.maxHeight);
        final bottomPadding = AppLayout.shellBottomPaddingFor(
          constraints.maxHeight,
        );
        final showRail = chromeVisible && navRail != null;

        return Padding(
          // Fullscreen means fullscreen: with the rail gone the shell padding
          // would still frame the body in a band of background on all four
          // sides, so the body would only grow slightly instead of taking the
          // whole display.
          //
          // With the rail up every margin is the same hairline
          // [AppLayout.navRailInset]: the four shell edges and the gap between
          // the rail and the body. One value, no special case for the left
          // side, so the selected destination's plate is framed identically
          // wherever you look. Pages with no rail (splash, the license gate)
          // keep the full responsive gutters: they are a centred card on a
          // backdrop, not a stage.
          padding: chromeVisible
              ? showRail
                    ? const EdgeInsets.all(AppLayout.navRailInset)
                    : EdgeInsets.fromLTRB(
                        horizontalPadding,
                        topPadding,
                        horizontalPadding,
                        bottomPadding,
                      )
              : EdgeInsets.zero,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (showRail) ...[
                SizedBox(
                  width: AppLayout.navRailWidthFor(constraints.maxWidth),
                  child: navRail,
                ),
                const SizedBox(width: AppLayout.navRailInset),
              ],
              // Keyed so toggling the chrome does not destroy and rebuild the
              // body. Without it the body's index in this Row shifts from 2
              // to 0 when the rail goes, the element is discarded, and every
              // piece of state under it — the player's focus nodes, its
              // fullscreen overlay, its whole widget subtree — is recreated.
              Expanded(key: const ValueKey('karaokeShellBody'), child: body),
            ],
          ),
        );
      },
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
              waveCount: 4,
              opacity: 0.55,
            ),
          ),
        ),
      ),
    );
  }
}
