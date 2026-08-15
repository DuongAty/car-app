import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/shared/widgets/collapsible_axis.dart';
import '../../../../core/shared/widgets/karaoke_shell.dart';
import '../../../../core/shared/widgets/surface_scope.dart';
import '../../../../core/theme/app_layout.dart';
import '../../../playback/presentation/providers/now_playing_controller.dart';
import '../../../navigation/presentation/widgets/main_nav_rail.dart';
import '../../../song_browser/presentation/widgets/preview_player.dart';
import '../widgets/selected_queue_panel.dart';

/// Lists every song added from a search result's "+" across all three
/// sources, and lets the user reorder, replay, remove, or clear the queue.
/// Reached from the "ĐÃ CHỌN" tab on the song browser.
class SelectedQueuePage extends ConsumerWidget {
  const SelectedQueuePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Shared with the song browser: expanding the video here (or having left
    // it expanded there) collapses this list the same way.
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
        navRail: const MainNavRail(
          selectedId: NavDestination.queue,
          hasStagePlayer: true,
        ),
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
                  // Anchored to the far edge so the panel slides out of frame
                  // (matching the song browser's side panels) rather than
                  // being trimmed in place.
                  alignment: Alignment.topRight,
                  // Keep the hairline inside the collapsible region, so it
                  // closes with the queue column.
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(
                        width: AppLayout.browserRightPanelWidth,
                        child: SelectedQueuePanel(),
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
            // collapsed queue column is still mounted underneath (so its
            // state survives an instant return to normal), so it still
            // needs the bare scope — without it, its panel would paint its
            // own bare surface with no slab there to replace it.
            return mode == PlayerViewMode.fullscreen
                ? SurfaceScope(child: row)
                : ContentSlab(child: row);
          },
        ),
      ),
    );
  }
}
