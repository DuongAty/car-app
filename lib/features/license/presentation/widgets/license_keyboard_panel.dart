import 'package:flutter/material.dart';
import 'package:viet_ktv/l10n/app_localizations.dart';

import '../../../../core/shared/widgets/panel_frame.dart';
import '../../../../core/shared/widgets/virtual_key_tile.dart';
import '../../../../core/theme/app_icons.dart';
import '../../../../core/theme/app_layout.dart';
import '../../../../l10n/l10n.dart';

const keyBackspace = 'BACK';
const keyClear = 'CLEAR';
const keySubmit = 'SUBMIT';

const _rows = [
  [
    'A',
    'B',
    'C',
    'D',
    'E',
    'F',
    'G',
    'H',
    'I',
    'J',
    'K',
    'L',
    'M',
    keyBackspace,
  ],
  ['N', 'O', 'P', 'Q', 'R', 'S', 'T', 'U', 'V', 'W', 'X', 'Y', 'Z'],
  ['1', '2', '3', '4', '5', '6', '7', '8', '9', '0', '-'],
  [keyClear, keySubmit],
];

/// On-screen alphanumeric keyboard for typing a license key. No space/mode
/// toggle keys — license keys are a fixed alnum+dash format, unlike the free
/// text song search keyboard it otherwise mirrors.
class LicenseKeyboardPanel extends StatelessWidget {
  const LicenseKeyboardPanel({super.key, required this.onKeyPressed});

  final ValueChanged<String> onKeyPressed;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return PanelFrame(
      child: Column(
        children: [
          for (final row in _rows) ...[
            Expanded(
              child: Row(
                children: [
                  for (var index = 0; index < row.length; index++) ...[
                    if (index > 0)
                      const SizedBox(width: AppLayout.browserKeyGap),
                    Expanded(
                      flex: _flexFor(row[index]),
                      child: _key(l10n, row[index]),
                    ),
                  ],
                ],
              ),
            ),
            if (row != _rows.last)
              const SizedBox(height: AppLayout.browserKeyRowGap),
          ],
        ],
      ),
    );
  }

  Widget _key(AppLocalizations l10n, String key) {
    if (key == keyBackspace) {
      return VirtualKeyTile(
        icon: AppIcons.backspace,
        onPressed: () => onKeyPressed(key),
        onLongPress: () => onKeyPressed(keyClear),
      );
    }
    if (key == keyClear) {
      return VirtualKeyTile(
        label: l10n.keyboardClear,
        onPressed: () => onKeyPressed(key),
      );
    }
    if (key == keySubmit) {
      return VirtualKeyTile(
        label: l10n.licenseKeyboardSubmit,
        filled: true,
        onPressed: () => onKeyPressed(key),
      );
    }
    return VirtualKeyTile(label: key, onPressed: () => onKeyPressed(key));
  }

  int _flexFor(String key) => switch (key) {
    keyClear => 2,
    keySubmit => 3,
    _ => 1,
  };
}
