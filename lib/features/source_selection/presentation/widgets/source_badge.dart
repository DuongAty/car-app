import 'package:flutter/material.dart';

import '../../../../core/shared/widgets/brand_logos.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../data/models/music_source.dart';

/// Small badge identifying which platform a piece of content came from.
/// Shared between the now-playing preview and the queue list, so a queued
/// song reads the same regardless of where it was added from.
class SourceBadge extends StatelessWidget {
  const SourceBadge({super.key, required this.source});

  final MusicSourceLogoStyle source;

  @override
  Widget build(BuildContext context) {
    return switch (source) {
      MusicSourceLogoStyle.youtube => const YoutubeBadge(height: 30),
      MusicSourceLogoStyle.soundcloud => const _PillBadge(
        color: AppColors.orange,
        label: 'SoundCloud',
      ),
    };
  }
}

/// Mark-only indicator for the top bar: just the platform's icon, no
/// wordmark or pill background. Unlike [SourceBadge], this must never be
/// reused at the badge call sites (favorites/history rows, preview player,
/// queue rows) — those keep the full wordmark chip.
class SourceMark extends StatelessWidget {
  const SourceMark({super.key, required this.source});

  final MusicSourceLogoStyle source;

  @override
  Widget build(BuildContext context) {
    return switch (source) {
      MusicSourceLogoStyle.youtube => const YoutubeMark(height: 32),
      MusicSourceLogoStyle.soundcloud => const SoundCloudMark(height: 32),
    };
  }
}

class _PillBadge extends StatelessWidget {
  const _PillBadge({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(AppRadius.xs),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
          height: 1.2,
        ),
      ),
    );
  }
}
