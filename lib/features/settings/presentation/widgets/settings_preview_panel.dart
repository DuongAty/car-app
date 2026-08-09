import 'package:flutter/material.dart';

import '../../../../core/shared/widgets/panel_frame.dart';
import '../../../../core/shared/widgets/surface_scope.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_icons.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../l10n/l10n.dart';
import '../../data/models/app_settings.dart';
import 'settings_copy.dart';

class SettingsPreviewPanel extends StatelessWidget {
  const SettingsPreviewPanel({super.key, required this.settings});

  final AppSettings settings;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final category = settings.selectedCategory;
    final accent = settingsCategoryAccent(category);

    return Column(
      children: [
        Expanded(
          flex: 3,
          child: PanelFrame(
            title: l10n.settingsPreview,
            leadingIcon: settingsCategoryIcon(category),
            leadingIconColor: accent,
            opacity: 0.48,
            child: _PreviewBody(settings: settings),
          ),
        ),
        const SurfaceDivider(),
        Expanded(
          flex: 2,
          child: PanelFrame(
            title: category == SettingsCategory.video
                ? l10n.settingsOsdPreview
                : l10n.settingsGuide,
            leadingIcon: category == SettingsCategory.video
                ? AppIcons.captions
                : AppIcons.info,
            leadingIconColor: category == SettingsCategory.video
                ? AppColors.fire
                : accent,
            opacity: 0.48,
            child: _GuideBody(settings: settings),
          ),
        ),
      ],
    );
  }
}

class _PreviewBody extends StatelessWidget {
  const _PreviewBody({required this.settings});

  final AppSettings settings;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return switch (settings.selectedCategory) {
      SettingsCategory.video => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.sm),
              child: DecoratedBox(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0xFF182B4A),
                      Color(0xFFFF7A18),
                      Color(0xFF090A10),
                    ],
                    stops: [0, 0.48, 1],
                  ),
                ),
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: CustomPaint(painter: _PalmSilhouettePainter()),
                    ),
                    Align(
                      alignment: Alignment.bottomCenter,
                      child: Container(
                        height: 42,
                        decoration: BoxDecoration(
                          color: AppColors.black40,
                          border: Border(
                            top: BorderSide(
                              color: AppColors.green.withValues(alpha: 0.5),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text.rich(
            TextSpan(
              text: l10n.settingsDemoCurrent(''),
              children: [
                TextSpan(
                  text: l10n.settingsDemoFile,
                  style: const TextStyle(color: AppColors.green),
                ),
              ],
            ),
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
      SettingsCategory.audio => _MeterPreview(
        label: l10n.settingsAudio,
        value: settings.masterVolume,
        secondaryValue: settings.musicVolume,
      ),
      SettingsCategory.display => _TypographyPreview(settings: settings),
      SettingsCategory.interface => _GlowPreview(settings: settings),
      SettingsCategory.device => _QrPreview(label: l10n.settingsDeviceName),
      SettingsCategory.language => _LanguagePreview(),
      SettingsCategory.songManagement => _StatusPreview(
        icon: AppIcons.movie,
        title: l10n.settingsSongManagement,
        subtitle: l10n.settingsManagementHint,
      ),
      SettingsCategory.account => _StatusPreview(
        icon: AppIcons.account,
        title: l10n.settingsAccountName,
        subtitle: l10n.settingsAccountHint,
      ),
      SettingsCategory.system => _StatusPreview(
        icon: AppIcons.settings,
        title: l10n.settingsSystem,
        subtitle: l10n.settingsSystemHint,
      ),
      SettingsCategory.info => _StatusPreview(
        icon: AppIcons.info,
        title: l10n.settingsAppVersion,
        subtitle: l10n.settingsInfoHint,
      ),
    };
  }
}

class _GuideBody extends StatelessWidget {
  const _GuideBody({required this.settings});

  final AppSettings settings;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    if (settings.selectedCategory == SettingsCategory.video) {
      return LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: (constraints.maxWidth / 2.6).clamp(72.0, 150.0),
                width: double.infinity,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    border: Border.all(color: AppColors.panelBorder),
                  ),
                  child: Center(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        l10n.settingsOsdTextValue.toUpperCase(),
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.displaySmall
                            ?.copyWith(
                              color: AppColors.textPrimary,
                              shadows: [
                                const Shadow(
                                  color: AppColors.red,
                                  blurRadius: 16,
                                ),
                                Shadow(
                                  color: AppColors.purple.withValues(
                                    alpha: 0.9,
                                  ),
                                  blurRadius: 24,
                                ),
                              ],
                            ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(l10n.settingsOsdDescription),
              const SizedBox(height: AppSpacing.sm),
              Text(l10n.settingsVideoGuide),
            ],
          ),
        ),
      );
    }

    final text = switch (settings.selectedCategory) {
      SettingsCategory.device => l10n.settingsDeviceHint,
      SettingsCategory.audio => l10n.settingsAudioHint,
      SettingsCategory.display => l10n.settingsDisplayHint,
      SettingsCategory.interface => l10n.settingsInterfaceHint,
      SettingsCategory.language => l10n.settingsInterfaceHint,
      SettingsCategory.songManagement => l10n.settingsManagementHint,
      SettingsCategory.account => l10n.settingsAccountHint,
      SettingsCategory.system => l10n.settingsSystemHint,
      SettingsCategory.info => l10n.settingsInfoHint,
      SettingsCategory.video => l10n.settingsVideoGuide,
    };

    return Center(
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodyMedium,
      ),
    );
  }
}

