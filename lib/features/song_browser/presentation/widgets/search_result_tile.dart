import 'package:flutter/material.dart';

import '../../../../core/shared/widgets/focusable_tile.dart';
import '../../../../core/shared/widgets/liquid_glass.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_glows.dart';
import '../../../../core/theme/app_layout.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../data/models/song_item.dart';
import 'song_thumbnail.dart';

/// Row in the "KẾT QUẢ TÌM KIẾM" column.
///
/// The row itself selects and plays the song (matching the "OK - Chọn / Phát
/// bài" remote hint); the trailing "+" is a separate tap target that only
/// adds the song to the queue.
class SearchResultTile extends StatelessWidget {
  const SearchResultTile({
    super.key,
    required this.item,
    required this.selected,
    required this.onPressed,
    required this.onAdd,
    this.onFocused,
  });

  final SongItem item;
  final bool selected;
  final VoidCallback onPressed;
  final VoidCallback onAdd;
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

        return AnimatedContainer(
          duration: const Duration(milliseconds: 140),
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
                seed: item.thumbnailSeed,
                width: 104,
                height: 62,
                imageUrl: item.imageUrl,
                durationLabel: item.duration,
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
                    const SizedBox(height: 3),
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
              InkWell(
                onTap: onAdd,
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
                        Icons.add,
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
