import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/locale_provider.dart';
import '../../../../core/services/app_system_service.dart';
import '../../../../core/shared/widgets/focusable_tile.dart';
import '../../../../core/shared/widgets/language_toggle.dart';
import '../../../../core/shared/widgets/panel_frame.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_icons.dart';
import '../../../../core/theme/app_motion.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../l10n/l10n.dart';
import '../../../../routes/app_router.dart';
import '../../data/models/app_settings.dart';
import '../providers/settings_controller.dart';
import 'settings_copy.dart';

class SettingsContentPanel extends ConsumerWidget {
  const SettingsContentPanel({
    super.key,
    required this.settings,
    required this.controller,
    required this.onClearFavorites,
    required this.onClearHistory,
  });

  final AppSettings settings;
  final SettingsController controller;
  final VoidCallback onClearFavorites;
  final VoidCallback onClearHistory;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final category = settings.selectedCategory;

    return PanelFrame(
      title: settingsCategoryLabel(l10n, category),
      leadingIcon: settingsCategoryIcon(category),
      leadingIconColor: settingsCategoryAccent(category),
      opacity: 0.5,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: ListView(
        padding: EdgeInsets.zero,
        physics: const ClampingScrollPhysics(),
        children: switch (category) {
          SettingsCategory.device => _deviceSettings(context),
          SettingsCategory.audio => _audioSettings(context),
          SettingsCategory.display => _displaySettings(context),
          SettingsCategory.interface => _interfaceSettings(context),
          SettingsCategory.video => _videoSettings(context),
          SettingsCategory.language => _languageSettings(context, ref),
          SettingsCategory.songManagement => _songManagementSettings(context),
          SettingsCategory.account => _accountSettings(context),
          SettingsCategory.system => _systemSettings(context),
          SettingsCategory.info => _infoSettings(context),
        },
      ),
    );
  }

  List<Widget> _videoSettings(BuildContext context) {
    final l10n = context.l10n;
    return [
      _SectionTitle(l10n.settingsQualitySection),
      _QualityGrid(settings: settings, controller: controller),
      const SizedBox(height: AppSpacing.lg),
      _SectionTitle(l10n.settingsPlaybackModeSection),
      _SettingToggleRow(
        icon: AppIcons.play,
        title: l10n.settingsPlayContinuous,
        subtitle: l10n.settingsPlayContinuousDescription,
        value: settings.continuousPlayback,
        onChanged: controller.setContinuousPlayback,
      ),
      _SettingToggleRow(
        icon: AppIcons.repeat,
        title: l10n.settingsRepeatAll,
        subtitle: l10n.settingsRepeatAllDescription,
        value: settings.repeatAll,
        onChanged: controller.setRepeatAll,
      ),
      _SettingToggleRow(
        icon: AppIcons.repeatOne,
        title: l10n.settingsRepeatOne,
        subtitle: l10n.settingsRepeatOneDescription,
        value: settings.repeatOne,
        onChanged: controller.setRepeatOne,
      ),
      _SettingToggleRow(
        icon: AppIcons.shuffle,
        title: l10n.settingsShuffle,
        subtitle: l10n.settingsShuffleDescription,
        value: settings.shuffle,
        onChanged: controller.setShuffle,
      ),
      const SizedBox(height: AppSpacing.lg),
      _SectionTitle(l10n.settingsOtherOptionsSection),
      _StepperRow(
        icon: AppIcons.timer,
        title: l10n.settingsBuffer,
        subtitle: l10n.settingsBufferDescription,
        value: l10n.settingsSeconds(settings.bufferSeconds),
        onDecrease: () => controller.stepBuffer(-1),
        onIncrease: () => controller.stepBuffer(1),
      ),
      _SettingToggleRow(
        icon: AppIcons.movie,
        title: l10n.settingsAutoMv,
        subtitle: l10n.settingsAutoMvDescription,
        value: settings.autoPlayMv,
        onChanged: controller.setAutoPlayMv,
      ),
      _SettingToggleRow(
        icon: AppIcons.captions,
        title: l10n.settingsCaptions,
        subtitle: l10n.settingsCaptionsDescription,
        value: settings.showCaptions,
        onChanged: controller.setShowCaptions,
      ),
      const SizedBox(height: AppSpacing.lg),
      _SectionTitle(l10n.settingsDemoVideoSection, color: AppColors.fire),
      _SettingToggleRow(
        icon: AppIcons.videoSettings,
        title: l10n.settingsDemoEnabled,
        subtitle: l10n.settingsDemoEnabledDescription,
        value: settings.demoVideoEnabled,
        onChanged: controller.setDemoVideoEnabled,
      ),
      _NavigationRow(
        icon: AppIcons.movie,
        title: l10n.settingsDemoPick,
        subtitle: l10n.settingsDemoFile,
        onPressed: () => _showSnack(context, l10n.settingsActionUnavailable),
      ),
      _NavigationRow(
        icon: AppIcons.captions,
        title: l10n.settingsOsdText,
        subtitle: l10n.settingsOsdTextValue,
        onPressed: () => _showSnack(context, l10n.settingsActionUnavailable),
      ),
    ];
  }

  List<Widget> _deviceSettings(BuildContext context) {
    final l10n = context.l10n;
    return [
      _SectionTitle(l10n.settingsDevice),
      _NavigationRow(
        icon: AppIcons.connectPhone,
        title: l10n.settingsDeviceQr,
        subtitle: l10n.settingsDeviceHint,
        onPressed: () => _showSnack(context, l10n.settingsActionUnavailable),
      ),
      _InfoRow(
        icon: AppIcons.deviceHub,
        title: l10n.settingsDeviceName,
        subtitle: l10n.settingsDeviceHint,
      ),
    ];
  }

  List<Widget> _audioSettings(BuildContext context) {
    final l10n = context.l10n;
    return [
      _SectionTitle(l10n.settingsAudio),
      _SliderRow(
        icon: AppIcons.volumeUp,
        title: l10n.settingsMasterVolume,
        value: settings.masterVolume,
        onChanged: controller.setMasterVolume,
      ),
      _SliderRow(
        icon: AppIcons.movie,
        title: l10n.settingsMusicVolume,
        value: settings.musicVolume,
        onChanged: controller.setMusicVolume,
      ),
      _SettingToggleRow(
        icon: AppIcons.microphone,
        title: l10n.settingsVocalBoost,
        subtitle: l10n.settingsAudioHint,
        value: settings.vocalBoost,
        onChanged: controller.setVocalBoost,
      ),
    ];
  }

  List<Widget> _displaySettings(BuildContext context) {
    final l10n = context.l10n;
    return [
      _SectionTitle(l10n.settingsDisplay),
      _SliderRow(
        icon: AppIcons.captions,
        title: l10n.settingsLyricSize,
        value: settings.lyricScale,
        onChanged: controller.setLyricScale,
      ),
      _SettingToggleRow(
        icon: AppIcons.highQuality,
        title: l10n.settingsVisualizer,
        subtitle: l10n.settingsDisplayHint,
        value: settings.visualizerEnabled,
        onChanged: controller.setVisualizerEnabled,
      ),
    ];
  }

  List<Widget> _interfaceSettings(BuildContext context) {
    final l10n = context.l10n;
    return [
      _SectionTitle(l10n.settingsInterface),
      _InfoRow(
        icon: AppIcons.palette,
        title: l10n.settingsTheme,
        subtitle: l10n.settingsThemeDefault,
      ),
      _SliderRow(
        icon: AppIcons.fire,
        title: l10n.settingsGlowLevel,
        value: settings.glowLevel,
        onChanged: controller.setGlowLevel,
      ),
      _SettingToggleRow(
        icon: AppIcons.highQuality,
        title: l10n.settingsParticles,
        subtitle: l10n.settingsInterfaceHint,
        value: settings.particlesEnabled,
        onChanged: controller.setParticlesEnabled,
      ),
    ];
  }

  List<Widget> _languageSettings(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final locale = ref.watch(appLocaleProvider);
    final localeController = ref.read(appLocaleProvider.notifier);
    final options = _languageOptions(l10n);
    return [
      _SectionTitle(l10n.settingsLanguageSection),
      Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.sm,
        children: [
          for (final option in options)
            SizedBox(
              width: 210,
              child: _LanguageTile(
                option: option,
                selected: locale.languageCode == option.locale.languageCode,
                onPressed: () {
                  if (option.enabled) {
                    localeController.setLocale(option.locale);
                  } else {
                    _showSnack(context, l10n.settingsLanguageUnavailable);
                  }
                },
              ),
            ),
        ],
      ),
      const SizedBox(height: AppSpacing.lg),
      _PlainRow(
        icon: AppIcons.language,
        title: l10n.settingsLanguage,
        subtitle: l10n.settingsInterfaceHint,
        trailing: LanguageToggle(
          isVietnamese: locale.languageCode == 'vi',
          onToggle: localeController.toggle,
        ),
      ),
    ];
  }

  List<Widget> _songManagementSettings(BuildContext context) {
    final l10n = context.l10n;
    return [
      _SectionTitle(l10n.settingsHistorySection, color: AppColors.fire),
      _ConfirmActionRow(
        icon: AppIcons.favoriteOutline,
        label: l10n.settingsClearFavorites,
        confirmLabel: l10n.settingsConfirmAgain,
        onConfirmed: onClearFavorites,
      ),
      _ConfirmActionRow(
        icon: AppIcons.history,
        label: l10n.settingsClearHistory,
        confirmLabel: l10n.settingsConfirmAgain,
        onConfirmed: onClearHistory,
      ),
      const SizedBox(height: AppSpacing.lg),
      _SectionTitle(l10n.settingsDataSection),
      _NavigationRow(
        icon: AppIcons.history,
        title: l10n.settingsViewHistory,
        subtitle: l10n.settingsManagementHint,
        onPressed: () => Navigator.of(context).pushNamed(AppRouter.history),
      ),
    ];
  }

  List<Widget> _accountSettings(BuildContext context) {
    final l10n = context.l10n;
    return [
      _SectionTitle(l10n.settingsAccount),
      _InfoRow(
        icon: AppIcons.account,
        title: l10n.settingsAccountName,
        subtitle: l10n.settingsAccountPlan,
      ),
      _InfoRow(
        icon: AppIcons.cache,
        title: l10n.settingsAccountPlan,
        subtitle: l10n.settingsAccountHint,
      ),
    ];
  }

  List<Widget> _systemSettings(BuildContext context) {
    final l10n = context.l10n;
    return [
      _SectionTitle(l10n.settingsSystem),
      const _SystemInfoRows(),
      const SizedBox(height: AppSpacing.lg),
      _NavigationRow(
        icon: AppIcons.deviceHub,
        title: l10n.settingsNetworkCheck,
        onPressed: () => _showSnack(context, l10n.settingsNetworkOk),
      ),
      _NavigationRow(
        icon: AppIcons.highQuality,
        title: l10n.settingsSdkCheck,
        onPressed: () => _showSnack(context, l10n.settingsSdkOk),
      ),
      _NavigationRow(
        icon: AppIcons.cache,
        title: l10n.settingsClearCache,
        onPressed: () {
          PaintingBinding.instance.imageCache.clear();
          PaintingBinding.instance.imageCache.clearLiveImages();
          _showSnack(context, l10n.settingsCacheCleared);
        },
      ),
    ];
  }

  List<Widget> _infoSettings(BuildContext context) {
    final l10n = context.l10n;
    return [
      _SectionTitle(l10n.settingsInfo),
      _InfoRow(
        icon: AppIcons.info,
        title: l10n.settingsAppVersion,
        subtitle: '1.0.0',
      ),
      _InfoRow(
        icon: AppIcons.display,
        title: l10n.settingsAndroidSupport,
        subtitle: l10n.settingsInfoHint,
      ),
    ];
  }

  void _showSnack(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
      );
  }
}

