import 'package:flutter/material.dart';

import '../../../../core/shared/widgets/favorite_toggle.dart';
import '../../../../core/shared/widgets/focusable_tile.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_glows.dart';
import '../../../../core/theme/app_layout.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../source_selection/data/models/music_source.dart';
import '../../data/models/song_item.dart';
import 'song_thumbnail.dart';

/// Row in the "GỢI Ý CHO BẠN" column: artwork, title, artist, and duration.
class SuggestionTile extends StatelessWidget {
  const SuggestionTile({
    super.key,
    required this.item,
    required this.selected,
    required this.onPressed,
    required this.source,
    this.onFocused,
  });

  final SongItem item;
  final bool selected;
  final VoidCallback onPressed;
  final MusicSourceLogoStyle source;
  final VoidCallback? onFocused;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return FocusableTile(
      onPressed: onPressed,
      onFocusChange: (focused) {
        if (focused) {
          onFocused?.call();
        }
      },
      builder: (context, focused) {
        final active = selected || focused;

        // Plain Container, not AnimatedContainer: instant focus highlight
        // avoids tweening a blurred BoxShadow on every D-pad move. See
        // SearchResultTile for the rationale.
        return Container(
          height: AppLayout.browserSuggestionTileHeight,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xs,
            vertical: AppSpacing.xs,
          ),
          decoration: BoxDecoration(
            color: active
                ? AppColors.green.withValues(alpha: 0.16)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadius.sm),
            border: Border.all(
              color: active ? AppColors.green : Colors.transparent,
              width: 1.5,
            ),
            boxShadow: AppGlows.control(AppColors.green, focused: active),
          ),
          child: Row(
            children: [
              SongThumbnail(
                seed: item.thumbnailSeed,
                width: 72,
                height: 52,
                imageUrl: item.imageUrl,
                badge: item.badge,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      item.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.titleMedium?.copyWith(fontSize: 19),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              FavoriteToggle(
                song: item,
                source: source,
                size: 36,
                iconSize: 18,
              ),
              const SizedBox(width: AppSpacing.xs),
              Text(item.duration, style: textTheme.bodySmall),
            ],
          ),
        );
      },
    );
  }
}
