import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../features/favorites/presentation/providers/favorites_controller.dart';
import '../../../features/song_browser/data/models/song_item.dart';
import '../../../features/source_selection/data/models/music_source.dart';
import 'favorite_toggle_button.dart';

/// Self-contained favorite heart for a single song row.
///
/// Watches only whether *this* song is a favorite via a `.select`, so toggling
/// any favorite rebuilds just the affected row's heart rather than the whole
/// results/suggestions list. It also keeps the membership check O(1)-ish per
/// row instead of the panel re-scanning the favorites list for every visible
/// row on each rebuild.
class FavoriteToggle extends ConsumerWidget {
  const FavoriteToggle({
    super.key,
    required this.song,
    required this.source,
    this.size = 42,
    this.iconSize = 22,
  });

  final SongItem song;
  final MusicSourceLogoStyle source;
  final double size;
  final double iconSize;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isFavorite = ref.watch(
      favoritesControllerProvider.select(
        (favorites) => favorites.any((entry) => entry.song.id == song.id),
      ),
    );

    return FavoriteToggleButton(
      isFavorite: isFavorite,
      onPressed: () =>
          ref.read(favoritesControllerProvider.notifier).toggle(song, source),
      size: size,
      iconSize: iconSize,
    );
  }
}
