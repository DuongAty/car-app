import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/shared/widgets/circle_icon_button.dart';
import '../../../../core/shared/widgets/panel_frame.dart';
import '../../../../core/theme/app_colors.dart';
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
    final queue = ref.watch(queueProvider);
    final selectedIndex = ref.watch(selectedQueueControllerProvider);
    final controller = ref.read(selectedQueueControllerProvider.notifier);
    final playbackController = ref.read(
      queuePlaybackControllerProvider.notifier,
    );

    void play(int index) {
      controller.selectIndex(index);
      playbackController.playAt(index);
    }

    return PanelFrame(
      title: l10n.songSelected,
      leadingIcon: Icons.playlist_add_check_rounded,
      trailingText: l10n.queueItemCount(queue.length),
      opacity: onClose == null ? 0.52 : 0.88,
      trailing: onClose == null
          ? null
          : CircleIconButton(
              icon: Icons.close_rounded,
              onPressed: onClose!,
              size: 40,
              iconSize: 20,
              opacity: 0.38,
            ),
      child: queue.isEmpty
          ? Center(
              child: Text(
                l10n.queueEmpty,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            )
          : ListView.separated(
              padding: EdgeInsets.zero,
              physics: const BouncingScrollPhysics(),
              itemCount: queue.length,
              separatorBuilder: (_, _) =>
                  Container(height: 1, color: AppColors.panelBorderSoft),
              itemBuilder: (context, index) => QueuedSongTile(
                item: queue[index],
                selected: index == selectedIndex,
                onPressed: () => play(index),
                onFocused: (focused) {
                  if (focused) {
                    controller.selectIndex(index);
                  }
                },
                onRemove: () =>
                    ref.read(queueProvider.notifier).removeAt(index),
                onMoveUp: index > 0
                    ? () => ref.read(queueProvider.notifier).moveUp(index)
                    : null,
                onMoveDown: index < queue.length - 1
                    ? () => ref.read(queueProvider.notifier).moveDown(index)
                    : null,
              ),
            ),
    );
  }
}
