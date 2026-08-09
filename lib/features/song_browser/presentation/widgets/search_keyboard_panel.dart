import 'package:flutter/material.dart';
import 'package:viet_ktv/l10n/app_localizations.dart';

import '../../../../core/shared/widgets/panel_frame.dart';
import '../../../../core/shared/widgets/search_input_shell.dart';
import '../../../../core/shared/widgets/virtual_key_tile.dart';
import '../../../../core/theme/app_icons.dart';
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
    this.isListening = false,
    this.hasVoiceSearchError = false,
  });

  final String query;
  final ValueChanged<String> onKeyPressed;
  final VoidCallback onMicTap;
  final bool isListening;
  final bool hasVoiceSearchError;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return PanelFrame(
      padding: const EdgeInsets.all(AppSpacing.sm),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxHeight < 300;
          final searchHeight = compact ? 54.0 : AppLayout.browserSearchHeight;
          final rowGap = compact ? 5.0 : AppLayout.browserKeyRowGap;
          final keyGap = compact ? 5.0 : AppLayout.browserKeyGap;
          final keyFontSize = compact ? 17.0 : 22.0;

          return Column(
            children: [
              SizedBox(
                height: searchHeight,
                child: SearchInputShell(
                  value: query,
                  placeholder: l10n.searchPlaceholder,
                  isFocused: query.isNotEmpty || isListening,
                  isListening: isListening,
                  hasVoiceSearchError: hasVoiceSearchError,
                  voiceSearchTooltip: l10n.voiceSearch,
                  stopVoiceSearchTooltip: l10n.stopVoiceSearch,
                  onMicTap: onMicTap,
                  onTap: onMicTap,
                ),
              ),
              SizedBox(height: compact ? AppSpacing.xs : AppSpacing.sm),
              Expanded(
                child: Column(
                  children: [
                    for (final row in SongBrowserMockData.keyboardRows) ...[
                      Expanded(
                        child: Row(
                          children: [
                            for (
                              var index = 0;
                              index < row.length;
                              index++
                            ) ...[
                              if (index > 0) SizedBox(width: keyGap),
                              Expanded(
                                flex: _flexForKey(row[index]),
                                child: _key(
                                  l10n,
                                  row[index],
                                  fontSize: keyFontSize,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      if (row != SongBrowserMockData.keyboardRows.last)
                        SizedBox(height: rowGap),
                    ],
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _key(AppLocalizations l10n, String key, {required double fontSize}) {
    if (key == SongBrowserMockData.keyBackspace) {
      return VirtualKeyTile(
        icon: AppIcons.backspace,
        iconSize: fontSize + 2,
        onPressed: () => onKeyPressed(key),
        onLongPress: () => onKeyPressed(SongBrowserMockData.keyClear),
      );
    }

    return VirtualKeyTile(
      label: SongBrowserMockData.keyboardLabel(l10n, key),
      fontSize: fontSize,
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
