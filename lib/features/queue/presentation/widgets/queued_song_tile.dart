import 'package:flutter/material.dart';

import '../../../../core/shared/widgets/focusable_tile.dart';
import '../../../../core/shared/widgets/liquid_glass.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_icons.dart';
import '../../../../core/theme/app_glows.dart';
import '../../../../core/theme/app_layout.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../l10n/l10n.dart';
import '../../../song_browser/presentation/widgets/song_thumbnail.dart';
import '../../../source_selection/presentation/widgets/source_badge.dart';
import '../../data/models/queued_song.dart';

/// Row on the queue screen: the same shape as [SearchResultTile] (thumbnail,
/// title, subtitle, tap-to-play), but with a source badge — since queue items
/// can come from any of the three sources — and a remove "×" instead of add.
class QueuedSongTile extends StatelessWidget {
  const QueuedSongTile({
    super.key,
    required this.item,
    required this.selected,
    required this.onPressed,
    required this.onRemove,
    this.dragHandle,
    this.onFocused,
  });

  final QueuedSong item;
  final bool selected;
  final VoidCallback onPressed;
  final VoidCallback onRemove;
  final Widget? dragHandle;

  final ValueChanged<bool>? onFocused;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final song = item.song;

    return FocusableTile(
      onPressed: onPressed,
      onFocusChange: (focused) => onFocused?.call(focused),
      builder: (context, focused) {
        final active = selected || focused;

        // Plain Container, not AnimatedContainer: instant focus highlight
        // avoids tweening a blurred BoxShadow on every D-pad move while
        // scrolling the queue. See SearchResultTile for the rationale.
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
              if (dragHandle != null) ...[
                dragHandle!,
                const SizedBox(width: AppSpacing.xs),
              ],
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
                            child: SourceBadge(source: item.source.logoStyle),
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
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Tooltip(
                message: context.l10n.queueRemoveTooltip,
                child: InkWell(
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
                      // Matches the row's own focus accent (green) rather than
                      // a destructive red: this button sits inside a
                      // green-highlighted row, and a red fill there reads as
                      // an error state rather than a normal remove action.
                      tint: active ? AppColors.green : null,
                      tintStrength: 0.3,
                      rimColor: active ? AppColors.green : null,
                      child: Center(
                        child: Icon(
                          AppIcons.close,
                          size: 22,
                          color: active
                              ? AppColors.green
                              : AppColors.textPrimary,
                        ),
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
