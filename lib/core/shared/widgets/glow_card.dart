import 'package:flutter/material.dart';

import '../../theme/app_glows.dart';
import '../../theme/app_layout.dart';
import '../../theme/app_radius.dart';
import 'focusable_tile.dart';
import 'liquid_glass.dart';
import 'particle_wave.dart';

/// Large neon panel used for the source picker: an accent-tinted dark card with
/// a glowing border, particle streams in the lower half, and a short accent bar
/// floating underneath.
class GlowCard extends StatelessWidget {
  const GlowCard({
    super.key,
    required this.accentColor,
    required this.child,
    required this.onPressed,
    this.particleSeed = 7,
    this.focusNode,
    this.autofocus = false,
    this.onFocusChange,
  });

  final Color accentColor;
  final Widget child;
  final VoidCallback onPressed;
  final int particleSeed;
  final FocusNode? focusNode;
  final bool autofocus;
  final ValueChanged<bool>? onFocusChange;

  @override
  Widget build(BuildContext context) {
    return FocusableTile(
      focusNode: focusNode,
      autofocus: autofocus,
      onFocusChange: onFocusChange,
      onPressed: onPressed,
      builder: (context, focused) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Expanded(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOut,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  boxShadow: AppGlows.card(accentColor, focused: focused),
                ),
                // Glass, but kept fairly solid on purpose: the outer bloom sits
                // directly behind the card and a thinner face would let it wash
                // out the whole panel.
                child: LiquidGlass(
                  radius: AppRadius.lg,
                  tint: accentColor,
                  tintStrength: focused ? 0.13 : 0.09,
                  opacity: focused ? 0.72 : 0.68,
                  rimWidth: focused ? 2.4 : 1.2,
                  rimColor: focused
                      ? accentColor
                      : accentColor.withValues(alpha: 0.34),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Align(
                        alignment: Alignment.bottomCenter,
                        child: FractionallySizedBox(
                          heightFactor: 0.5,
                          child: ParticleWave(
                            color: accentColor,
                            seed: particleSeed,
                            opacity: focused ? 1 : 0.7,
                          ),
                        ),
                      ),
                      child,
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppLayout.sourceAccentBarGap),
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: AppLayout.sourceAccentBarWidth,
              height: AppLayout.sourceAccentBarHeight,
              decoration: BoxDecoration(
                color: accentColor,
                borderRadius: BorderRadius.circular(AppRadius.pill),
                boxShadow: focused ? AppGlows.bar(accentColor) : null,
              ),
            ),
          ],
        );
      },
    );
  }
}