List<_LanguageOption> _languageOptions(AppLocalizations l10n) => [
  _LanguageOption('VI', l10n.languageVi, const Locale('vi'), true),
  _LanguageOption('EN', l10n.languageEn, const Locale('en'), true),
  _LanguageOption('FR', l10n.languageFrench, const Locale('fr'), false),
  _LanguageOption('ES', l10n.languageSpanish, const Locale('es'), false),
  _LanguageOption('DE', l10n.languageGerman, const Locale('de'), false),
  _LanguageOption('JA', l10n.languageJapanese, const Locale('ja'), false),
  _LanguageOption('KO', l10n.languageKorean, const Locale('ko'), false),
  _LanguageOption('ZH', l10n.languageChinese, const Locale('zh'), false),
  _LanguageOption('TH', l10n.languageThai, const Locale('th'), false),
  _LanguageOption('ID', l10n.languageIndonesian, const Locale('id'), false),
  _LanguageOption('PT', l10n.languagePortuguese, const Locale('pt'), false),
  _LanguageOption('RU', l10n.languageRussian, const Locale('ru'), false),
];

class _LanguageOption {
  const _LanguageOption(this.code, this.label, this.locale, this.enabled);

  final String code;
  final String label;
  final Locale locale;
  final bool enabled;
}

