import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/volume_provider.dart';
import '../../../../core/shared/widgets/liquid_glass.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_icons.dart';
import '../../../../core/theme/app_layout.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../settings/presentation/providers/settings_controller.dart';

/// Step used by the remote's arrows while the popup is open.
const double _volumeStep = 0.05;

/// Finds the floating slider in tests.
const Key volumeSliderPopupKey = ValueKey('volumeSliderPopup');

/// Volume control at the foot of the rail.
///
/// Just the speaker icon and the level; activating it floats a slider popup
/// directly above the icon. The popup is an overlay rather than an inline
/// expansion so opening it never changes the rail's layout — on a karaoke
/// screen the destinations must not shift under the user's finger.
///
/// Its own widget rather than a `NavRailItem` built inside `MainNavRail`: the
/// level changes on every step (including the hardware keys), and watching
/// `volumeProvider` up in the rail would rebuild all eight destinations each
/// time.
class VolumeRailEntry extends ConsumerStatefulWidget {
  const VolumeRailEntry({super.key});

  @override
  ConsumerState<VolumeRailEntry> createState() => _VolumeRailEntryState();
}

class _VolumeRailEntryState extends ConsumerState<VolumeRailEntry> {
  final OverlayPortalController _popup = OverlayPortalController();
  final LayerLink _link = LayerLink();
  bool _focused = false;

  void _toggle(bool enabled) {
    if (!enabled) {
      return;
    }
    setState(_popup.toggle);
  }

  @override
  Widget build(BuildContext context) {
    final volume = ref.watch(volumeProvider);
    // Writes through the settings controller rather than straight to
    // volumeProvider so the level is persisted and Settings → Âm thanh shows
    // the same number; that controller pushes it to the device itself.
    final setLevel = ref
        .read(settingsControllerProvider.notifier)
        .setMasterVolume;
    final enabled = volume.isAvailable;

    void nudge(int direction) {
      if (!enabled) {
        return;
      }
      setLevel((volume.level + direction * _volumeStep).clamp(0.0, 1.0));
    }

    return CompositedTransformTarget(
      link: _link,
      child: OverlayPortal(
        controller: _popup,
        overlayChildBuilder: (context) => _VolumePopupLayer(
          link: _link,
          level: volume.level,
          percent: volume.percent,
          onChanged: setLevel,
          onNudge: nudge,
          onDismiss: () => setState(_popup.hide),
        ),
        child: FocusableActionDetector(
          onFocusChange: (value) {
            if (_focused != value) {
              setState(() => _focused = value);
            }
          },
          shortcuts: const {
            SingleActivator(LogicalKeyboardKey.enter): _ToggleIntent(),
            SingleActivator(LogicalKeyboardKey.space): _ToggleIntent(),
            SingleActivator(LogicalKeyboardKey.select): _ToggleIntent(),
          },
          actions: {
            _ToggleIntent: CallbackAction<_ToggleIntent>(
              onInvoke: (intent) {
                _toggle(enabled);
                return null;
              },
            ),
          },
          mouseCursor: enabled
              ? SystemMouseCursors.click
              : SystemMouseCursors.basic,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => _toggle(enabled),
            child: _VolumeButton(
              level: volume.level,
              percent: volume.percent,
              enabled: enabled,
              active: _focused || _popup.isShowing,
            ),
          ),
        ),
      ),
    );
  }
}

/// The rail row itself: speaker icon over the level, sized and styled to match
/// a destination.
class _VolumeButton extends StatelessWidget {
  const _VolumeButton({
    required this.level,
    required this.percent,
    required this.enabled,
    required this.active,
  });

  final double level;
  final int percent;
  final bool enabled;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final color = !enabled
        ? AppColors.textMuted
        : active
        ? AppColors.green
        : AppColors.textSecondary;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xxs),
      child: SizedBox(
        height: AppLayout.navRailItemHeight,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              volumeIconFor(level, enabled),
              size: AppLayout.navRailIconSize,
              color: color,
            ),
            const SizedBox(height: 2),
            Text(
              '$percent%',
              maxLines: 1,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                fontSize: 13,
                letterSpacing: 0.2,
                fontWeight: active ? FontWeight.w700 : FontWeight.w600,
                color: active ? AppColors.textPrimary : color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

IconData volumeIconFor(double level, bool enabled) {
  if (!enabled || level <= 0) {
    return AppIcons.volumeOff;
  }
  return level < 0.5 ? AppIcons.volumeDown : AppIcons.volumeUp;
}

/// Overlay contents: a dismiss barrier plus the slider pinned above the icon.
class _VolumePopupLayer extends StatelessWidget {
  const _VolumePopupLayer({
    required this.link,
    required this.level,
    required this.percent,
    required this.onChanged,
    required this.onNudge,
    required this.onDismiss,
  });

  final LayerLink link;
  final double level;
  final int percent;
  final ValueChanged<double> onChanged;
  final ValueChanged<int> onNudge;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Tap anywhere else to close. Transparent, not dimmed: the popup is a
        // small inline control, and dimming the stage mid-song is jarring.
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onDismiss,
            child: const SizedBox.expand(),
          ),
        ),
        CompositedTransformFollower(
          link: link,
          // Bottom of the popup meets the top of the icon.
          targetAnchor: Alignment.topCenter,
          followerAnchor: Alignment.bottomCenter,
          offset: const Offset(0, -AppSpacing.xs),
          child: _VolumePopup(
            level: level,
            percent: percent,
            onChanged: onChanged,
            onNudge: onNudge,
            onDismiss: onDismiss,
          ),
        ),
      ],
    );
  }
}

