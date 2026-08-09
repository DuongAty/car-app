import 'package:flutter/material.dart';

import '../../../features/song_browser/presentation/widgets/song_thumbnail.dart';
import '../../../features/source_selection/presentation/widgets/source_badge.dart';
import '../../models/persisted_song_entry.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_icons.dart';
import '../../theme/app_glows.dart';
import '../../theme/app_layout.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_spacing.dart';
import 'focusable_tile.dart';
import 'liquid_glass.dart';

/// Row shared by the Favorites and History pages: thumbnail, title, source
/// badge + subtitle, an optional trailing meta label (History's relative
/// time), and a remove "×". Same shape as `QueuedSongTile` minus the reorder
/// arrows, which only make sense for an ordered queue.
class PersistedSongTile extends StatelessWidget {
  const PersistedSongTile({
    super.key,
    required this.entry,
    required this.selected,
    required this.onPressed,
    required this.onRemove,
    this.metaLabel,
    this.onFocused,
  });

  final PersistedSongEntry entry;
  final bool selected;
  final VoidCallback onPressed;
  final VoidCallback onRemove;
  final String? metaLabel;
  final ValueChanged<bool>? onFocused;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final song = entry.song;

    return FocusableTile(
      onPressed: onPressed,
      onFocusChange: (focused) => onFocused?.call(focused),
      builder: (context, focused) {
        final active = selected || focused;

        // Plain Container, not AnimatedContainer: instant focus highlight
        // avoids tweening a blurred BoxShadow on every D-pad move while
        // scrolling favorites/history. See SearchResultTile for the rationale.
        return Container(
          height: AppLayout.browserResultTileHeight,
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
                seed: song.thumbnailSeed,
                width: 104,
                height: 62,
                imageUrl: song.imageUrl,
                durationLabel: song.duration,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      song.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.titleMedium?.copyWith(fontSize: 19),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        SizedBox(
                          height: 18,
                          child: FittedBox(
                            child: SourceBadge(source: entry.source),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        Expanded(
                          child: Text(
                            song.subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: textTheme.bodySmall,
                          ),
                        ),
                        if (metaLabel != null) ...[
                          const SizedBox(width: AppSpacing.xs),
                          Text(metaLabel!, style: textTheme.bodySmall),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              InkWell(
                onTap: onRemove,
                customBorder: const CircleBorder(),
                child: SizedBox(
                  width: 42,
                  height: 42,
                  child: LiquidGlass(
                    capsule: true,
                    detail: LiquidGlassDetail.simple,
                    lifted: false,
                    opacity: 0.38,
                    tint: active ? AppColors.green : null,
                    tintStrength: 0.3,
                    rimColor: active ? AppColors.green : null,
                    child: Center(
                      child: Icon(
                        AppIcons.close,
                        size: 22,
                        color: active ? AppColors.green : AppColors.textPrimary,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
