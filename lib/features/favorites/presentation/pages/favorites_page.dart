import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/shared/widgets/collapsible_axis.dart';
import '../../../../core/shared/widgets/karaoke_shell.dart';
import '../../../../core/shared/widgets/panel_frame.dart';
import '../../../../core/shared/widgets/persisted_song_tile.dart';
import '../../../../core/shared/widgets/surface_scope.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_icons.dart';
import '../../../../core/theme/app_layout.dart';
import '../../../../l10n/l10n.dart';
import '../../../playback/presentation/providers/now_playing_controller.dart';
import '../../../playback/presentation/widgets/app_control_bar.dart';
import '../../../song_browser/presentation/widgets/main_top_bar.dart';
import '../../../song_browser/presentation/widgets/preview_player.dart';
import '../providers/favorites_controller.dart';

/// Songs marked ♥ from the song browser. Reached from the "D / Yêu thích"
/// bottom hint, same shell family as [SelectedQueuePage].
class FavoritesPage extends ConsumerWidget {
  const FavoritesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final favorites = ref.watch(favoritesControllerProvider);
    final favoritesController = ref.read(favoritesControllerProvider.notifier);
    final nowPlaying = ref.read(nowPlayingProvider.notifier);
    final mode = ref.watch(nowPlayingProvider.select((value) => value.mode));

    return PopScope(
      // Back must leave fullscreen rather than the screen. Without this the
      // user's only way out is a button that auto-hides.
      canPop: mode != PlayerViewMode.fullscreen,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          ref.read(nowPlayingProvider.notifier).exitFullscreen();
        }
      },
      child: KaraokeShell(
        chromeVisible: mode != PlayerViewMode.fullscreen,
        topBar: MainTopBar(selectedIndex: null),
        body: Builder(
          builder: (context) {
            final Widget row = Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                CollapsibleAxis(
                  axis: Axis.horizontal,
                  // +1 for the hairline that replaced the gap.
                  extent: AppLayout.browserRightPanelWidth + 1,
                  collapsed: mode != PlayerViewMode.normal,
                  alignment: Alignment.topRight,
                  // Keep the hairline inside the collapsible region, so it
                  // closes with the favorites column.
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(
                        width: AppLayout.browserRightPanelWidth,
                        child: PanelFrame(
                          title: l10n.hintFavorites,
                          leadingIcon: AppIcons.favorite,
                          leadingIconColor: AppColors.red,
                          trailingText: l10n.queueItemCount(favorites.length),
                          child: favorites.isEmpty
                              ? Center(
                                  child: Text(
                                    l10n.favoritesEmpty,
                                    textAlign: TextAlign.center,
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodyMedium,
                                  ),
                                )
                              : ListView.separated(
                                  padding: EdgeInsets.zero,
                                  scrollCacheExtent:
                                      const ScrollCacheExtent.pixels(140),
                                  physics: const ClampingScrollPhysics(),
                                  itemCount: favorites.length,
                                  separatorBuilder: (_, _) => Container(
                                    height: 1,
                                    color: AppColors.panelBorderSoft,
                                  ),
                                  itemBuilder: (context, index) {
                                    final entry = favorites[index];
                                    return PersistedSongTile(
                                      entry: entry,
                                      selected: false,
                                      onPressed: () => nowPlaying.play(
                                        entry.song,
                                        entry.source,
                                      ),
                                      onRemove: () => favoritesController
                                          .remove(entry.song.id),
                                    );
                                  },
                                ),
                        ),
                      ),
                      // Built only in normal mode: collapsed still mounts
                      // this child (state is kept alive for an instant
                      // re-expand), so the divider must be conditional
                      // itself or it would keep painting — clipped to
                      // nothing, but still in the tree — down the player's
                      // left edge.
                      if (mode == PlayerViewMode.normal)
                        const SurfaceDivider(axis: Axis.vertical),
                    ],
                  ),
                ),
                const Expanded(child: PreviewPlayer()),
              ],
            );

            // No slab in fullscreen: the player is deliberately full-bleed
            // there, and a slab would put the rounded frame back. The
            // collapsed favorites column is still mounted underneath (so
            // its state survives an instant return to normal), so it still
            // needs the bare scope — without it, its panel would paint its
            // own bare surface with no slab there to replace it.
            return mode == PlayerViewMode.fullscreen
                ? SurfaceScope(child: row)
                : ContentSlab(child: row);
          },
        ),
        bottomBar: const AppControlBar(hasStagePlayer: true),
      ),
    );
  }
}
