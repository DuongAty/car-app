import 'package:flutter/widgets.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_icons.dart';
import '../../../../l10n/app_localizations.dart';
import '../../data/models/app_settings.dart';

String settingsCategoryLabel(AppLocalizations l10n, SettingsCategory category) {
  return switch (category) {
    SettingsCategory.device => l10n.settingsDevice,
    SettingsCategory.audio => l10n.settingsAudio,
    SettingsCategory.display => l10n.settingsDisplay,
    SettingsCategory.interface => l10n.settingsInterface,
    SettingsCategory.video => l10n.settingsVideoPlayback,
    SettingsCategory.language => l10n.settingsLanguageSection,
    SettingsCategory.songManagement => l10n.settingsSongManagement,
    SettingsCategory.account => l10n.settingsAccount,
    SettingsCategory.system => l10n.settingsSystem,
    SettingsCategory.info => l10n.settingsInfo,
  };
}

IconData settingsCategoryIcon(SettingsCategory category) {
  return switch (category) {
    SettingsCategory.device => AppIcons.deviceHub,
    SettingsCategory.audio => AppIcons.volumeUp,
    SettingsCategory.display => AppIcons.display,
    SettingsCategory.interface => AppIcons.palette,
    SettingsCategory.video => AppIcons.videoSettings,
    SettingsCategory.language => AppIcons.language,
    SettingsCategory.songManagement => AppIcons.movie,
    SettingsCategory.account => AppIcons.account,
    SettingsCategory.system => AppIcons.settings,
    SettingsCategory.info => AppIcons.info,
  };
}

Color settingsCategoryAccent(SettingsCategory category) {
  return switch (category) {
    SettingsCategory.device => AppColors.blue,
    SettingsCategory.audio => AppColors.orange,
    SettingsCategory.display => AppColors.purple,
    SettingsCategory.interface => AppColors.green,
    SettingsCategory.video => AppColors.green,
    SettingsCategory.language => AppColors.blue,
    SettingsCategory.songManagement => AppColors.fire,
    SettingsCategory.account => AppColors.yellow,
    SettingsCategory.system => AppColors.textSecondary,
    SettingsCategory.info => AppColors.purple,
  };
}

String videoQualityLabel(AppLocalizations l10n, VideoQuality quality) {
  return switch (quality) {
    VideoQuality.fourK => l10n.settingsQuality4k,
    VideoQuality.fullHd => l10n.settingsQualityFhd,
    VideoQuality.hd => l10n.settingsQualityHd,
    VideoQuality.sd => l10n.settingsQualitySd,
    VideoQuality.auto => l10n.settingsQualityAuto,
  };
}

String videoQualityResolution(VideoQuality quality) {
  return switch (quality) {
    VideoQuality.fourK => '3840 x 2160',
    VideoQuality.fullHd => '1920 x 1080',
    VideoQuality.hd => '1280 x 720',
    VideoQuality.sd => '720 x 480',
    VideoQuality.auto => '',
  };
}
