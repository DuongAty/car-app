import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_icons.dart';
import 'circle_icon_button.dart';

/// Heart toggle reused on search results, suggestions, and persisted-song
/// rows to mark a song as a favorite. Filled red when favorited.
class FavoriteToggleButton extends StatelessWidget {
  const FavoriteToggleButton({
    super.key,
    required this.isFavorite,
    required this.onPressed,
    this.size = 42,
    this.iconSize = 22,
  });

  final bool isFavorite;
  final VoidCallback onPressed;
  final double size;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return CircleIconButton(
      icon: isFavorite ? AppIcons.favorite : AppIcons.favoriteOutline,
      onPressed: onPressed,
      size: size,
      iconSize: iconSize,
      tint: isFavorite ? AppColors.red : null,
    );
  }
}
