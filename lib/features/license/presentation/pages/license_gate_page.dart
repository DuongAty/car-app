import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';

import '../../../../core/shared/widgets/focusable_tile.dart';
import '../../../../core/shared/widgets/karaoke_shell.dart';
import '../../../../core/shared/widgets/liquid_glass.dart';
import '../../../../core/shared/widgets/panel_frame.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_glows.dart';
import '../../../../core/theme/app_icons.dart';
import '../../../../core/theme/app_layout.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../l10n/l10n.dart';
import '../providers/license_controller.dart';
import '../providers/license_gate_state.dart';

/// Gate shown right after the splash screen. Blocks entry into the app until
/// this device has a key the server confirms as `dang_kich_hoat` for it.
class LicenseGatePage extends ConsumerWidget {
  const LicenseGatePage({super.key, required this.onUnlocked});

  /// Called exactly once, the moment the controller reaches
  /// [LicenseGateStatus.active].
  final VoidCallback onUnlocked;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen<LicenseGateState>(licenseControllerProvider, (previous, next) {
      final wasActive = previous?.status == LicenseGateStatus.active;
      if (next.status == LicenseGateStatus.active && !wasActive) {
        onUnlocked();
      }
    });

    final state = ref.watch(licenseControllerProvider);
    final l10n = context.l10n;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          FocusManager.instance.primaryFocus?.unfocus();
        }
      },
      child: KaraokeShell(
        topBar: const SizedBox.shrink(),
        body: switch (state.status) {
          LicenseGateStatus.needsKey => _NeedsKeyBody(state: state),
          LicenseGateStatus.pending => _StatusPanel(
            icon: AppIcons.pending,
            iconColor: AppColors.fire,
            title: l10n.licensePendingTitle,
            subtitle: l10n.licensePendingSubtitle,
            keyCode: state.activeKeyCode,
            showSpinner: true,
            actions: [
              _ActionButton(
                label: l10n.licenseChangeKey,
                onPressed: () =>
                    ref.read(licenseControllerProvider.notifier).changeKey(),
              ),
            ],
          ),
          LicenseGateStatus.locked => _StatusPanel(
            icon: AppIcons.lock,
            iconColor: AppColors.red,
            title: l10n.licenseLockedTitle,
            subtitle: l10n.licenseLockedSubtitle,
            keyCode: state.activeKeyCode,
            actions: [
              _ActionButton(
                label: l10n.licenseRetry,
                onPressed: () =>
                    ref.read(licenseControllerProvider.notifier).retry(),
              ),
              _ActionButton(
                label: l10n.licenseChangeKey,
                onPressed: () =>
                    ref.read(licenseControllerProvider.notifier).changeKey(),
              ),
            ],
          ),
          LicenseGateStatus.expired => _StatusPanel(
            icon: AppIcons.timer,
            iconColor: AppColors.red,
            title: l10n.licenseExpiredTitle,
            subtitle: l10n.licenseExpiredSubtitle,
            keyCode: state.activeKeyCode,
            actions: [
              _ActionButton(
                label: l10n.licenseRetry,
                onPressed: () =>
                    ref.read(licenseControllerProvider.notifier).retry(),
              ),
              _ActionButton(
                label: l10n.licenseChangeKey,
                onPressed: () =>
                    ref.read(licenseControllerProvider.notifier).changeKey(),
              ),
            ],
          ),
          LicenseGateStatus.offlineRetry => _StatusPanel(
            icon: AppIcons.wifiOff,
            iconColor: AppColors.textSecondary,
            title: l10n.licenseOfflineTitle,
            subtitle: l10n.licenseOfflineSubtitle,
            keyCode: null,
            actions: [
              _ActionButton(
                label: l10n.licenseRetry,
                onPressed: () =>
                    ref.read(licenseControllerProvider.notifier).retry(),
              ),
              _ActionButton(
                label: l10n.licenseChangeKey,
                onPressed: () =>
                    ref.read(licenseControllerProvider.notifier).changeKey(),
              ),
            ],
          ),
          LicenseGateStatus.checking ||
          LicenseGateStatus.active => _StatusPanel(
            icon: AppIcons.key,
            iconColor: AppColors.green,
            title: l10n.licenseCheckingMessage,
            subtitle: null,
            keyCode: null,
            showSpinner: true,
            actions: const [],
          ),
        },
        bottomBar: const SizedBox.shrink(),
      ),
    );
  }
}

class _NeedsKeyBody extends ConsumerStatefulWidget {
  const _NeedsKeyBody({required this.state});

  final LicenseGateState state;

  @override
  ConsumerState<_NeedsKeyBody> createState() => _NeedsKeyBodyState();
}

class _NeedsKeyBodyState extends ConsumerState<_NeedsKeyBody> {
  late final TextEditingController _keyController;
  late final TextEditingController _userNameController;

  @override
  void initState() {
    super.initState();
    _keyController = TextEditingController(text: widget.state.enteredKey);
    _userNameController = TextEditingController(
      text: widget.state.enteredUserName,
    );
  }

