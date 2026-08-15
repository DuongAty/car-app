import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/shared/widgets/circle_icon_button.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_icons.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../queue/presentation/providers/queue_playback_controller.dart';
import '../providers/now_playing_controller.dart';

/// Compact now-playing block for the foot of the left navigation rail.
///
/// Stage-less pages (the source picker, settings) used to surface the transport
/// in the bottom bar; with that bar gone it stacks into the rail instead, so
/// whatever is playing stays reachable from every screen.
class RailMiniPlayer extends ConsumerWidget {
  const RailMiniPlayer({super.key, this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final queuePlayback = ref.read(queuePlaybackControllerProvider.notifier);
    // Only the title needs the coarse playback slice; it does not change on the
    // per-second tick. The play/pause icon and the progress fill are isolated in
    // leaf Consumers below so this block does not re-lay-out once a second.
    final playback = ref.watch(nowPlayingProvider.select((s) => s.playback));
    final songTitle = switch (playback) {
      PlaybackReady(:final song) => song.title,
      PlaybackLoading(:final song) => song.title,
      PlaybackFailed(:final song) => song.title,
      PlaybackIdle() => null,
    };

    if (songTitle == null) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xxs,
        vertical: AppSpacing.xxs,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(AppRadius.xs),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
              child: Text(
                songTitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  fontSize: 12,
                  height: 1.25,
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xxs),
          const _RailProgressTrack(),
          const SizedBox(height: AppSpacing.xxs),
          // Scaled down rather than overflowing: the rail is sized to its
          // labels, and three round buttons plus their gaps are wider than the
          // narrowest rail (104) allows.
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _RailTransportButton(
                  icon: AppIcons.previous,
                  onPressed: queuePlayback.playPrevious,
                ),
                const SizedBox(width: AppSpacing.xxs),
                const _RailPlayPauseButton(),
                const SizedBox(width: AppSpacing.xxs),
                _RailTransportButton(
                  icon: AppIcons.next,
                  onPressed: queuePlayback.playNext,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Play/pause icon isolated so the tick rebuilds only this button.
class _RailPlayPauseButton extends ConsumerWidget {
  const _RailPlayPauseButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = ref.watch(nowPlayingProvider);
    final notifier = ref.read(nowPlayingProvider.notifier);
    final controller = now.videoController;
    final videoReady = controller != null && controller.value.isInitialized;
    final isPlaying = videoReady
        ? controller.value.isPlaying
        : now.audioIsPlaying;

    return CircleIconButton(
      icon: isPlaying ? AppIcons.pause : AppIcons.play,
      onPressed: notifier.togglePlayPause,
      size: 34,
      iconSize: 21,
      tint: AppColors.greenDeep,
    );
  }
}

class _RailTransportButton extends StatelessWidget {
  const _RailTransportButton({required this.icon, required this.onPressed});

  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return CircleIconButton(
      icon: icon,
      onPressed: onPressed,
      size: 28,
      iconSize: 17,
      opacity: 0.38,
    );
  }
}

/// Progress fill. A leaf Consumer so the once-per-second position update
/// rebuilds only this 3px bar, not the title or the buttons.
class _RailProgressTrack extends ConsumerWidget {
  const _RailProgressTrack();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = ref.watch(nowPlayingProvider);
    final controller = now.videoController;
    final videoReady = controller != null && controller.value.isInitialized;
    final position = videoReady ? controller.value.position : now.audioPosition;
    final duration = videoReady ? controller.value.duration : now.audioDuration;
    final ratio =
        (duration.inMilliseconds > 0
                ? position.inMilliseconds / duration.inMilliseconds
                : 0.0)
            .clamp(0.0, 1.0);

    return LayoutBuilder(
      builder: (context, constraints) {
        final filled = constraints.maxWidth * ratio;

        return SizedBox(
          height: 6,
          child: Stack(
            alignment: Alignment.centerLeft,
            children: [
              Container(
                height: 3,
                decoration: BoxDecoration(
                  color: AppColors.keyFill.withValues(alpha: 0.82),
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
              ),
              Container(
                height: 3,
                width: filled,
                decoration: BoxDecoration(
                  color: AppColors.green,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.green.withValues(alpha: 0.55),
                      blurRadius: 10,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
