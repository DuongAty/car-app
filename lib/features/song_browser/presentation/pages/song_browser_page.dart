import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/shared/widgets/collapsible_axis.dart';
import '../../../../core/shared/widgets/karaoke_shell.dart';
import '../../../../core/shared/widgets/surface_scope.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_layout.dart';
import '../../../../core/theme/app_motion.dart';
import '../../../../l10n/l10n.dart';
import '../../../../routes/app_router.dart';
import '../../../playback/presentation/providers/now_playing_controller.dart';
import '../../../queue/presentation/providers/queue_provider.dart';
import '../../../playback/presentation/widgets/app_control_bar.dart';
import '../../../queue/presentation/widgets/selected_queue_panel.dart';
import '../../../source_selection/data/models/music_source.dart';
import '../../data/mock/song_browser_mock_data.dart';
import '../../data/song_categories.dart';
import '../providers/song_browser_provider.dart';
import '../widgets/category_grid_panel.dart';
import '../widgets/main_top_bar.dart';
import '../widgets/native_song_search_field.dart';
import '../widgets/preview_player.dart';
import '../widgets/search_results_panel.dart';

class SongBrowserPage extends ConsumerStatefulWidget {
  const SongBrowserPage({
    super.key,
    required this.source,
    this.initialTopActionIndex,
  });

  final MusicSource source;
  final int? initialTopActionIndex;

  @override
  ConsumerState<SongBrowserPage> createState() => _SongBrowserPageState();
}

class _SongBrowserPageState extends ConsumerState<SongBrowserPage> {
  bool _queueDrawerOpen = false;
  bool _initialTopActionApplied = false;

