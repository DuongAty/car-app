import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/shared/widgets/circle_icon_button.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_icons.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../queue/presentation/providers/queue_playback_controller.dart';
import '../providers/now_playing_controller.dart';

class BottomMiniPlayer extends ConsumerWidget {
  const BottomMiniPlayer({super.key, this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final queuePlayback = ref.read(queuePlaybackControllerProvider.notifier);
    // Only the now-playing title needs the coarse playback slice; it does not
    // change on the per-second tick. The play/pause icon and progress fill are
    // isolated in leaf Consumers so this bar does not re-lay-out its whole Row
    // once a second on otherwise-static pages.
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

    return Row(
      children: [
        _MiniTransportButton(
          icon: AppIcons.previous,
          onPressed: queuePlayback.playPrevious,
        ),
        const SizedBox(width: AppSpacing.sm),
        const _MiniPlayPauseButton(),
        const SizedBox(width: AppSpacing.sm),
        _MiniTransportButton(
          icon: AppIcons.next,
          onPressed: queuePlayback.playNext,
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(AppRadius.sm),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    songTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  const _MiniProgressTrack(),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Play/pause icon isolated so the tick rebuilds only this button.
class _MiniPlayPauseButton extends ConsumerWidget {
  const _MiniPlayPauseButton();

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
      size: 38,
      iconSize: 24,
      tint: AppColors.greenDeep,
    );
  }
}

class _MiniTransportButton extends StatelessWidget {
  const _MiniTransportButton({required this.icon, required this.onPressed});

  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return CircleIconButton(
      icon: icon,
      onPressed: onPressed,
      size: 34,
      iconSize: 22,
      opacity: 0.38,
    );
  }
}

/// Progress fill for the mini player. A leaf Consumer so the once-per-second
/// position update rebuilds only this 3px bar, not the buttons or title.
class _MiniProgressTrack extends ConsumerWidget {
  const _MiniProgressTrack();

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
          height: 8,
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
