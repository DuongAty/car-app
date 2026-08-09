import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/shared/widgets/circle_icon_button.dart';
import '../../../../core/shared/widgets/liquid_glass.dart';
import '../../../../core/shared/widgets/neon_empty_state.dart';
import '../../../../core/shared/widgets/panel_frame.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_icons.dart';
import '../../../../core/theme/app_layout.dart';
import '../../../../core/theme/app_motion.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../l10n/l10n.dart';
import '../providers/queue_playback_controller.dart';
import '../providers/queue_provider.dart';
import '../providers/selected_queue_controller.dart';
import 'queued_song_tile.dart';

class SelectedQueuePanel extends ConsumerWidget {
  const SelectedQueuePanel({super.key, this.onClose});

  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final queue = ref.watch(queueProvider.select((state) => state.items));
    final repeatMode = ref.watch(
      queueProvider.select((state) => state.repeatMode),
    );
    final shuffle = ref.watch(queueProvider.select((state) => state.shuffle));
    final queueController = ref.read(queueProvider.notifier);
    // Selection is not watched at panel scope: each row watches only whether it
    // is the selected one via `.select` below, so moving the D-pad rebuilds
    // just the row losing and the row gaining selection, not every visible tile.
    final controller = ref.read(selectedQueueControllerProvider.notifier);
    final playbackController = ref.read(
      queuePlaybackControllerProvider.notifier,
    );
    final mediaQuery = MediaQuery.of(context);
    final safeWidth =
        mediaQuery.size.width -
        mediaQuery.padding.left -
        mediaQuery.padding.right;
    final safeHeight =
        mediaQuery.size.height -
        mediaQuery.padding.top -
        mediaQuery.padding.bottom;
    final designScale = math.min(
      safeWidth / AppLayout.designWidth,
      safeHeight / AppLayout.designHeight,
    );

    void play(int index) {
      controller.selectIndex(index);
      playbackController.playAt(index);
    }

    return PanelFrame(
      title: l10n.songSelected,
      leadingIcon: AppIcons.selectedQueue,
      trailingText: l10n.queueItemCount(queue.length),
      opacity: onClose == null ? 0.52 : 0.88,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _RepeatButton(
            mode: repeatMode,
            onPressed: queueController.cycleQueueRepeatMode,
          ),
          const SizedBox(width: AppSpacing.xs),
          _ShuffleButton(
            active: shuffle,
            onPressed: queueController.toggleShuffle,
          ),
          if (queue.isNotEmpty) ...[
            const SizedBox(width: AppSpacing.xs),
            Tooltip(
              message: l10n.hintClearQueue,
              child: CircleIconButton(
                icon: AppIcons.clearAll,
                onPressed: queueController.clear,
                size: 40,
                iconSize: 20,
                tint: AppColors.red,
              ),
            ),
          ],
          if (onClose != null) ...[
            const SizedBox(width: AppSpacing.xs),
            CircleIconButton(
              icon: AppIcons.close,
              onPressed: onClose!,
              size: 40,
              iconSize: 20,
              opacity: 0.38,
            ),
          ],
        ],
      ),
      child: queue.isEmpty
          ? NeonEmptyState(
              icon: AppIcons.selectedQueue,
              title: l10n.queueEmpty,
              subtitle: l10n.hintSelectedQueue(0),
            )
          : ListView.custom(
              padding: EdgeInsets.zero,
              scrollCacheExtent: const ScrollCacheExtent.pixels(160),
              physics: const ClampingScrollPhysics(),
              childrenDelegate: SliverChildBuilderDelegate((context, index) {
                if (index.isEven) {
                  final slotIndex = index ~/ 2;
                  return _QueueDropSlot(
                    onAccept: (fromIndex) =>
                        queueController.moveToSlot(fromIndex, slotIndex),
                  );
                }

                final itemIndex = index ~/ 2;
                return Consumer(
                  key: ObjectKey(queue[itemIndex]),
                  builder: (context, ref, _) {
                    final selected = ref.watch(
                      selectedQueueControllerProvider.select(
                        (selectedIndex) => selectedIndex == itemIndex,
                      ),
                    );
                    return QueuedSongTile(
                      item: queue[itemIndex],
                      dragHandle: _QueueDragHandle(
                        index: itemIndex,
                        title: queue[itemIndex].song.title,
                        designScale: designScale,
                      ),
                      selected: selected,
                      onPressed: () => play(itemIndex),
                      onFocused: (focused) {
                        if (focused) {
                          controller.selectIndex(itemIndex);
                        }
                      },
                      onRemove: () {
                        final removed = queueController.removeAt(itemIndex);
                        if (removed == null) {
                          return;
                        }
                        ScaffoldMessenger.of(context)
                          ..hideCurrentSnackBar()
                          ..showSnackBar(
                            SnackBar(
                              content: Text(l10n.queueRemoved),
                              duration: const Duration(seconds: 2),
                              behavior: SnackBarBehavior.floating,
                              margin: const EdgeInsets.all(AppSpacing.lg),
                              action: SnackBarAction(
                                label: l10n.undo,
                                onPressed: () => queueController.insertAt(
                                  itemIndex,
                                  removed,
                                ),
                              ),
                            ),
                          );
                      },
                    );
                  },
                );
              }, childCount: queue.length * 2 + 1),
            ),
    );
  }
}