class _LanguageTile extends StatelessWidget {
  const _LanguageTile({
    required this.option,
    required this.selected,
    required this.onPressed,
  });

  final _LanguageOption option;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return FocusableTile(
      onPressed: onPressed,
      builder: (context, focused) {
        final active = selected || focused;
        return Container(
          padding: const EdgeInsets.all(AppSpacing.sm),
          decoration: BoxDecoration(
            color: active
                ? AppColors.green.withValues(alpha: 0.14)
                : AppColors.panelStrong.withValues(alpha: 0.48),
            borderRadius: BorderRadius.circular(AppRadius.sm),
            border: Border.all(
              color: active ? AppColors.green : AppColors.panelBorderSoft,
              width: active ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Text(
                option.code,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: active ? AppColors.green : AppColors.textSecondary,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  option.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SystemInfoRows extends StatelessWidget {
  const _SystemInfoRows();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return FutureBuilder<AppSystemInfo>(
      future: const AppSystemService().getSystemInfo(),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return _InfoRow(
            icon: AppIcons.deviceHub,
            title: l10n.settingsSystemLoading,
          );
        }
        if (!snapshot.hasData) {
          return _InfoRow(
            icon: AppIcons.warning,
            title: l10n.settingsSystemUnavailable,
          );
        }
        final info = snapshot.data!;
        return Column(
          children: [
            _InfoRow(
              icon: AppIcons.deviceHub,
              title: l10n.settingsNetworkStatus,
              subtitle: info.networkStatus,
            ),
            _InfoRow(
              icon: AppIcons.display,
              title: l10n.settingsDeviceInfo,
              subtitle: '${info.deviceName} · ${info.androidVersion}',
            ),
            _InfoRow(
              icon: AppIcons.info,
              title: l10n.settingsAppVersion,
              subtitle: info.appVersion,
            ),
            _InfoRow(
              icon: AppIcons.cache,
              title: l10n.settingsStorageInfo,
              subtitle: info.storageSummary,
            ),
          ],
        );
      },
    );
  }
}

class _QualityGrid extends StatelessWidget {
  const _QualityGrid({required this.settings, required this.controller});

  final AppSettings settings;
  final SettingsController controller;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 620
            ? 5
            : constraints.maxWidth >= 380
            ? 3
            : 2;
        return GridView.count(
          crossAxisCount: columns,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: AppSpacing.sm,
          crossAxisSpacing: AppSpacing.sm,
          childAspectRatio: columns >= 5 ? 1.05 : 1.75,
          children: [
            for (final quality in VideoQuality.values)
              _QualityTile(
                quality: quality,
                selected: settings.videoQuality == quality,
                onPressed: () => controller.selectVideoQuality(quality),
              ),
          ],
        );
      },
    );
  }
}

class _QualityTile extends StatelessWidget {
  const _QualityTile({
    required this.quality,
    required this.selected,
    required this.onPressed,
  });