  @override
  void didUpdateWidget(covariant _NeedsKeyBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncController(_keyController, widget.state.enteredKey);
    _syncController(_userNameController, widget.state.enteredUserName);
  }

  @override
  void dispose() {
    _keyController.dispose();
    _userNameController.dispose();
    super.dispose();
  }

  void _syncController(TextEditingController controller, String value) {
    if (controller.text == value) return;
    controller.value = TextEditingValue(
      text: value,
      selection: TextSelection.collapsed(offset: value.length),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final errorText = switch (widget.state.inputError) {
      LicenseInputError.none => null,
      LicenseInputError.missingUserName =>
        'Nhập tên người dùng trước khi kích hoạt.',
      LicenseInputError.notFound => l10n.licenseErrorNotFound,
      LicenseInputError.activeOther => l10n.licenseErrorActiveOther,
      LicenseInputError.network => l10n.licenseErrorNetwork,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.licenseInputTitle,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          l10n.licenseInputSubtitle,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: AppSpacing.md),
        SizedBox(
          height: AppLayout.browserSearchHeight,
          child: TextField(
            key: const ValueKey('licenseUserNameField'),
            controller: _userNameController,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
            onChanged: (value) => ref
                .read(licenseControllerProvider.notifier)
                .updateEnteredUserName(value),
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(color: AppColors.textPrimary),
            decoration: InputDecoration(
              labelText: 'Tên người dùng',
              hintText: 'Nhập tên để quản lý key',
              prefixIcon: const Icon(AppIcons.account),
              filled: true,
              fillColor: AppColors.panelStrong,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.md,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.pill),
                borderSide: const BorderSide(color: AppColors.glassBorder),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.pill),
                borderSide: const BorderSide(
                  color: AppColors.green,
                  width: 1.5,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        SizedBox(
          height: AppLayout.browserSearchHeight,
          child: TextField(
            key: const ValueKey('licenseNativeKeyField'),
            controller: _keyController,
            textCapitalization: TextCapitalization.characters,
            textInputAction: TextInputAction.done,
            keyboardType: TextInputType.text,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9-]')),
              _UpperCaseTextFormatter(),
            ],
            onChanged: (value) => ref
                .read(licenseControllerProvider.notifier)
                .updateEnteredKey(value),
            onSubmitted: (_) =>
                ref.read(licenseControllerProvider.notifier).submitKey(),
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: AppColors.textPrimary,
              letterSpacing: 2,
            ),
            decoration: InputDecoration(
              hintText: l10n.licenseInputPlaceholder,
              prefixIcon: const Icon(AppIcons.key),
              filled: true,
              fillColor: AppColors.panelStrong,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.md,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.pill),
                borderSide: const BorderSide(color: AppColors.glassBorder),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.pill),
                borderSide: const BorderSide(
                  color: AppColors.green,
                  width: 1.5,
                ),
              ),
            ),
          ),
        ),
        if (errorText != null) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            errorText,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppColors.red),
          ),
        ],
        const Spacer(),
        Center(
          child: _ActionButton(
            label: l10n.licenseKeyboardSubmit,
            onPressed: () =>
                ref.read(licenseControllerProvider.notifier).submitKey(),
          ),
        ),
        const Spacer(),
      ],
    );
  }
}

class _UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return newValue.copyWith(text: newValue.text.toUpperCase());
  }
}

class _StatusPanel extends StatelessWidget {
  const _StatusPanel({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.keyCode,
    this.showSpinner = false,
    this.actions = const [],
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String? subtitle;
  final String? keyCode;
  final bool showSpinner;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: PanelFrame(
          opacity: 0.62,
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: iconColor, size: 64),
              const SizedBox(height: AppSpacing.lg),
              Text(
                title,
                textAlign: TextAlign.center,
                style: textTheme.titleLarge?.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: AppSpacing.xs),
                Text(
                  subtitle!,
                  textAlign: TextAlign.center,
                  style: textTheme.bodyMedium,
                ),
              ],
              if (keyCode != null) ...[
                const SizedBox(height: AppSpacing.md),
                Text(
                  keyCode!,
                  style: textTheme.titleMedium?.copyWith(
                    color: AppColors.textSecondary,
                    letterSpacing: 2,
                  ),
                ),
              ],
              if (showSpinner) ...[
                const SizedBox(height: AppSpacing.lg),
                const SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    color: AppColors.green,
                  ),
                ),
              ],
              if (actions.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.xl),
                Wrap(
                  spacing: AppSpacing.md,
                  runSpacing: AppSpacing.sm,
                  alignment: WrapAlignment.center,
                  children: actions,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return FocusableTile(
      onPressed: onPressed,
      builder: (context, focused) {
        return AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.pill),
            boxShadow: AppGlows.control(AppColors.green, focused: focused),
          ),
          child: LiquidGlass(
            capsule: true,
            tint: focused ? AppColors.green : null,
            tintStrength: 0.28,
            opacity: 0.5,
            rimWidth: focused ? 1.6 : 1,
            rimColor: focused ? AppColors.green : AppColors.glassBorder,
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.sm,
            ),
            child: Text(
              label,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        );
      },
    );
  }
}
