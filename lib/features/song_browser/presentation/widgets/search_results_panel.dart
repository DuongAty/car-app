import 'package:flutter/material.dart';

import '../../../../core/shared/widgets/panel_frame.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../l10n/l10n.dart';
import '../../data/models/song_item.dart';
import '../providers/song_browser_provider.dart';
import 'search_result_tile.dart';

/// Right column: results for the query submitted with the on-screen
/// keyboard's TÌM key, each addable to the queue.
class SearchResultsPanel extends StatelessWidget {
  const SearchResultsPanel({
    super.key,
    required this.search,
    required this.selectedIndex,
    required this.onSelected,
    required this.onPlay,
    required this.onAdd,
  });

  final SearchState search;
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final ValueChanged<SongItem> onPlay;
  final ValueChanged<SongItem> onAdd;

  @override
  Widget build(BuildContext context) {
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
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(color: AppColors.green),
              const SizedBox(height: 16),
              Text(l10n.searchLoading, style: bodyStyle),
            ],
          ),
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
            ? Center(child: Text(l10n.searchEmpty, style: bodyStyle))
            : ListView.separated(
                padding: EdgeInsets.zero,
                physics: const BouncingScrollPhysics(),
                itemCount: results.length,
                separatorBuilder: (_, _) =>
                    Container(height: 1, color: AppColors.panelBorderSoft),
                itemBuilder: (context, index) => SearchResultTile(
                  item: results[index],
                  selected: index == selectedIndex,
                  onPressed: () => onPlay(results[index]),
                  onFocused: () => onSelected(index),
                  onAdd: () => onAdd(results[index]),
                ),
              ),
      ),
    };
  }
}
