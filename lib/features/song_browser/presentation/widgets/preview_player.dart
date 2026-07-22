import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';

import '../../../../core/shared/widgets/circle_icon_button.dart';
import '../../../../core/shared/widgets/liquid_glass.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_layout.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../l10n/l10n.dart';
import '../../../playback/presentation/providers/now_playing_controller.dart';
import '../../../queue/presentation/providers/queue_playback_controller.dart';
import '../../../source_selection/presentation/widgets/source_badge.dart';
import 'stage_backdrop.dart';

/// Now-playing preview: real video playback above a transport strip.
///
/// Reads [nowPlayingProvider] rather than owning a [VideoPlayerController]
/// itself. That state (and the controller) is shared app-wide, so the exact
/// same instance of this widget on the browser page and the queue page shows
/// the same video mid-playback instead of restarting it — navigating between
/// them must not interrupt what's already playing, only picking a different
/// song does.
class PreviewPlayer extends ConsumerWidget {
  const PreviewPlayer({super.key});

  String _formatDuration(Duration duration) {
    final totalSeconds = duration.inSeconds;
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = ref.watch(nowPlayingProvider);
    final notifier = ref.read(nowPlayingProvider.notifier);
    final queuePlayback = ref.read(queuePlaybackControllerProvider.notifier);
    final controller = now.videoController;
    final displayController = now.visualizerController ?? controller;
    final hasAudioPlayer = now.audioPlayer != null;
    final videoReady = controller != null && controller.value.isInitialized;
    final audioReady = videoReady || hasAudioPlayer;
    final displayReady =
        displayController != null && displayController.value.isInitialized;
    final position = videoReady ? controller.value.position : now.audioPosition;
    final duration = videoReady ? controller.value.duration : now.audioDuration;
    final progress = audioReady && duration.inMilliseconds > 0
        ? position.inMilliseconds / duration.inMilliseconds
        : 0.0;

    return LiquidGlass(
      radius: AppRadius.md,
      opacity: 0.5,
      padding: const EdgeInsets.all(1),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.md - 1),
        child: Column(
          children: [
            Expanded(
              // Only the picture toggles on double tap. The transport strip
              // below is excluded so double-tapping a control cannot resize
              // the screen out from under the user.
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onDoubleTap: notifier.toggleExpanded,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (displayReady)
                      // Letterboxed rather than BoxFit.cover: a cropped video
                      // would clip the burned-in karaoke lyrics baked into the
                      // source video's own frame.
                      ColoredBox(
                        color: Colors.black,
                        child: Center(
                          child: AspectRatio(
                            aspectRatio: displayController.value.aspectRatio,
                            child: VideoPlayer(displayController),
                          ),
                        ),
                      )
                    else
                      const StageBackdrop(),
                    Positioned(
                      top: AppSpacing.md,
                      right: AppSpacing.md,
                      child: SourceBadge(source: now.activeSource),
                    ),
                    _PlaybackStatusOverlay(
                      playback: now.playback,
                      hasController: displayReady || hasAudioPlayer,
                    ),
                  ],
                ),
              ),
            ),
            _TransportStrip(
              elapsedLabel: _formatDuration(position),
              durationLabel: _formatDuration(duration),
              progress: progress,
              isPlaying: videoReady
                  ? controller.value.isPlaying
                  : now.audioIsPlaying,
              onPlayPause: notifier.togglePlayPause,
              onPrevious: queuePlayback.playPrevious,
              onNext: queuePlayback.playNext,
              isExpanded: now.isExpanded,
              onToggleExpanded: notifier.toggleExpanded,
            ),
          ],
        ),
      ),
    );
  }
}

/// Centered status chip shown while a song is loading, failed to resolve, or
/// none has been selected yet. Hidden once a frame is actually on screen.
class _PlaybackStatusOverlay extends StatelessWidget {
  const _PlaybackStatusOverlay({
    required this.playback,
    required this.hasController,
  });

  final PlaybackState playback;
  final bool hasController;

