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
import 'suggestion_tile.dart';

/// Left column: seeded from a curated real search rather than user history —
/// see [RecommendationsState] for why.
class SuggestionsPanel extends ConsumerWidget {
  const SuggestionsPanel({
    super.key,
    required this.recommendations,
    required this.selectedIndex,
    required this.onSelected,
    required this.onPlay,
    required this.source,
  });

  final RecommendationsState recommendations;
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final ValueChanged<SongItem> onPlay;
  final MusicSourceLogoStyle source;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final bodyStyle = Theme.of(context).textTheme.bodyMedium;

    return switch (recommendations) {
      RecommendationsLoading() => PanelFrame(
        title: l10n.panelSuggestions,
        leadingIcon: AppIcons.fire,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(l10n.recommendationsLoading, style: bodyStyle),
            ),
            const Expanded(child: NeonSkeletonList(itemCount: 5)),
          ],
        ),
      ),
      RecommendationsFailed() => PanelFrame(
        title: l10n.panelSuggestions,
        leadingIcon: AppIcons.fire,
        child: Center(
          child: Text(
            l10n.recommendationsFailed,
            textAlign: TextAlign.center,
            style: bodyStyle,
          ),
        ),
      ),
      RecommendationsSuccess(:final items) => PanelFrame(
        title: l10n.panelSuggestions,
        leadingIcon: AppIcons.fire,
        child: items.isEmpty
            ? NeonEmptyState(
                icon: AppIcons.fire,
                title: l10n.recommendationsEmpty,
                subtitle: l10n.searchIdlePrompt,
              )
            : ListView.separated(
                padding: EdgeInsets.zero,
                scrollCacheExtent: const ScrollCacheExtent.pixels(140),
                physics: const ClampingScrollPhysics(),
                itemCount: items.length,
                separatorBuilder: (_, _) =>
                    Container(height: 1, color: AppColors.panelBorderSoft),
                itemBuilder: (context, index) => SuggestionTile(
                  item: items[index],
                  selected: index == selectedIndex,
                  onPressed: () => onPlay(items[index]),
                  onFocused: () => onSelected(index),
                  source: source,
                ),
              ),
      ),
    };
  }
}
