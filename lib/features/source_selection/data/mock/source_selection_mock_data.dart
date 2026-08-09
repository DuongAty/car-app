import 'package:viet_ktv/l10n/app_localizations.dart';

import '../../../../core/models/nav_action_item.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_icons.dart';
import '../models/music_source.dart';

abstract final class SourceSelectionMockData {
  static const int connectPhoneActionIndex = 0;
  static const int settingsActionIndex = 1;
  static const int exitActionIndex = 2;

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
  ];

  static List<NavActionItem> topActions(AppLocalizations l10n) => [
    NavActionItem(label: l10n.topConnectPhone, icon: AppIcons.connectPhone),
    NavActionItem(label: l10n.topSettings, icon: AppIcons.settings),
    NavActionItem(label: l10n.topExit, icon: AppIcons.power),
  ];
}
