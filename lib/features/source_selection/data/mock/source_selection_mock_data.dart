import 'package:viet_ktv/l10n/app_localizations.dart';

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
  ];
}