  @override
  Widget build(BuildContext context) {
    if (hasController) {
      return const SizedBox.shrink();
    }

    final l10n = context.l10n;

    return Center(
      child: switch (playback) {
        PlaybackIdle() => _StatusChip(
          icon: Icons.queue_music_rounded,
          label: l10n.playbackIdlePrompt,
        ),
        PlaybackLoading() => _StatusChip(
          spinner: true,
          label: l10n.playbackLoading,
        ),
        PlaybackFailed() => _StatusChip(
          icon: Icons.error_outline_rounded,
          label: l10n.playbackFailed,
        ),
        // A ready state with no controller yet means the player is still
        // initializing on the first frame after resolving the link.
        PlaybackReady() => _StatusChip(
          spinner: true,
          label: l10n.playbackLoading,
        ),
      },
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({this.icon, required this.label, this.spinner = false});

  final IconData? icon;
  final String label;
  final bool spinner;

  @override
  Widget build(BuildContext context) {
    return LiquidGlass(
      radius: AppRadius.lg,
      opacity: 0.55,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (spinner)
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.green,
              ),
            )
          else if (icon != null)
            Icon(icon, color: AppColors.textPrimary, size: 22),
          const SizedBox(width: AppSpacing.sm),
          Text(label, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}

class _TransportStrip extends StatelessWidget {
  const _TransportStrip({
    required this.elapsedLabel,
    required this.durationLabel,
    required this.progress,
    required this.isPlaying,
    required this.onPlayPause,
    required this.onPrevious,
    required this.onNext,
    required this.isExpanded,
    required this.onToggleExpanded,
  });

  final String elapsedLabel;
  final String durationLabel;
  final double progress;
  final bool isPlaying;
  final VoidCallback onPlayPause;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final bool isExpanded;
  final VoidCallback onToggleExpanded;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      height: AppLayout.browserPreviewControlsHeight,
      color: AppColors.background.withValues(alpha: 0.55),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Text(elapsedLabel, style: textTheme.labelLarge),
              const SizedBox(width: AppSpacing.md),
              Expanded(child: _ProgressTrack(progress: progress)),
              const SizedBox(width: AppSpacing.md),
              Text(durationLabel, style: textTheme.labelLarge),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _TransportButton(
                icon: Icons.skip_previous_rounded,
                onPressed: onPrevious,
              ),
              const SizedBox(width: AppSpacing.md),
              _TransportButton(
                icon: Icons.fast_rewind_rounded,
                onPressed: onPlayPause,
              ),
              const SizedBox(width: AppSpacing.md),
              CircleIconButton(
                icon: isPlaying
                    ? Icons.pause_rounded
                    : Icons.play_arrow_rounded,
                onPressed: onPlayPause,
                size: 52,
                iconSize: 26,
                tint: AppColors.greenDeep,
              ),
              const SizedBox(width: AppSpacing.md),
              _TransportButton(
                icon: Icons.skip_next_rounded,
                onPressed: onNext,
              ),
              const SizedBox(width: AppSpacing.md),
              _TransportButton(
                icon: Icons.settings_outlined,
                onPressed: onPlayPause,
              ),
              const SizedBox(width: AppSpacing.md),
              _TransportButton(
                icon: isExpanded
                    ? Icons.fullscreen_exit_rounded
                    : Icons.fullscreen_rounded,
                onPressed: onToggleExpanded,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TransportButton extends StatelessWidget {
  const _TransportButton({required this.icon, required this.onPressed});

  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return CircleIconButton(
      icon: icon,
      onPressed: onPressed,
      size: 46,
      iconSize: 24,
    );
  }
}

class _ProgressTrack extends StatelessWidget {
  const _ProgressTrack({required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) {
    final ratio = progress.clamp(0.0, 1.0);

    return LayoutBuilder(
      builder: (context, constraints) {
        final filled = constraints.maxWidth * ratio;

        return SizedBox(
          height: 14,
          child: Stack(
            alignment: Alignment.centerLeft,
            children: [
              Container(
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.keyFill,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
              ),
              Container(
                height: 4,
                width: filled,
                decoration: BoxDecoration(
                  color: AppColors.green,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
              ),
              Positioned(
                left: (filled - 7).clamp(0.0, constraints.maxWidth - 14),
                child: Container(
                  width: 14,
                  height: 14,
                  decoration: const BoxDecoration(
                    color: AppColors.green,
                    shape: BoxShape.circle,
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
