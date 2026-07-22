import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_spacing.dart';

/// Speaker icon, current level, and a draggable fill bar wired to the device
/// media volume.
///
/// Touch drags the track; when focused, left/right adjust it by [_keyStep] so
/// the control is reachable from a remote.
class VolumeIndicator extends StatelessWidget {
  const VolumeIndicator({
    super.key,
    required this.level,
    required this.onChanged,
    this.enabled = true,
    this.trackWidth = 118,
  });

  /// Current volume from 0.0 to 1.0.
  final double level;
  final ValueChanged<double> onChanged;

  /// False when the platform reports no volume control; the bar renders dimmed
  /// and ignores input.
  final bool enabled;
  final double trackWidth;

  static const double _keyStep = 0.05;

  double _levelAt(double dx) => (dx / trackWidth).clamp(0.0, 1.0);

  @override
  Widget build(BuildContext context) {
    final ratio = level.clamp(0.0, 1.0);
    final tint = enabled ? AppColors.textPrimary : AppColors.textMuted;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(_iconFor(ratio), color: tint, size: 28),
        const SizedBox(width: AppSpacing.sm),
        SizedBox(
          width: 42,
          child: Text(
            '${(ratio * 100).round()}',
            style: Theme.of(
              context,
            ).textTheme.labelLarge?.copyWith(color: tint),
          ),
        ),
        const SizedBox(width: AppSpacing.xs),
        FocusableActionDetector(
          enabled: enabled,
          shortcuts: const {
            SingleActivator(LogicalKeyboardKey.arrowLeft): _AdjustIntent(-1),
            SingleActivator(LogicalKeyboardKey.arrowRight): _AdjustIntent(1),
          },
          actions: {
            _AdjustIntent: CallbackAction<_AdjustIntent>(
              onInvoke: (intent) {
                onChanged(
                  (level + intent.direction * _keyStep).clamp(0.0, 1.0),
                );
                return null;
              },
            ),
          },
          mouseCursor: enabled
              ? SystemMouseCursors.click
              : SystemMouseCursors.basic,
          child: Builder(
            builder: (context) {
              final focused = Focus.of(context).hasFocus;

              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapDown: enabled
                    ? (details) => onChanged(_levelAt(details.localPosition.dx))
                    : null,
                onHorizontalDragUpdate: enabled
                    ? (details) => onChanged(_levelAt(details.localPosition.dx))
                    : null,
                child: SizedBox(
                  width: trackWidth,
                  // Taller than the painted bar so the drag target is reachable.
                  height: 28,
                  child: Center(
                    child: _Track(
                      ratio: ratio,
                      enabled: enabled,
                      focused: focused,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  IconData _iconFor(double ratio) {
    if (ratio <= 0) {
      return Icons.volume_off_outlined;
    }
    if (ratio < 0.5) {
      return Icons.volume_down_outlined;
    }
    return Icons.volume_up_outlined;
  }
}

class _Track extends StatelessWidget {
  const _Track({
    required this.ratio,
    required this.enabled,
    required this.focused,
  });

  final double ratio;
  final bool enabled;
  final bool focused;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: focused ? 10 : 8,
      child: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              color: AppColors.keyFill,
              borderRadius: BorderRadius.circular(AppRadius.pill),
              border: focused
                  ? Border.all(color: AppColors.green, width: 1.5)
                  : null,
            ),
          ),
          FractionallySizedBox(
            widthFactor: ratio,
            child: Container(
              decoration: BoxDecoration(
                color: enabled ? AppColors.green : AppColors.textMuted,
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AdjustIntent extends Intent {
  const _AdjustIntent(this.direction);

  final int direction;
}
