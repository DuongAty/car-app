import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/models/bottom_hint_item.dart';
import '../../../../core/providers/locale_provider.dart';
import '../../../../core/providers/volume_provider.dart';
import '../../../../core/shared/widgets/app_bottom_hint_bar.dart';
import '../../../../core/shared/widgets/app_top_nav.dart';
import '../../../../core/shared/widgets/brand_wordmark.dart';
import '../../../../core/shared/widgets/circle_icon_button.dart';
import '../../../../core/shared/widgets/collapsible_axis.dart';
import '../../../../core/shared/widgets/karaoke_shell.dart';
import '../../../../core/shared/widgets/volume_indicator.dart';
import '../../../../core/shared/widgets/language_toggle.dart';
import '../../../../core/shared/widgets/title_pill.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_layout.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../l10n/l10n.dart';
import '../../../../routes/app_router.dart';
import '../../../playback/presentation/providers/now_playing_controller.dart';
import '../../../queue/presentation/providers/queue_provider.dart';
import '../../../queue/presentation/widgets/selected_queue_panel.dart';
import '../../../source_selection/data/models/music_source.dart';
import '../../data/mock/song_browser_mock_data.dart';
import '../providers/song_browser_provider.dart';
import '../widgets/preview_player.dart';
import '../widgets/search_keyboard_panel.dart';
import '../widgets/search_results_panel.dart';
import '../widgets/suggestions_panel.dart';

class SongBrowserPage extends ConsumerStatefulWidget {
  const SongBrowserPage({super.key, required this.source});

  final MusicSource source;

  @override
  ConsumerState<SongBrowserPage> createState() => _SongBrowserPageState();
}

class _SongBrowserPageState extends ConsumerState<SongBrowserPage> {
  bool _queueDrawerOpen = false;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final state = ref.watch(songBrowserProvider(widget.source));
    final controller = ref.read(songBrowserProvider(widget.source).notifier);
    final locale = ref.watch(appLocaleProvider);
    final localeController = ref.read(appLocaleProvider.notifier);
    final volume = ref.watch(volumeProvider);
    final queueCount = ref.watch(queueProvider).length;
    final isExpanded = ref.watch(
      nowPlayingProvider.select((value) => value.isExpanded),
    );

    return KaraokeShell(
      topBar: SizedBox(
        height: AppLayout.topNavItemHeight,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Row(
              children: [
                const BrandWordmark(fontSize: 34),
                const SizedBox(width: AppSpacing.sm),
                TitlePill(label: l10n.karaokeLabel),
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
            AppTopNav(
              actions: SongBrowserMockData.topActions(l10n, queueCount),
              selectedIndex: state.selectedTopActionIndex,
              onSelected: (index) => _handleTopAction(controller, index),
              spacing: AppSpacing.xl,
            ),
          ],
        ),
      ),
      body: Stack(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // The trailing gap collapses with the panel, otherwise expanding
              // would leave a dead 32px strip behind.
              CollapsibleAxis(
                axis: Axis.horizontal,
                extent:
                    AppLayout.browserLeftPanelWidth +
                    AppLayout.browserColumnGap,
                collapsed: isExpanded,
                // Anchored to the far edge so the panel slides out of frame
                // rather than being trimmed in place.
                alignment: Alignment.topRight,
                child: Padding(
                  padding: const EdgeInsets.only(
                    right: AppLayout.browserColumnGap,
                  ),
                  child: SuggestionsPanel(
                    recommendations: state.recommendations,
                    selectedIndex: state.selectedSuggestionIndex,
                    onSelected: controller.selectSuggestion,
                    onPlay: controller.playSong,
                  ),
                ),
              ),
              Expanded(
                child: Column(
                  children: [
                    const Expanded(child: PreviewPlayer()),
                    CollapsibleAxis(
                      axis: Axis.vertical,
                      extent:
                          AppLayout.browserSectionGap +
                          AppLayout.browserInputPanelHeight,
                      collapsed: isExpanded,
                      // Slides down and out of frame.
                      alignment: Alignment.topLeft,
                      child: Padding(
                        padding: const EdgeInsets.only(
                          top: AppLayout.browserSectionGap,
                        ),
                        child: SearchKeyboardPanel(
                          query: state.query,
                          onKeyPressed: controller.pressKey,
                          onMicTap: () {},
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              CollapsibleAxis(
                axis: Axis.horizontal,
                extent:
                    AppLayout.browserRightPanelWidth +
                    AppLayout.browserColumnGap,
                collapsed: isExpanded,
                alignment: Alignment.topLeft,
                child: Padding(
                  padding: const EdgeInsets.only(
                    left: AppLayout.browserColumnGap,
                  ),
                  child: SearchResultsPanel(
                    search: state.search,
                    selectedIndex: state.selectedResultIndex,
                    onSelected: controller.selectResult,
                    onPlay: controller.playSong,
                    onAdd: controller.addSongToQueue,
                  ),
                ),
              ),
            ],
          ),
          if (_queueDrawerOpen) ...[
            Positioned.fill(
              child: GestureDetector(
                onTap: _closeQueueDrawer,
                child: ColoredBox(
                  color: AppColors.background.withValues(alpha: 0.42),
                ),
              ),
            ),
            Positioned.fill(
              child: Align(
                alignment: Alignment.centerRight,
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 1, end: 0),
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  builder: (context, value, child) {
                    return FractionalTranslation(
                      translation: Offset(value, 0),
                      child: child,
                    );
                  },
                  child: SizedBox(
                    key: const ValueKey('selectedQueueDrawer'),
                    width: AppLayout.browserRightPanelWidth,
                    child: SelectedQueuePanel(onClose: _closeQueueDrawer),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
      bottomBar: AppBottomHintBar(
        leading: VolumeIndicator(
          level: volume.level,
          enabled: volume.isAvailable,
          onChanged: ref.read(volumeProvider.notifier).setLevel,
        ),
        items: SongBrowserMockData.bottomHints(l10n),
        trailingItems: SongBrowserMockData.trailingHints(l10n, queueCount),
        onItemTap: _handleHint,
      ),
    );
  }

  void _handleHint(BottomHintItem item) {
    switch (item.id) {
      case 'back':
        Navigator.of(context).maybePop();
      case 'queue':
        setState(() {
          _queueDrawerOpen = true;
        });
    }
  }

  void _closeQueueDrawer() {
    setState(() {
      _queueDrawerOpen = false;
    });
  }

  void _handleTopAction(SongBrowserController controller, int index) {
    if (index == SongBrowserMockData.selectedTabIndex) {
      Navigator.of(context).pushNamed(AppRouter.selectedQueue);
      return;
    }
    controller.selectTopAction(index);
  }
}
