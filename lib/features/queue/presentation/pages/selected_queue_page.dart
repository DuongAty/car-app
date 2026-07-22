import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/models/bottom_hint_item.dart';
import '../../../../core/providers/locale_provider.dart';
import '../../../../core/providers/volume_provider.dart';
import '../../../../core/shared/widgets/app_bottom_hint_bar.dart';
import '../../../../core/shared/widgets/brand_wordmark.dart';
import '../../../../core/shared/widgets/circle_icon_button.dart';
import '../../../../core/shared/widgets/collapsible_axis.dart';
import '../../../../core/shared/widgets/karaoke_shell.dart';
import '../../../../core/shared/widgets/language_toggle.dart';
import '../../../../core/shared/widgets/title_pill.dart';
import '../../../../core/shared/widgets/volume_indicator.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_layout.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../l10n/l10n.dart';
import '../../../playback/presentation/providers/now_playing_controller.dart';
import '../../../song_browser/presentation/widgets/preview_player.dart';
import '../providers/queue_provider.dart';
import '../widgets/selected_queue_panel.dart';

/// Lists every song added from a search result's "+" across all three
/// sources, and lets the user reorder, replay, remove, or clear the queue.
/// Reached from the "ĐÃ CHỌN" tab on the song browser.
class SelectedQueuePage extends ConsumerWidget {
  const SelectedQueuePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final locale = ref.watch(appLocaleProvider);
    final localeController = ref.read(appLocaleProvider.notifier);
    final volume = ref.watch(volumeProvider);
    // Shared with the song browser: expanding the video here (or having left
    // it expanded there) collapses this list the same way.
    final isExpanded = ref.watch(
      nowPlayingProvider.select((value) => value.isExpanded),
    );

    return KaraokeShell(
      topBar: SizedBox(
        height: AppLayout.topNavItemHeight,
        child: Row(
          children: [
            const BrandWordmark(fontSize: 34),
            const SizedBox(width: AppSpacing.sm),
            TitlePill(label: l10n.songSelected, color: AppColors.yellow),
            const Spacer(),
            LanguageToggle(
              isVietnamese: locale.languageCode == 'vi',
              onToggle: localeController.toggle,
              compact: true,
            ),
            const SizedBox(width: AppSpacing.sm),
            CircleIconButton(
              icon: Icons.language,
              onPressed: localeController.toggle,
            ),
          ],
        ),
      ),
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CollapsibleAxis(
            axis: Axis.horizontal,
            extent:
                AppLayout.browserRightPanelWidth + AppLayout.browserColumnGap,
            collapsed: isExpanded,
            // Anchored to the far edge so the panel slides out of frame
            // (matching the song browser's side panels) rather than being
            // trimmed in place.
            alignment: Alignment.topRight,
            child: Padding(
              padding: const EdgeInsets.only(right: AppLayout.browserColumnGap),
              child: const SelectedQueuePanel(),
            ),
          ),
          const Expanded(child: PreviewPlayer()),
        ],
      ),
      bottomBar: AppBottomHintBar(
        leading: VolumeIndicator(
          level: volume.level,
          enabled: volume.isAvailable,
          onChanged: ref.read(volumeProvider.notifier).setLevel,
        ),
        items: const [],
        trailingItems: [
          BottomHintItem(
            id: 'play',
            badgeText: 'OK',
            label: l10n.hintChooseAndPlay,
            accentColor: AppColors.greenDeep,
          ),
          BottomHintItem(
            id: 'clear',
            badgeText: 'C',
            label: l10n.hintClearQueue,
            accentColor: AppColors.yellow,
          ),
          BottomHintItem(
            id: 'back',
            badgeIcon: Icons.undo_rounded,
            label: l10n.hintBack,
          ),
        ],
        onItemTap: (item) => _handleHint(context, ref, item),
      ),
    );
  }

  void _handleHint(BuildContext context, WidgetRef ref, BottomHintItem item) {
    switch (item.id) {
      case 'back':
        Navigator.of(context).maybePop();
      case 'clear':
        ref.read(queueProvider.notifier).clear();
    }
  }
}