  // Fullscreen is the one mode where PreviewPlayer sits outside ContentSlab
  // (no rounded-frame slab around a full-bleed player), so its ancestor
  // subtree's widget type genuinely differs between fullscreen and the other
  // two modes. Without a stable identity, Flutter treats that as a brand-new
  // subtree on every fullscreen toggle and tears down PreviewPlayer's own
  // State — silently breaking the deferred focus-on-enter-fullscreen logic in
  // `_PlayerRemoteShortcuts.didUpdateWidget`, which never runs again because
  // `initState` runs instead. The GlobalKey lets Flutter re-parent the same
  // Element under the new ancestor instead of discarding it.
  final GlobalKey _previewPlayerKey = GlobalKey();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialTopActionApplied) {
      return;
    }
    _initialTopActionApplied = true;

    final initialTopActionIndex = widget.initialTopActionIndex;
    if (initialTopActionIndex != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        ref
            .read(songBrowserProvider(widget.source).notifier)
            .selectTopAction(initialTopActionIndex);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final provider = songBrowserProvider(widget.source);
    // watch (not read) the notifier: this provider is autoDispose.family and
    // depends on nowPlayingProvider.notifier, so it is recreated when playback
    // state is rebuilt (e.g. a settings change at startup). Watching the
    // notifier rebuilds this page only when the controller instance actually
    // changes — never on a plain data/keystroke change — so the callbacks below
    // can never hold a disposed controller.
    final controller = ref.watch(provider.notifier);
    final source = widget.source.logoStyle;
    // Watch only the tab index at page scope. The native search panel below
    // watches its own query/result slices, so typing does not rebuild this page.
    final selectedTopActionIndex = ref.watch(
      provider.select((state) => state.selectedTopActionIndex),
    );
    final mode = ref.watch(nowPlayingProvider.select((value) => value.mode));
    final isCategoryTab =
        selectedTopActionIndex == SongBrowserMockData.categoryTabIndex;

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
        // `mode` is sticky and app-wide, but the category tab builds no
        // PreviewPlayer. Hiding the chrome there would leave a page with no
        // way out but Back, so the mode only affects the tab that has a
        // player.
        chromeVisible: isCategoryTab || mode != PlayerViewMode.fullscreen,
        topBar: MainTopBar(
          selectedIndex: selectedTopActionIndex,
          currentSource: widget.source,
          onSearchSelected: () =>
              controller.selectTopAction(SongBrowserMockData.searchTabIndex),
          onCategorySelected: () =>
              controller.selectTopAction(SongBrowserMockData.categoryTabIndex),
          onOtherSelected: (index) => _handleTopAction(controller, index),
        ),
        body: LayoutBuilder(
          builder: (context, constraints) {
            // Keep the player and keyboard usable on compact landscape displays.
            // The side panels are targets, not requirements: they can shrink
            // before the central interaction area does.
            final leftPanelWidth = (constraints.maxWidth * 0.38)
                .clamp(360.0, AppLayout.browserRightPanelWidth)
                .toDouble();
            final rightPanelWidth = (constraints.maxWidth * 0.35)
                .clamp(360.0, AppLayout.browserRightPanelWidth)
                .toDouble();

            return Stack(
              children: [
                if (isCategoryTab)
                  ContentSlab(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SizedBox(
                          width: (leftPanelWidth * 1.38)
                              .clamp(360.0, constraints.maxWidth * 0.46)
                              .toDouble(),
                          child: Consumer(
                            builder: (context, ref, _) {
                              final browseTab = ref.watch(
                                provider.select((s) => s.browseTab),
                              );
                              final artistRegion = ref.watch(
                                provider.select((s) => s.artistRegion),
                              );
                              final selectedCategoryIndex = ref.watch(
                                provider.select((s) => s.selectedCategoryIndex),
                              );
                              final selectedArtistIndex = ref.watch(
                                provider.select((s) => s.selectedArtistIndex),
                              );
                              return CategoryGridPanel(
                                source: source,
                                browseTab: browseTab,
                                artistRegion: artistRegion,
                                selectedCategoryIndex: selectedCategoryIndex,
                                selectedArtistIndex: selectedArtistIndex,
                                onBrowseTabSelected: controller.selectBrowseTab,
                                onArtistRegionSelected:
                                    controller.selectArtistRegion,
                                onCategorySelected: (index) {
                                  final category = songCategoriesFor(
                                    l10n,
                                    source,
                                  )[index];
                                  controller.browseCategory(
                                    index,
                                    category.seedQuery,
                                  );
                                },
                                onCategoryFocused: controller.selectCategory,
                                onArtistSelected: (index) {
                                  final artists = switch (artistRegion) {
                                    ArtistRegion.vietnam => vietnameseArtists(),
                                    ArtistRegion.international =>
                                      internationalArtists(),
                                  };
                                  controller.browseArtist(
                                    index,
                                    artists[index].seedQuery,
                                  );
                                },
                                onArtistFocused: controller.selectArtist,
                              );
                            },
                          ),
                        ),
                        const SurfaceDivider(axis: Axis.vertical),
                        Expanded(child: _SearchResults(source: widget.source)),
                      ],
                    ),
                  )
                else
                  Builder(
                    builder: (context) {
                      final Widget row = Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // This follows the selected-queue layout: search and
                          // its results live in one left column, while the
                          // player uses every remaining pixel on the right.
                          CollapsibleAxis(
                            axis: Axis.horizontal,
                            // +1 for the hairline that replaced the gap.
                            extent: leftPanelWidth + 1,
                            collapsed: mode != PlayerViewMode.normal,
                            // Anchored to the far edge so the panel slides out
                            // of frame rather than being trimmed in place.
                            alignment: Alignment.topRight,
                            // Keep the hairline inside the collapsible region,
                            // so it closes with the search column.
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                SizedBox(
                                  width: leftPanelWidth,
                                  child: _BrowserSearchPanel(
                                    source: widget.source,
                                    controller: controller,
                                  ),
                                ),
                                // Built only in normal mode: collapsed still
                                // mounts this child (state is kept alive for
                                // an instant re-expand), so the divider must be
                                // conditional itself or it would keep painting
                                // — clipped to nothing, but still in the tree —
                                // down the player's left edge.
                                if (mode == PlayerViewMode.normal)
                                  const SurfaceDivider(axis: Axis.vertical),
                              ],
                            ),
                          ),
                          Expanded(
                            child: PreviewPlayer(key: _previewPlayerKey),
                          ),
                        ],
                      );

                      // No slab in fullscreen: the player is deliberately
                      // full-bleed there, and a slab would put the rounded
                      // frame back. The collapsed search column is still
                      // mounted underneath (so its state survives an instant
                      // return to normal), so it still needs the bare scope —
                      // without it, its search field and results panel would
                      // paint their own bare surfaces with no slab there to
                      // replace them.
                      return mode == PlayerViewMode.fullscreen
                          ? SurfaceScope(child: row)
                          : ContentSlab(child: row);
                    },
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
                        duration: AppMotion.panel,
                        curve: AppMotion.standardCurve,
                        builder: (context, value, child) {
                          return FractionalTranslation(
                            translation: Offset(value, 0),
                            child: child,
                          );
                        },
                        child: SizedBox(
                          key: const ValueKey('selectedQueueDrawer'),
                          width: rightPanelWidth,
                          child: SelectedQueuePanel(onClose: _closeQueueDrawer),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            );
          },
        ),
        // The search tab hosts the full PreviewPlayer; the category ("Danh mục")
        // tab has no stage, so the mini-player drops into the bar there instead.
        bottomBar: AppControlBar(
          hasStagePlayer: !isCategoryTab,
          onMiniPlayerTap: () =>
              controller.selectTopAction(SongBrowserMockData.searchTabIndex),
          onQueue: () => setState(() {
            _queueDrawerOpen = true;
          }),
        ),
      ),
    );
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
    if (index == SongBrowserMockData.settingsTabIndex) {
      Navigator.of(context).pushNamed(AppRouter.settings);
      return;
    }
    if (index == SongBrowserMockData.homeTabIndex) {
      // Home is the initial route — pop back to the existing source picker
      // rather than pushing a second copy onto the stack.
      Navigator.of(context).popUntil((route) => route.isFirst);
      return;
    }
    controller.selectTopAction(index);
  }
}