  final VideoQuality quality;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final resolution = videoQualityResolution(quality);

    return FocusableTile(
      onPressed: onPressed,
      builder: (context, focused) {
        final active = selected || focused;
        return AnimatedContainer(
          duration: AppMotion.control,
          padding: const EdgeInsets.all(AppSpacing.sm),
          decoration: BoxDecoration(
            color: active
                ? AppColors.green.withValues(alpha: 0.14)
                : AppColors.panelStrong.withValues(alpha: 0.52),
            borderRadius: BorderRadius.circular(AppRadius.sm),
            border: Border.all(
              color: active ? AppColors.green : AppColors.panelBorderSoft,
              width: active ? 1.5 : 1,
            ),
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  selected ? AppIcons.highQuality : AppIcons.display,
                  color: active ? AppColors.green : AppColors.textSecondary,
                  size: 28,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  videoQualityLabel(l10n, quality),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: active ? AppColors.green : AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  resolution.isEmpty
                      ? l10n.settingsQualityAutoDescription
                      : resolution,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.label, {this.color = AppColors.green});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Text(
        label,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
          color: color,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _SettingToggleRow extends StatelessWidget {
  const _SettingToggleRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return _PlainRow(
      icon: icon,
      title: title,
      subtitle: subtitle,
      onPressed: () => onChanged(!value),
      trailing: Switch(
        value: value,
        activeThumbColor: AppColors.textPrimary,
        activeTrackColor: AppColors.greenDeep,
        inactiveThumbColor: AppColors.textSecondary,
        inactiveTrackColor: AppColors.keyFill,
        onChanged: onChanged,
      ),
    );
  }
}

class _NavigationRow extends StatelessWidget {
  const _NavigationRow({
    required this.icon,
    required this.title,
    this.subtitle,
    this.onPressed,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return _PlainRow(
      icon: icon,
      title: title,
      subtitle: subtitle,
      onPressed: onPressed ?? () {},
      trailing: Icon(AppIcons.chevronRight, color: AppColors.textSecondary),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.title, this.subtitle});

  final IconData icon;
  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return _PlainRow(icon: icon, title: title, subtitle: subtitle);
  }
}

class _StepperRow extends StatelessWidget {
  const _StepperRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onDecrease,
    required this.onIncrease,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String value;
  final VoidCallback onDecrease;
  final VoidCallback onIncrease;

  @override
  Widget build(BuildContext context) {
    return _PlainRow(
      icon: icon,
      title: title,
      subtitle: subtitle,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _MiniAction(icon: AppIcons.back, onPressed: onDecrease),
          SizedBox(
            width: 74,
            child: Text(
              value,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          _MiniAction(icon: AppIcons.chevronRight, onPressed: onIncrease),
        ],
      ),
    );
  }
}

class _SliderRow extends StatelessWidget {
  const _SliderRow({
    required this.icon,
    required this.title,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final double value;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return _PlainRow(
      icon: icon,
      title: title,
      subtitle: '${(value * 100).round()}%',
      trailing: SizedBox(
        width: 220,
        child: Slider(
          value: value,
          activeColor: AppColors.green,
          inactiveColor: AppColors.keyFill,
          onChanged: onChanged,
        ),
      ),
    );
  }
}

class _PlainRow extends StatelessWidget {
  const _PlainRow({
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onPressed,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final content = Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.textSecondary, size: 28),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: AppSpacing.md),
            trailing!,
          ],
        ],
      ),
    );

    if (onPressed == null) {
      return _RowFrame(child: content);
    }

    return FocusableTile(
      onPressed: onPressed!,
      builder: (context, focused) {
        return _RowFrame(focused: focused, child: content);
      },
    );
  }
}

class _RowFrame extends StatelessWidget {
  const _RowFrame({required this.child, this.focused = false});

