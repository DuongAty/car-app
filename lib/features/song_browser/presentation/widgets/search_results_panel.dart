import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/shared/widgets/panel_frame.dart';
import '../../../../core/shared/widgets/neon_empty_state.dart';
import '../../../../core/shared/widgets/neon_skeleton.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_icons.dart';
import '../../../../l10n/l10n.dart';
import '../../../source_selection/data/models/music_source.dart';
import '../../data/models/song_item.dart';
import '../providers/song_browser_provider.dart';
import 'search_result_tile.dart';

/// Right column: results for the query submitted with the on-screen
/// keyboard's TÌM key, each addable to the queue.
class SearchResultsPanel extends ConsumerWidget {
  const SearchResultsPanel({
    super.key,
    required this.search,
    required this.selectedIndex,
    required this.onSelected,
    required this.onPlay,
    required this.onAdd,
    required this.source,
  });

  final SearchState search;
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final ValueChanged<SongItem> onPlay;
  final ValueChanged<SongItem> onAdd;
  final MusicSourceLogoStyle source;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final bodyStyle = Theme.of(context).textTheme.bodyMedium;

    return switch (search) {
      SearchIdle() => PanelFrame(
        title: l10n.panelSearchResults,
        child: Center(
          child: Text(
            l10n.searchIdlePrompt,
            textAlign: TextAlign.center,
            style: bodyStyle,
          ),
        ),
      ),
      SearchLoading() => PanelFrame(
        title: l10n.panelSearchResults,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(l10n.searchLoading, style: bodyStyle),
            ),
            const Expanded(child: NeonSkeletonList(itemCount: 5)),
          ],
        ),
      ),
      SearchFailed() => PanelFrame(
        title: l10n.panelSearchResults,
        child: Center(
          child: Text(
            l10n.searchFailed,
            textAlign: TextAlign.center,
            style: bodyStyle,
          ),
        ),
      ),
      SearchSuccess(:final results) => PanelFrame(
        title: l10n.panelSearchResults,
        trailingText: l10n.searchResultCount(results.length),
        child: results.isEmpty
            ? NeonEmptyState(
                icon: AppIcons.search,
                title: l10n.searchEmpty,
                subtitle: l10n.searchIdlePrompt,
              )
            : ListView.separated(
                padding: EdgeInsets.zero,
                scrollCacheExtent: const ScrollCacheExtent.pixels(140),
                physics: const ClampingScrollPhysics(),
                itemCount: results.length,
                separatorBuilder: (_, _) =>
                    Container(height: 1, color: AppColors.panelBorderSoft),
                itemBuilder: (context, index) => SearchResultTile(
                  item: results[index],
                  selected: index == selectedIndex,
                  onPressed: () => onPlay(results[index]),
                  onFocused: () => onSelected(index),
                  onAdd: () => onAdd(results[index]),
                  source: source,
                ),
              ),
      ),
    };
  }
}