class _BrowserSearchPanel extends ConsumerWidget {
  const _BrowserSearchPanel({required this.source, required this.controller});

  final MusicSource source;
  final SongBrowserController controller;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = songBrowserProvider(source);
    final query = ref.watch(provider.select((state) => state.query));

    return Column(
      children: [
        SizedBox(
          height: AppLayout.browserSearchHeight,
          child: NativeSongSearchField(
            query: query,
            placeholder: context.l10n.searchPlaceholder,
            onChanged: controller.setQuery,
            onSubmitted: controller.submitSearch,
          ),
        ),
        const SurfaceDivider(),
        Expanded(child: _SearchResults(source: source)),
      ],
    );
  }
}

/// Search-results column, extracted so it watches only `search` +
/// `selectedResultIndex`. It appears on both the search and category tabs, so a
/// shared widget also avoids duplicating the wiring.
class _SearchResults extends ConsumerWidget {
  const _SearchResults({required this.source});

  final MusicSource source;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = songBrowserProvider(source);
    // See SongBrowserPage.build: watch the notifier so a recreated controller
    // is picked up instead of calling a disposed one.
    final controller = ref.watch(provider.notifier);
    final search = ref.watch(provider.select((s) => s.search));
    final selectedIndex = ref.watch(
      provider.select((s) => s.selectedResultIndex),
    );

    return SearchResultsPanel(
      search: search,
      selectedIndex: selectedIndex,
      onSelected: controller.selectResult,
      onPlay: controller.playSong,
      onAdd: (song) {
        final result = controller.addSongToQueue(song);
        final message = switch (result) {
          QueueAddResult.added => context.l10n.queueAdded,
          QueueAddResult.duplicate => context.l10n.queueDuplicate,
        };
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(message),
              duration: const Duration(seconds: 2),
            ),
          );
      },
      source: source.logoStyle,
    );
  }
}