  final Widget child;
  final bool focused;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: AppMotion.focus,
      margin: const EdgeInsets.only(bottom: AppSpacing.xs),
      decoration: BoxDecoration(
        color: focused
            ? AppColors.green.withValues(alpha: 0.12)
            : AppColors.panelStrong.withValues(alpha: 0.34),
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(
          color: focused ? AppColors.green : AppColors.panelBorderSoft,
          width: focused ? 1.4 : 1,
        ),
      ),
      child: child,
    );
  }
}

class _MiniAction extends StatelessWidget {
  const _MiniAction({required this.icon, required this.onPressed});

  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return FocusableTile(
      onPressed: onPressed,
      builder: (context, focused) {
        return Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: focused
                ? AppColors.green.withValues(alpha: 0.2)
                : AppColors.keyFill.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(AppRadius.xs),
            border: Border.all(
              color: focused ? AppColors.green : AppColors.panelBorder,
            ),
          ),
          child: Icon(icon, color: AppColors.textPrimary, size: 20),
        );
      },
    );
  }
}

class _ConfirmActionRow extends StatefulWidget {
  const _ConfirmActionRow({
    required this.icon,
    required this.label,
    required this.confirmLabel,
    required this.onConfirmed,
  });

  final IconData icon;
  final String label;
  final String confirmLabel;
  final VoidCallback onConfirmed;

  @override
  State<_ConfirmActionRow> createState() => _ConfirmActionRowState();
}

class _ConfirmActionRowState extends State<_ConfirmActionRow> {
  bool _armed = false;
  Timer? _resetTimer;

  @override
  void dispose() {
    _resetTimer?.cancel();
    super.dispose();
  }

  void _handleTap() {
    if (_armed) {
      _resetTimer?.cancel();
      setState(() => _armed = false);
      widget.onConfirmed();
      return;
    }
    setState(() => _armed = true);
    _resetTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() => _armed = false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return FocusableTile(
      onPressed: _handleTap,
      builder: (context, focused) {
        final active = _armed || focused;
        return _RowFrame(
          focused: active,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            child: Row(
              children: [
                Icon(widget.icon, color: AppColors.red, size: 28),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    _armed ? widget.confirmLabel : widget.label,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: _armed ? AppColors.red : AppColors.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
