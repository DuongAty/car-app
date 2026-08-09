import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/models/bottom_hint_item.dart';
import '../../../../core/providers/volume_provider.dart';
import '../../../../core/shared/widgets/app_bottom_hint_bar.dart';
import '../../../../core/shared/widgets/volume_indicator.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_icons.dart';
import '../../../../l10n/l10n.dart';
import '../../../../routes/app_router.dart';
import '../../../queue/presentation/providers/queue_provider.dart';
import '../../../source_selection/data/mock/source_selection_mock_data.dart';
import '../../../source_selection/data/models/music_source.dart';
import '../providers/now_playing_controller.dart';
import 'bottom_mini_player.dart';

/// The single, app-wide bottom control bar.
///
/// Every page uses this instead of composing its own [AppBottomHintBar], so the
/// remote-control legend (volume + navigate/OK/queue/favorites/back) is
/// identical and pinned on every screen. When a song is playing on a page that
/// has no large stage player of its own, the [BottomMiniPlayer] drops into the
/// bar's centre slot so the now-playing transport is always reachable.
class AppControlBar extends ConsumerWidget {
  const AppControlBar({
    super.key,
    this.hasStagePlayer = false,
    this.onQueue,
    this.onFavorites,
    this.onMiniPlayerTap,
  });

  /// Whether this page already shows a full [PreviewPlayer] stage in its body.
  /// Stage pages never need the mini-player; stage-less pages (home, settings)
  /// surface it in the bar whenever something is playing.
  final bool hasStagePlayer;

  /// Optional overrides for the queue / favorites hints. When null the bar
  /// navigates to the matching route (skipping the push if already there) —
  /// pages with bespoke behaviour (e.g. the browser's slide-in queue drawer)
  /// pass their own handler.
  final VoidCallback? onQueue;
  final VoidCallback? onFavorites;
  final VoidCallback? onMiniPlayerTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final volume = ref.watch(volumeProvider);
    final queueCount = ref.watch(
      queueProvider.select((state) => state.items.length),
    );
    final isPlaying = ref.watch(
      nowPlayingProvider.select((state) => state.playback is! PlaybackIdle),
    );
    final activeSource = ref.watch(
      nowPlayingProvider.select((state) => state.activeSource),
    );
    final showMiniPlayer = !hasStagePlayer && isPlaying;

    return AppBottomHintBar(
      leading: VolumeIndicator(
        level: volume.level,
        enabled: volume.isAvailable,
        onChanged: ref.read(volumeProvider.notifier).setLevel,
      ),
      items: [
        BottomHintItem(
          id: 'navigate',
          badgeIcon: AppIcons.menu,
          label: l10n.hintNavigate,
        ),
        BottomHintItem(
          id: 'play',
          badgeText: 'OK',
          label: l10n.hintChooseAndPlay,
          accentColor: AppColors.greenDeep,
        ),
      ],
      trailingItems: [
        BottomHintItem(
          id: 'queue',
          badgeIcon: AppIcons.selectedQueue,
          label: l10n.hintSelectedQueue(queueCount),
          accentColor: AppColors.yellow,
        ),
        BottomHintItem(
          id: 'favorites',
          badgeIcon: AppIcons.favorite,
          label: l10n.hintFavorites,
          accentColor: AppColors.blue,
        ),
        BottomHintItem(
          id: 'back',
          badgeIcon: AppIcons.back,
          label: l10n.hintBack,
        ),
      ],
      center: showMiniPlayer
          ? BottomMiniPlayer(
              onTap:
                  onMiniPlayerTap ??
                  () => _openSongBrowserFromMiniPlayer(context, activeSource),
            )
          : null,
      compactLabels: showMiniPlayer,
      onItemTap: (item) => _handle(context, item),
    );
  }

  void _handle(BuildContext context, BottomHintItem item) {
    switch (item.id) {
      case 'queue':
        if (onQueue != null) {
          onQueue!();
        } else {
          _pushIfAbsent(context, AppRouter.selectedQueue);
        }
      case 'favorites':
        if (onFavorites != null) {
          onFavorites!();
        } else {
          _pushIfAbsent(context, AppRouter.favorites);
        }
      case 'back':
        Navigator.of(context).maybePop();
    }
  }

  void _pushIfAbsent(BuildContext context, String route) {
    if (ModalRoute.of(context)?.settings.name == route) return;
    Navigator.of(context).pushNamed(route);
  }

  void _openSongBrowserFromMiniPlayer(
    BuildContext context,
    MusicSourceLogoStyle sourceStyle,
  ) {
    final navigator = Navigator.of(context);
    var foundSongBrowser = false;

    navigator.popUntil((route) {
      if (route.settings.name == AppRouter.songBrowser) {
        foundSongBrowser = true;
        return true;
      }
      return route.isFirst;
    });

    if (foundSongBrowser) {
      return;
    }

    final sources = SourceSelectionMockData.localizedSources(context.l10n);
    final source = sources.firstWhere(
      (source) => source.logoStyle == sourceStyle,
      orElse: () => sources.first,
    );
    navigator.pushNamed(AppRouter.songBrowser, arguments: source);
  }
}
