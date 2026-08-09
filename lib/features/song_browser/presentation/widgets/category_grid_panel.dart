import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../../../../core/shared/widgets/focusable_tile.dart';
import '../../../../core/shared/widgets/liquid_glass.dart';
import '../../../../core/shared/widgets/panel_frame.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_glows.dart';
import '../../../../core/theme/app_icons.dart';
import '../../../../core/theme/app_motion.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../l10n/l10n.dart';
import '../../../source_selection/data/models/music_source.dart';
import '../../data/song_categories.dart';
import '../providers/song_browser_provider.dart';

/// Full browse surface for the "DANH MỤC" top tab.
///
/// This intentionally does not embed [PreviewPlayer]. Picking a genre or artist
/// runs a search and shows matching songs in the adjacent results panel.
class CategoryGridPanel extends StatelessWidget {
  const CategoryGridPanel({
    super.key,
    required this.source,
    required this.browseTab,
    required this.artistRegion,
    required this.selectedCategoryIndex,
    required this.selectedArtistIndex,
    required this.onBrowseTabSelected,
    required this.onArtistRegionSelected,
    required this.onCategorySelected,
    required this.onCategoryFocused,
    required this.onArtistSelected,
    required this.onArtistFocused,
  });

  final MusicSourceLogoStyle source;
  final BrowseTab browseTab;
  final ArtistRegion artistRegion;
  final int selectedCategoryIndex;
  final int selectedArtistIndex;
  final ValueChanged<BrowseTab> onBrowseTabSelected;
  final ValueChanged<ArtistRegion> onArtistRegionSelected;
  final ValueChanged<int> onCategorySelected;
  final ValueChanged<int> onCategoryFocused;
  final ValueChanged<int> onArtistSelected;
  final ValueChanged<int> onArtistFocused;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final categories = songCategoriesFor(l10n, source);
    final artists = switch (artistRegion) {
      ArtistRegion.vietnam => vietnameseArtists(),
      ArtistRegion.international => internationalArtists(),
    };
    final itemsCount = browseTab == BrowseTab.genres
        ? categories.length
        : artists.length;

    return PanelFrame(
      title: l10n.panelCategories,
      leadingIcon: AppIcons.categoryGrid,
      child: Column(
        children: [
          _SegmentedTabs<BrowseTab>(
            values: const [BrowseTab.genres, BrowseTab.artists],
            selected: browseTab,
            labels: {
              BrowseTab.genres: l10n.browseGenres,
              BrowseTab.artists: l10n.browseArtists,
            },
            onSelected: onBrowseTabSelected,
          ),
          if (browseTab == BrowseTab.artists) ...[
            const SizedBox(height: AppSpacing.sm),
            _SegmentedTabs<ArtistRegion>(
              values: const [ArtistRegion.vietnam, ArtistRegion.international],
              selected: artistRegion,
              labels: {
                ArtistRegion.vietnam: l10n.artistVietnam,
                ArtistRegion.international: l10n.artistInternational,
              },
              onSelected: onArtistRegionSelected,
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          Expanded(
            child: GridView.builder(
              padding: EdgeInsets.zero,
              scrollCacheExtent: const ScrollCacheExtent.pixels(160),
              physics: const ClampingScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 280,
                mainAxisExtent: 142,
                crossAxisSpacing: AppSpacing.sm,
                mainAxisSpacing: AppSpacing.sm,
              ),
              itemCount: itemsCount,
              itemBuilder: (context, index) {
                if (browseTab == BrowseTab.genres) {
                  final category = categories[index];
                  return _BrowseTile(
                    label: category.label,
                    subtitle: category.subtitle,
                    imageAsset: category.imageAsset,
                    selected: index == selectedCategoryIndex,
                    onPressed: () => onCategorySelected(index),
                    onFocused: () => onCategoryFocused(index),
                  );
                }

                final artist = artists[index];
                return _BrowseTile(
                  label: artist.name,
                  subtitle: artist.subtitle,
                  imageAsset: artist.imageAsset,
                  selected: index == selectedArtistIndex,
                  onPressed: () => onArtistSelected(index),
                  onFocused: () => onArtistFocused(index),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _SegmentedTabs<T> extends StatelessWidget {
  const _SegmentedTabs({
    required this.values,
    required this.selected,
    required this.labels,
    required this.onSelected,
  });

  final List<T> values;
  final T selected;
  final Map<T, String> labels;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    return LiquidGlass(
      radius: AppRadius.sm,
      detail: LiquidGlassDetail.simple,
      opacity: 0.38,
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          for (final value in values)
            Expanded(
              child: _SegmentButton(
                label: labels[value]!,
                selected: value == selected,
                onPressed: () => onSelected(value),
              ),
            ),
        ],
      ),
    );
  }
}

class _SegmentButton extends StatelessWidget {
  const _SegmentButton({
    required this.label,
    required this.selected,
    required this.onPressed,
  });

  final String label;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return FocusableTile(
      onPressed: onPressed,
      builder: (context, focused) {
        final active = selected || focused;
        return AnimatedContainer(
          duration: AppMotion.focus,
          height: 38,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: active
                ? AppColors.green.withValues(alpha: 0.2)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadius.xs),
            border: Border.all(
              color: active ? AppColors.green : Colors.transparent,
              width: 1.2,
            ),
          ),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: active ? AppColors.textPrimary : AppColors.textSecondary,
            ),
          ),
        );
      },
    );
  }
}

class _BrowseTile extends StatelessWidget {
  const _BrowseTile({
    required this.label,
    required this.subtitle,
    required this.imageAsset,
    required this.selected,
    required this.onPressed,
    required this.onFocused,
  });

  final String label;
  final String subtitle;
  final String imageAsset;
  final bool selected;
  final VoidCallback onPressed;
  final VoidCallback onFocused;

  @override
  Widget build(BuildContext context) {
    final pixelRatio = MediaQuery.devicePixelRatioOf(context);
    final imageCacheWidth = (280 * pixelRatio).ceil().clamp(160, 360).toInt();
    final imageCacheHeight = (142 * pixelRatio).ceil().clamp(90, 220).toInt();

    return FocusableTile(
      onPressed: onPressed,
      onFocusChange: (focused) {
        if (focused) {
          onFocused();
        }
      },
      builder: (context, focused) {
        final active = selected || focused;
        return AnimatedContainer(
          duration: AppMotion.focus,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.sm),
            border: Border.all(
              color: active ? AppColors.green : AppColors.glassBorder,
              width: active ? 1.5 : 1,
            ),
            boxShadow: AppGlows.control(AppColors.green, focused: active),
          ),
          // Isolate the decoded image + overlay so the 140ms focus border/glow
          // tween doesn't re-rasterize the image blit every frame.
          child: RepaintBoundary(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.sm - 1),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.asset(
                    imageAsset,
                    fit: BoxFit.cover,
                    cacheWidth: imageCacheWidth,
                    cacheHeight: imageCacheHeight,
                    filterQuality: FilterQuality.low,
                  ),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.12),
                          Colors.black.withValues(alpha: 0.82),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    left: AppSpacing.sm,
                    right: AppSpacing.sm,
                    bottom: AppSpacing.sm,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(bottom: 2),
                          child: Icon(
                            AppIcons.chevronRight,
                            size: 20,
                            color: active
                                ? AppColors.green
                                : AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        Expanded(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.titleSmall
                                    ?.copyWith(
                                      color: AppColors.textPrimary,
                                      fontWeight: FontWeight.w800,
                                    ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                subtitle,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.labelSmall
                                    ?.copyWith(
                                      color: AppColors.textSecondary,
                                      height: 1.15,
                                    ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
