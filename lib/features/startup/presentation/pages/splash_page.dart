import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/shared/widgets/karaoke_shell.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_icons.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../l10n/l10n.dart';
import '../../../../routes/app_router.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(const Duration(seconds: 2), () {
      if (!mounted) {
        return;
      }
      Navigator.of(context).pushReplacementNamed(AppRouter.license);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return KaraokeShell(
      topBar: const SizedBox.shrink(),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(AppIcons.musicNote, color: AppColors.green, size: 86),
            const SizedBox(height: AppSpacing.lg),
            Text(
              context.l10n.splashTagline,
              textAlign: TextAlign.center,
              style: textTheme.titleLarge?.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            SizedBox(
              width: 420,
              child: LinearProgressIndicator(
                value: 0.72,
                minHeight: 4,
                backgroundColor: AppColors.panelBorderSoft,
                color: AppColors.green,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(context.l10n.splashPreparing, style: textTheme.bodyMedium),
          ],
        ),
      ),
      bottomBar: const SizedBox.shrink(),
    );
  }
}