class _VolumePopup extends StatelessWidget {
  const _VolumePopup({
    required this.level,
    required this.percent,
    required this.onChanged,
    required this.onNudge,
    required this.onDismiss,
  });

  final double level;
  final int percent;
  final ValueChanged<double> onChanged;
  final ValueChanged<int> onNudge;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    // The overlay sits above the Scaffold's Material, so descendants have no
    // default text style or ink surface of their own.
    return Material(
      key: volumeSliderPopupKey,
      type: MaterialType.transparency,
      child: FocusableActionDetector(
        autofocus: true,
        // Focus is inside the popup, so up/down are free here — the natural
        // direction for a vertical bar — and both pairs are accepted.
        shortcuts: const {
          SingleActivator(LogicalKeyboardKey.arrowUp): _AdjustIntent(1),
          SingleActivator(LogicalKeyboardKey.arrowDown): _AdjustIntent(-1),
          SingleActivator(LogicalKeyboardKey.arrowRight): _AdjustIntent(1),
          SingleActivator(LogicalKeyboardKey.arrowLeft): _AdjustIntent(-1),
          SingleActivator(LogicalKeyboardKey.enter): _DismissPopupIntent(),
          SingleActivator(LogicalKeyboardKey.select): _DismissPopupIntent(),
          SingleActivator(LogicalKeyboardKey.escape): _DismissPopupIntent(),
        },
        actions: {
          _AdjustIntent: CallbackAction<_AdjustIntent>(
            onInvoke: (intent) {
              onNudge(intent.direction);
              return null;
            },
          ),
          _DismissPopupIntent: CallbackAction<_DismissPopupIntent>(
            onInvoke: (intent) {
              onDismiss();
              return null;
            },
          ),
        },
        child: LiquidGlass(
          radius: AppRadius.md,
          opacity: 0.9,
          rimColor: AppColors.green,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xs,
            vertical: AppSpacing.sm,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$percent%',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.green,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              _VerticalTrack(level: level, onChanged: onChanged),
            ],
          ),
        ),
      ),
    );
  }
}

/// Drag target: full at the top, silent at the bottom.
class _VerticalTrack extends StatelessWidget {
  const _VerticalTrack({required this.level, required this.onChanged});

  final double level;
  final ValueChanged<double> onChanged;

  static const double _height = AppLayout.navRailVolumeTrackHeight;

  @override
  Widget build(BuildContext context) {
    final ratio = level.clamp(0.0, 1.0);

    void setFrom(double dy) => onChanged((1 - dy / _height).clamp(0.0, 1.0));

    // A raw Listener, not a GestureDetector: a drag recognizer here loses the
    // gesture arena to any scrollable ancestor, so it would only ever see the
    // initial touch — the bar jumped to wherever you pressed, then ignored the
    // drag. Pointer events are delivered regardless of the arena.
    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: (event) => setFrom(event.localPosition.dy),
      onPointerMove: (event) => setFrom(event.localPosition.dy),
      child: SizedBox(
        // Wider than the painted bar so the drag target stays reachable by
        // touch on a car screen.
        width: 40,
        height: _height,
        child: Center(
          child: SizedBox(
            width: 12,
            child: Stack(
              alignment: Alignment.bottomCenter,
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.keyFill,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                ),
                FractionallySizedBox(
                  heightFactor: ratio,
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.green,
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.green.withValues(alpha: 0.5),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ToggleIntent extends Intent {
  const _ToggleIntent();
}

class _DismissPopupIntent extends Intent {
  const _DismissPopupIntent();
}

class _AdjustIntent extends Intent {
  const _AdjustIntent(this.direction);

  final int direction;
}
