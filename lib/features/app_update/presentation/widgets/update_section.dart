import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/shared/widgets/focusable_tile.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_glows.dart';
import '../../../../core/theme/app_icons.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../l10n/l10n.dart';
import '../providers/app_update_controller.dart';
import '../providers/app_update_state.dart';

/// The one place the user can ask whether a newer build exists. Nothing here
/// runs on its own: the app never checks at startup and never blocks on an
/// old version.
class UpdateSection extends ConsumerWidget {
  const UpdateSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appUpdateControllerProvider);
    final controller = ref.read(appUpdateControllerProvider.notifier);
    final busy =
        state.status == AppUpdateStatus.checking ||
        state.status == AppUpdateStatus.downloading ||
        state.status == AppUpdateStatus.verifying ||
        state.status == AppUpdateStatus.installing;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.panelStrong,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: AppColors.panelBorder),
      ),
      child: Row(
        children: [
          const Icon(AppIcons.info, color: AppColors.textSecondary),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_title(context, state) case final String title)
                  Text(
                    title,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: AppColors.textPrimary,
                    ),
                  ),
                if (_subtitle(context, state) case final String subtitle)
                  Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.xxs),
                    child: Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          if (busy)
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            _UpdateActionButton(
              label: _actionLabel(context, state),
              onPressed: () => _onPressed(controller, state),
            ),
        ],
      ),
    );
  }

  void _onPressed(AppUpdateController controller, AppUpdateState state) {
    if (state.status == AppUpdateStatus.available) {
      controller.downloadAndInstall();
      return;
    }
    // Once the installer has been handed the APK, this controller cannot
    // see how that went except through the platform's outcome callback.
    // `installRequested`, a later install error, and a dismissed
    // confirmation dialog (installCancelled) all retry the same way: reopen
    // the installer on the same verified file, never re-download.
    if (state.status == AppUpdateStatus.installRequested ||
        state.error == AppUpdateError.install ||
        state.error == AppUpdateError.installCancelled) {
      controller.reopenInstaller();
      return;
    }
    // Everything else — including a rejected package and a finished install —
    // falls through to a fresh check, so no state is a dead end.
    if (state.error == AppUpdateError.permission) {
      controller.openPermissionSettings();
      return;
    }
    controller.check();
  }

  /// Null in [AppUpdateStatus.idle]: the button already reads
  /// [l10n.settingsCheckUpdate] there, so a title saying the same thing
  /// would just repeat itself on the row.
  String? _title(BuildContext context, AppUpdateState state) {
    final l10n = context.l10n;
    return switch (state.status) {
      AppUpdateStatus.checking => l10n.settingsUpdateChecking,
      AppUpdateStatus.upToDate => l10n.settingsUpdateUpToDate,
      AppUpdateStatus.available => l10n.settingsUpdateAvailable(
        state.release?.versionName ?? '',
      ),
      // The server may omit Content-Length, in which case the downloader
      // never reports progress and `progress` stays 0 for the whole
      // download — sometimes several minutes on a ~145MB file. Showing
      // "0%" the entire time reads as frozen, so fall back to an
      // indeterminate label until real progress arrives.
      AppUpdateStatus.downloading =>
        state.progress <= 0
            ? l10n.settingsUpdateDownloadingIndeterminate
            : l10n.settingsUpdateDownloading((state.progress * 100).round()),
      AppUpdateStatus.verifying => l10n.settingsUpdateVerifying,
      AppUpdateStatus.installing => l10n.settingsUpdateInstalling,
      // Honest about what we know: the installer was opened, not that the
      // install succeeded — this controller has no way to observe that.
      AppUpdateStatus.installRequested =>
        l10n.settingsUpdateInstallRequestedTitle,
      // Only reachable because the platform reported STATUS_SUCCESS — never
      // guessed. A self-update usually replaces the process before this
      // lands, so seeing it at all is the exception.
      AppUpdateStatus.installed => l10n.settingsUpdateInstalledTitle,
      AppUpdateStatus.error => _errorMessage(context, state.error),
      AppUpdateStatus.idle => null,
    };
  }

  String? _subtitle(BuildContext context, AppUpdateState state) {
    if (state.status == AppUpdateStatus.installRequested) {
      return context.l10n.settingsUpdateInstallRequestedSubtitle;
    }
    if (state.status == AppUpdateStatus.installed) {
      return context.l10n.settingsUpdateInstalledSubtitle;
    }
    if (state.status != AppUpdateStatus.available) {
      return null;
    }
    final notes = state.release?.notes;
    return (notes == null || notes.isEmpty) ? null : notes;
  }

  String _actionLabel(BuildContext context, AppUpdateState state) {
    final l10n = context.l10n;
    if (state.status == AppUpdateStatus.available) {
      return l10n.settingsUpdateInstall;
    }
    // Reusing the verified file already on disk, not downloading again —
    // "Reinstall" says that plainly instead of implying another 145MB pull.
    if (state.status == AppUpdateStatus.installRequested ||
        state.error == AppUpdateError.install ||
        state.error == AppUpdateError.installCancelled) {
      return l10n.settingsUpdateReinstall;
    }
    if (state.error == AppUpdateError.permission) {
      return l10n.settingsUpdateOpenPermission;
    }
    // The system rejected the package itself, so there is nothing to retry on
    // this file — the only useful move is looking for a different build.
    if (state.error == AppUpdateError.installRejected) {
      return l10n.settingsCheckUpdate;
    }
    if (state.status == AppUpdateStatus.error) {
      return l10n.settingsUpdateRetry;
    }
    return l10n.settingsCheckUpdate;
  }

  String _errorMessage(BuildContext context, AppUpdateError error) {
    final l10n = context.l10n;
    return switch (error) {
      AppUpdateError.network => l10n.settingsUpdateErrorNetwork,
      AppUpdateError.download => l10n.settingsUpdateErrorDownload,
      AppUpdateError.checksum => l10n.settingsUpdateErrorChecksum,
      AppUpdateError.install => l10n.settingsUpdateErrorInstall,
      AppUpdateError.installRejected => l10n.settingsUpdateErrorInstallRejected,
      AppUpdateError.installCancelled =>
        l10n.settingsUpdateErrorInstallCancelled,
      AppUpdateError.permission => l10n.settingsUpdateErrorPermission,
      AppUpdateError.none => l10n.settingsCheckUpdate,
    };
  }
}

/// The row's single action button. A bare `FilledButton` here only gets
/// Material's default focus overlay — a faint tint that reads as invisible
/// on a remote from across the room. [FocusableTile] reports real focus so
/// the focused state can use a visibly brighter border and a restrained
/// glow, matching the focus treatment used everywhere else in Settings (see
/// `_LanguageTile`/`_QualityTile` in `settings_content_panel.dart`).
class _UpdateActionButton extends StatelessWidget {
  const _UpdateActionButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return FocusableTile(
      onPressed: onPressed,
      builder: (context, focused) {
        return Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            color: AppColors.green,
            borderRadius: BorderRadius.circular(AppRadius.sm),
            border: Border.all(
              color: focused ? AppColors.textPrimary : AppColors.green,
              width: focused ? 2 : 1,
            ),
            boxShadow: AppGlows.control(AppColors.green, focused: focused),
          ),
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: AppColors.background,
              fontWeight: FontWeight.w700,
            ),
          ),
        );
      },
    );
  }
}