class _QueueDragHandle extends StatelessWidget {
  const _QueueDragHandle({
    required this.index,
    required this.title,
    required this.designScale,
  });

  final int index;
  final String title;
  final double designScale;

  @override
  Widget build(BuildContext context) {
    final handle = SizedBox(
      width: 38,
      height: 58,
      child: LiquidGlass(
        capsule: true,
        detail: LiquidGlassDetail.simple,
        lifted: false,
        opacity: 0.3,
        child: const Center(
          child: Icon(
            AppIcons.dragHandle,
            size: 25,
            color: AppColors.textSecondary,
          ),
        ),
      ),
    );

    return Draggable<int>(
      data: index,
      feedback: Material(
        type: MaterialType.transparency,
        child: Transform.scale(
          scale: designScale * 0.78,
          child: Container(
            width: 320,
            height: 62,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            alignment: Alignment.centerLeft,
            decoration: BoxDecoration(
              color: AppColors.panelStrong,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.green, width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: AppColors.green.withValues(alpha: 0.45),
                  blurRadius: 18,
                ),
              ],
            ),
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
        ),
      ),
      childWhenDragging: Opacity(opacity: 0.35, child: handle),
      child: handle,
    );
  }
}

class _QueueDropSlot extends StatelessWidget {
  const _QueueDropSlot({required this.onAccept});

  final ValueChanged<int> onAccept;

  @override
  Widget build(BuildContext context) {
    return DragTarget<int>(
      onWillAcceptWithDetails: (_) => true,
      onAcceptWithDetails: (details) => onAccept(details.data),
      builder: (context, candidateData, _) {
        final isActive = candidateData.isNotEmpty;
        return AnimatedContainer(
          duration: AppMotion.focus,
          height: isActive ? 28 : 8,
          margin: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(
                color: isActive ? AppColors.green : Colors.transparent,
                width: isActive ? 3 : 0,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _RepeatButton extends StatelessWidget {
  const _RepeatButton({required this.mode, required this.onPressed});

  final QueueRepeatMode mode;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Tooltip(
      message: switch (mode) {
        QueueRepeatMode.off => l10n.queueRepeatOff,
        QueueRepeatMode.all => l10n.queueRepeatAll,
        QueueRepeatMode.one => l10n.queueRepeatOne,
      },
      child: CircleIconButton(
        icon: mode == QueueRepeatMode.one
            ? AppIcons.repeatOne
            : AppIcons.repeat,
        onPressed: onPressed,
        size: 52,
        iconSize: 26,
        tint: mode == QueueRepeatMode.off ? null : AppColors.green,
        color: AppColors.textPrimary,
      ),
    );
  }
}

class _ShuffleButton extends StatelessWidget {
  const _ShuffleButton({required this.active, required this.onPressed});

  final bool active;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: context.l10n.queueShuffle,
      child: CircleIconButton(
        icon: AppIcons.shuffle,
        onPressed: onPressed,
        size: 52,
        iconSize: 26,
        tint: active ? AppColors.green : null,
        color: AppColors.textPrimary,
      ),
    );
  }
}
