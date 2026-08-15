import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/shared/widgets/focusable_tile.dart';
import '../../../../core/shared/widgets/karaoke_shell.dart';
import '../../../../core/shared/widgets/panel_frame.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_glows.dart';
import '../../../../core/theme/app_icons.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../l10n/l10n.dart';
import '../../../navigation/presentation/widgets/main_nav_rail.dart';
import '../../data/models/pairing_result.dart';
import '../providers/pairing_controller.dart';
import '../widgets/pairing_qr_view.dart';

/// Pairing screen, reached from Cài đặt → Kết nối thiết bị.
///
/// Landscape by construction: the QR sits beside the code and the connection
/// status rather than under them, because a head unit screen is wide and
/// short. Every focusable element is a [FocusableTile] so the whole flow is
/// reachable from a D-pad remote.
class PairingPage extends ConsumerWidget {
  const PairingPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;

    return KaraokeShell(
      navRail: const MainNavRail(selectedId: NavDestination.settings),
      body: PanelFrame(
        title: l10n.remotePairingTitle,
        leadingIcon: AppIcons.connectPhone,
        leadingIconColor: AppColors.blue,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: const [
            Expanded(flex: 3, child: _CodeColumn()),
            SizedBox(width: AppSpacing.xl),
            Expanded(flex: 2, child: _StatusColumn()),
          ],
        ),
      ),
    );
  }
}

/// QR + the six digits + the countdown. Only this column watches the code.
class _CodeColumn extends ConsumerWidget {
  const _CodeColumn();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final code = ref.watch(
      pairingControllerProvider.select((state) => state.code),
    );
    final isBusy = ref.watch(
      pairingControllerProvider.select((state) => state.isBusy),
    );
    final error = ref.watch(
      pairingControllerProvider.select((state) => state.error),
    );

    return SingleChildScrollView(
      physics: const ClampingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.remotePairingSubtitle,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: AppSpacing.lg),
          if (error != null)
            _ErrorBanner(message: _errorMessage(l10n, error))
          else if (code == null)
            _PlaceholderBlock(
              label: isBusy
                  ? l10n.remotePairingRequesting
                  : l10n.remotePairingExpired,
            )
          else
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                PairingQrView(data: pairingQrPayload(code)),
                const SizedBox(width: AppSpacing.xl),
                Expanded(child: _CodeBlock(code: code)),
              ],
            ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            l10n.remotePairingHint,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _CodeBlock extends StatelessWidget {
  const _CodeBlock({required this.code});

  final String code;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.remotePairingCodeLabel,
          style: theme.textTheme.titleMedium?.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            color: AppColors.panelStrong.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: AppColors.green, width: 1.5),
            boxShadow: AppGlows.control(AppColors.green, focused: true),
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              // Grouped 3+3: read aloud across a car cabin, six unbroken
              // digits are the easiest thing to mistype.
              '${code.substring(0, code.length ~/ 2)} '
              '${code.substring(code.length ~/ 2)}',
              style: theme.textTheme.displaySmall?.copyWith(
                color: AppColors.green,
                fontWeight: FontWeight.w900,
                letterSpacing: 8,
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        const _Countdown(),
        const SizedBox(height: AppSpacing.md),
        const _NewCodeButton(),
      ],
    );
  }
}

/// Leaf consumer for the one-second tick — nothing else on the page rebuilds
/// while the code counts down.
class _Countdown extends ConsumerWidget {
  const _Countdown();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final remaining = ref.watch(
      pairingControllerProvider.select((state) => state.remaining),
    );

    if (remaining <= Duration.zero) {
      return Text(
        l10n.remotePairingExpired,
        style: Theme.of(
          context,
        ).textTheme.bodyMedium?.copyWith(color: AppColors.fire),
      );
    }

    final minutes = remaining.inMinutes;
    final seconds = remaining.inSeconds % 60;
    return Text(
      l10n.remotePairingExpiresIn(
        '$minutes:${seconds.toString().padLeft(2, '0')}',
      ),
      style: Theme.of(context).textTheme.bodyMedium,
    );
  }
}

