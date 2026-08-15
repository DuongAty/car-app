import 'package:viet_ktv/l10n/app_localizations.dart';

import '../../../../core/theme/app_colors.dart';
import '../models/music_source.dart';

abstract final class SourceSelectionMockData {
  static List<MusicSource> localizedSources(AppLocalizations l10n) => [
    _source(MusicSourceLogoStyle.youtube, l10n.sourceYoutubeSubtitle),
    _source(MusicSourceLogoStyle.soundcloud, l10n.sourceSoundcloudSubtitle),
  ];

  /// The same source objects as [localizedSources] minus the subtitle, for
  /// callers with no `BuildContext` to localize against (the phone-remote
  /// command handler). Ids and accents stay defined in one place so a queue
  /// entry added by remote de-duplicates against one added on screen.
  static MusicSource unlocalizedSource(MusicSourceLogoStyle style) =>
      _source(style, '');

  static MusicSource _source(MusicSourceLogoStyle style, String subtitle) =>
      switch (style) {
        MusicSourceLogoStyle.youtube => MusicSource(
          id: 'youtube',
          subtitle: subtitle,
          accentColor: AppColors.red,
          logoStyle: MusicSourceLogoStyle.youtube,
        ),
        MusicSourceLogoStyle.soundcloud => MusicSource(
          id: 'soundcloud',
          subtitle: subtitle,
          accentColor: AppColors.orange,
          logoStyle: MusicSourceLogoStyle.soundcloud,
        ),
      };
}
