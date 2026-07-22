import 'package:flutter/material.dart';
import 'package:viet_ktv/l10n/app_localizations.dart';

import '../../../../core/models/bottom_hint_item.dart';
import '../../../../core/models/nav_action_item.dart';
import '../../../../core/theme/app_colors.dart';
import '../models/music_source.dart';

abstract final class SourceSelectionMockData {
  static List<MusicSource> localizedSources(AppLocalizations l10n) => [
    MusicSource(
      id: 'youtube',
      subtitle: l10n.sourceYoutubeSubtitle,
      accentColor: AppColors.red,
      logoStyle: MusicSourceLogoStyle.youtube,
    ),
    MusicSource(
      id: 'soundcloud',
      subtitle: l10n.sourceSoundcloudSubtitle,
      accentColor: AppColors.orange,
      logoStyle: MusicSourceLogoStyle.soundcloud,
    ),
    MusicSource(
      id: 'mixcloud',
      subtitle: l10n.sourceMcloudSubtitle,
      accentColor: AppColors.purple,
      logoStyle: MusicSourceLogoStyle.mixcloud,
    ),
  ];

  static List<NavActionItem> topActions(AppLocalizations l10n) => [
    NavActionItem(label: l10n.topConnectPhone, icon: Icons.qr_code_2_rounded),
    NavActionItem(label: l10n.topSettings, icon: Icons.settings_outlined),
    NavActionItem(label: l10n.topExit, icon: Icons.power_settings_new_rounded),
  ];

  static List<BottomHintItem> bottomHints(AppLocalizations l10n) => [
    BottomHintItem(
      id: 'select',
      badgeText: 'OK',
      label: l10n.hintSelect,
      accentColor: AppColors.greenDeep,
    ),
    BottomHintItem(
      id: 'back',
      badgeIcon: Icons.arrow_back,
      label: l10n.hintBack,
    ),
  ];

  static List<BottomHintItem> trailingHints(AppLocalizations l10n) => [
    BottomHintItem(
      id: 'clear-queue',
      badgeText: 'C',
      label: l10n.hintClearQueue,
      accentColor: AppColors.yellow,
    ),
    BottomHintItem(
      id: 'queue',
      badgeText: 'D',
      label: l10n.hintQueueCount(0),
      accentColor: AppColors.blue,
    ),
  ];
}