class _MeterPreview extends StatelessWidget {
  const _MeterPreview({
    required this.label,
    required this.value,
    required this.secondaryValue,
  });

  final String label;
  final double value;
  final double secondaryValue;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: SizedBox(
          width: 260,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(AppIcons.volumeUp, size: 48, color: AppColors.orange),
              const SizedBox(height: AppSpacing.sm),
              Text(label, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: AppSpacing.md),
              _LevelBar(value: value, color: AppColors.green),
              const SizedBox(height: AppSpacing.sm),
              _LevelBar(value: secondaryValue, color: AppColors.orange),
            ],
          ),
        ),
      ),
    );
  }
}

class _LevelBar extends StatelessWidget {
  const _LevelBar({required this.value, required this.color});

  final double value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.pill),
      child: LinearProgressIndicator(
        minHeight: 10,
        value: value,
        backgroundColor: AppColors.keyFill,
        color: color,
      ),
    );
  }
}

class _TypographyPreview extends StatelessWidget {
  const _TypographyPreview({required this.settings});

  final AppSettings settings;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        'KARAOKE',
        style: Theme.of(context).textTheme.displaySmall?.copyWith(
          fontSize: 28 + settings.lyricScale * 20,
          color: AppColors.green,
          shadows: settings.visualizerEnabled
              ? [const Shadow(color: AppColors.green, blurRadius: 12)]
              : null,
        ),
      ),
    );
  }
}

class _GlowPreview extends StatelessWidget {
  const _GlowPreview({required this.settings});

  final AppSettings settings;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 160,
        height: 86,
        decoration: BoxDecoration(
          color: AppColors.green.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: AppColors.green),
          boxShadow: [
            BoxShadow(
              color: AppColors.green.withValues(alpha: settings.glowLevel),
              // Capped at 16 (was 36): a wide gaussian re-rasterized on every
              // slider frame is the costliest thing on this preview.
              blurRadius: 16,
            ),
          ],
        ),
        child: const Icon(AppIcons.palette, color: AppColors.green, size: 42),
      ),
    );
  }
}

class _QrPreview extends StatelessWidget {
  const _QrPreview({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 128,
              height: 128,
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: AppColors.textPrimary,
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: GridView.count(
                crossAxisCount: 7,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  for (var index = 0; index < 49; index++)
                    ColoredBox(
                      color: index.isEven || index % 5 == 0
                          ? AppColors.background
                          : AppColors.textPrimary,
                    ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(label, style: Theme.of(context).textTheme.titleMedium),
          ],
        ),
      ),
    );
  }
}

class _LanguagePreview extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('VI', style: TextStyle(fontSize: 28)),
          SizedBox(width: AppSpacing.lg),
          Text('EN', style: TextStyle(fontSize: 28)),
        ],
      ),
    );
  }
}

class _StatusPreview extends StatelessWidget {
  const _StatusPreview({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: SizedBox(
          width: 300,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 48, color: AppColors.green),
              const SizedBox(height: AppSpacing.sm),
              Text(
                title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PalmSilhouettePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.background.withValues(alpha: 0.62)
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;

    for (final x in [size.width * 0.18, size.width * 0.78]) {
      canvas.drawLine(
        Offset(x, size.height),
        Offset(x + 18, size.height * 0.28),
        paint,
      );
      final crown = Offset(x + 18, size.height * 0.28);
      for (var i = -2; i <= 2; i++) {
        canvas.drawLine(
          crown,
          crown + Offset(i * 24, -30 + i.abs() * 8),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
