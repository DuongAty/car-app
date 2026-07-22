import 'package:flutter/material.dart';

import '../../../../core/shared/widgets/brand_logos.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../data/models/music_source.dart';

/// Logo and description stacked inside a source card. The flex spacers place
/// the logo just above the card's midpoint and the copy in the lower third,
/// matching the karaoke neon source picker.
class SourceCardContent extends StatelessWidget {
  const SourceCardContent({super.key, required this.source});

  final MusicSource source;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Column(
        children: [
          const Spacer(flex: 26),
          // Logos are typographic, so their intrinsic width shifts with the
          // platform font. Scaling down keeps every card safe on any device.
          FittedBox(
            fit: BoxFit.scaleDown,
            child: _SourceLogo(style: source.logoStyle),
          ),
          const Spacer(flex: 13),
          Text(
            source.subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w400,
              color: AppColors.textPrimary,
              height: 1.35,
            ),
          ),
          const Spacer(flex: 23),
        ],
      ),
    );
  }
}

class _SourceLogo extends StatelessWidget {
  const _SourceLogo({required this.style});

  final MusicSourceLogoStyle style;

  @override
  Widget build(BuildContext context) {
    return switch (style) {
      MusicSourceLogoStyle.youtube => const YoutubeLogo(height: 56),
      MusicSourceLogoStyle.soundcloud => const SoundCloudLogo(width: 240),
      MusicSourceLogoStyle.mixcloud => const MixcloudLogo(fontSize: 50),
    };
  }
}