class _NewCodeButton extends ConsumerWidget {
  const _NewCodeButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isBusy = ref.watch(
      pairingControllerProvider.select((state) => state.isBusy),
    );

    return _ActionButton(
      icon: AppIcons.refresh,
      label: context.l10n.remotePairingNewCode,
      accent: AppColors.green,
      enabled: !isBusy,
      autofocus: true,
      onPressed: () =>
          ref.read(pairingControllerProvider.notifier).requestCode(),
    );
  }
}

/// Whether a phone is on the channel, plus the disconnect action.
class _StatusColumn extends ConsumerWidget {
  const _StatusColumn();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final state = ref.watch(pairingControllerProvider);
    final theme = Theme.of(context);

    final (icon, color, label) = switch ((state.isPaired, state.phoneOnline)) {
      (false, _) => (
        AppIcons.connectPhone,
        AppColors.textSecondary,
        l10n.remotePairingNotPaired,
      ),
      (true, true) => (
        AppIcons.checkCircle,
        AppColors.green,
        l10n.remotePairingPhoneConnected,
      ),
      (true, false) => (
        AppIcons.wifiOff,
        AppColors.textSecondary,
        l10n.remotePairingPhoneOffline,
      ),
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.remotePairingStatusTitle,
          style: theme.textTheme.titleMedium?.copyWith(
            color: AppColors.green,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.panelStrong.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(AppRadius.sm),
            border: Border.all(color: AppColors.panelBorderSoft),
          ),
          child: Row(
            children: [
              Icon(icon, color: color, size: 30),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  label,
                  style: theme.textTheme.titleMedium?.copyWith(color: color),
                ),
              ),
            ],
          ),
        ),
        if (state.isPaired) ...[
          const SizedBox(height: AppSpacing.lg),
          _ActionButton(
            icon: AppIcons.close,
            label: l10n.remotePairingDisconnect,
            accent: AppColors.red,
            enabled: !state.isBusy,
            onPressed: () =>
                ref.read(pairingControllerProvider.notifier).disconnectPhone(),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            l10n.remotePairingDisconnectHint,
            style: theme.textTheme.bodySmall,
          ),
        ],
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.accent,
    required this.onPressed,
    this.enabled = true,
    this.autofocus = false,
  });

  final IconData icon;
  final String label;
  final Color accent;
  final VoidCallback onPressed;
  final bool enabled;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    return FocusableTile(
      autofocus: autofocus,
      onPressed: enabled ? onPressed : () {},
      builder: (context, focused) {
        final active = focused && enabled;
        return Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            color: active
                ? accent.withValues(alpha: 0.16)
                : AppColors.panelStrong.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(AppRadius.sm),
            border: Border.all(
              color: active ? accent : AppColors.panelBorderSoft,
              width: active ? 1.5 : 1,
            ),
            boxShadow: AppGlows.control(accent, focused: active),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 24,
                color: enabled ? accent : AppColors.textMuted,
              ),
              const SizedBox(width: AppSpacing.sm),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: enabled
                        ? AppColors.textPrimary
                        : AppColors.textMuted,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _PlaceholderBlock extends StatelessWidget {
  const _PlaceholderBlock({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: 260,
          width: 260,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.panelStrong.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(AppRadius.sm),
            border: Border.all(color: AppColors.panelBorderSoft),
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        const _NewCodeButton(),
      ],
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.red.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(AppRadius.sm),
            border: Border.all(color: AppColors.red),
          ),
          child: Row(
            children: [
              const Icon(AppIcons.warning, color: AppColors.red, size: 28),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  message,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        const _NewCodeButton(),
      ],
    );
  }
}

String _errorMessage(AppLocalizations l10n, PairingFailureKind kind) =>
    switch (kind) {
      PairingFailureKind.network => l10n.remotePairingErrorNetwork,
      PairingFailureKind.backend => l10n.remotePairingErrorBackend,
      PairingFailureKind.malformed => l10n.remotePairingErrorMalformed,
    };
