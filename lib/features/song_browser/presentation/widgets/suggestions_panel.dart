import 'package:flutter/material.dart';

import '../../../../core/shared/widgets/panel_frame.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../l10n/l10n.dart';
import '../../data/models/song_item.dart';
import '../providers/song_browser_provider.dart';
import 'suggestion_tile.dart';

/// Left column: seeded from a curated real search rather than user history —
/// see [RecommendationsState] for why.
class SuggestionsPanel extends StatelessWidget {
  const SuggestionsPanel({
    super.key,
    required this.recommendations,
    required this.selectedIndex,
    required this.onSelected,
    required this.onPlay,
  });

  final RecommendationsState recommendations;
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final ValueChanged<SongItem> onPlay;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final bodyStyle = Theme.of(context).textTheme.bodyMedium;

    return switch (recommendations) {
      RecommendationsLoading() => PanelFrame(
        title: l10n.panelSuggestions,
        leadingIcon: Icons.local_fire_department_rounded,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(color: AppColors.green),
              const SizedBox(height: 16),
              Text(l10n.recommendationsLoading, style: bodyStyle),
            ],
          ),
        ),
      ),
      RecommendationsFailed() => PanelFrame(
        title: l10n.panelSuggestions,
        leadingIcon: Icons.local_fire_department_rounded,
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
        leadingIcon: Icons.local_fire_department_rounded,
        child: items.isEmpty
            ? Center(child: Text(l10n.recommendationsEmpty, style: bodyStyle))
            : ListView.separated(
                padding: EdgeInsets.zero,
                physics: const BouncingScrollPhysics(),
                itemCount: items.length,
                separatorBuilder: (_, _) =>
                    Container(height: 1, color: AppColors.panelBorderSoft),
                itemBuilder: (context, index) => SuggestionTile(
                  item: items[index],
                  selected: index == selectedIndex,
                  onPressed: () => onPlay(items[index]),
                  onFocused: () => onSelected(index),
                ),
              ),
      ),
    };
  }
}
