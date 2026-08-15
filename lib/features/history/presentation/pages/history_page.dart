import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/shared/widgets/collapsible_axis.dart';
import '../../../../core/shared/widgets/karaoke_shell.dart';
import '../../../../core/shared/widgets/panel_frame.dart';
import '../../../../core/shared/widgets/persisted_song_tile.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_icons.dart';
import '../../../../core/theme/app_layout.dart';
import '../../../../l10n/l10n.dart';
import '../../../playback/presentation/providers/now_playing_controller.dart';
import '../../../navigation/presentation/widgets/main_nav_rail.dart';
import '../../../song_browser/presentation/widgets/preview_player.dart';
import '../providers/history_controller.dart';
import '../relative_time.dart';

/// Songs played this install, most recent first. Reached from Settings.
class HistoryPage extends ConsumerWidget {
  const HistoryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final history = ref.watch(historyControllerProvider);
    final historyController = ref.read(historyControllerProvider.notifier);
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
        navRail: const MainNavRail(hasStagePlayer: true),
        body: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            CollapsibleAxis(
              axis: Axis.horizontal,
              extent:
                  AppLayout.browserRightPanelWidth + AppLayout.browserColumnGap,
              collapsed: mode != PlayerViewMode.normal,
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.only(
                  right: AppLayout.browserColumnGap,
                ),
                child: PanelFrame(
                  title: l10n.historyTitle,
                  leadingIcon: AppIcons.history,
                  leadingIconColor: AppColors.purple,
                  trailingText: l10n.queueItemCount(history.length),
                  child: history.isEmpty
                      ? Center(
                          child: Text(
                            l10n.historyEmpty,
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        )
                      : ListView.separated(
                          padding: EdgeInsets.zero,
                          scrollCacheExtent: const ScrollCacheExtent.pixels(
                            140,
                          ),
                          physics: const ClampingScrollPhysics(),
                          itemCount: history.length,
                          separatorBuilder: (_, _) => Container(
                            height: 1,
                            color: AppColors.panelBorderSoft,
                          ),
                          itemBuilder: (context, index) {
                            final entry = history[index];
                            return PersistedSongTile(
                              entry: entry,
                              selected: false,
                              metaLabel: formatRelativeTime(l10n, entry.at),
                              onPressed: () =>
                                  nowPlaying.play(entry.song, entry.source),
                              onRemove: () =>
                                  historyController.remove(entry.song.id),
                            );
                          },
                        ),
                ),
              ),
            ),
            const Expanded(child: PreviewPlayer()),
          ],
        ),
      ),
    );
  }
}
