import 'package:flutter/material.dart';
import 'package:viet_ktv/l10n/app_localizations.dart';

import '../../../../core/shared/widgets/panel_frame.dart';
import '../../../../core/shared/widgets/search_input_shell.dart';
import '../../../../core/shared/widgets/virtual_key_tile.dart';
import '../../../../core/theme/app_layout.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../l10n/l10n.dart';
import '../../data/mock/song_browser_mock_data.dart';

/// Search field with the always-visible on-screen keyboard beneath it.
class SearchKeyboardPanel extends StatelessWidget {
  const SearchKeyboardPanel({
    super.key,
    required this.query,
    required this.onKeyPressed,
    required this.onMicTap,
  });

  final String query;
  final ValueChanged<String> onKeyPressed;
  final VoidCallback onMicTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return PanelFrame(
      child: Column(
        children: [
          SizedBox(
            height: AppLayout.browserSearchHeight,
            child: SearchInputShell(
              value: query,
              placeholder: l10n.searchPlaceholder,
              isFocused: query.isNotEmpty,
              onMicTap: onMicTap,
              onTap: onMicTap,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Expanded(
            child: Column(
              children: [
                for (final row in SongBrowserMockData.keyboardRows) ...[
                  Expanded(
                    child: Row(
                      children: [
                        for (var index = 0; index < row.length; index++) ...[
                          if (index > 0)
                            const SizedBox(width: AppLayout.browserKeyGap),
                          Expanded(
                            flex: _flexForKey(row[index]),
                            child: _key(l10n, row[index]),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (row != SongBrowserMockData.keyboardRows.last)
                    const SizedBox(height: AppLayout.browserKeyRowGap),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _key(AppLocalizations l10n, String key) {
    if (key == SongBrowserMockData.keyBackspace) {
      return VirtualKeyTile(
        icon: Icons.backspace_outlined,
        onPressed: () => onKeyPressed(key),
      );
    }

    return VirtualKeyTile(
      label: SongBrowserMockData.keyboardLabel(l10n, key),
      filled: key == SongBrowserMockData.keySearch,
      onPressed: () => onKeyPressed(key),
    );
  }

  int _flexForKey(String key) {
    return switch (key) {
      SongBrowserMockData.keySpace => 4,
      SongBrowserMockData.keyClear => 3,
      SongBrowserMockData.keyNumbers => 2,
      SongBrowserMockData.keySearch => 2,
      _ => 1,
    };
  }
}
