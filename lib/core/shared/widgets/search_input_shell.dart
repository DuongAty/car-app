import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_icons.dart';
import '../../theme/app_motion.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_spacing.dart';
import 'liquid_glass.dart';

/// Pill-shaped search field. It displays the query built by the on-screen
/// keyboard rather than hosting a native text input.
class SearchInputShell extends StatelessWidget {
  const SearchInputShell({
    super.key,
    required this.value,
    required this.placeholder,
    required this.onMicTap,
    required this.onTap,
    required this.voiceSearchTooltip,
    required this.stopVoiceSearchTooltip,
    this.isFocused = false,
    this.isListening = false,
    this.hasVoiceSearchError = false,
  });

  final String value;
  final String placeholder;
  final VoidCallback onMicTap;
  final VoidCallback onTap;
  final String voiceSearchTooltip;
  final String stopVoiceSearchTooltip;
  final bool isFocused;
  final bool isListening;
  final bool hasVoiceSearchError;

  @override
  Widget build(BuildContext context) {
    final isEmpty = value.isEmpty;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.pill),
      child: LiquidGlass(
        capsule: true,
        opacity: 0.40,
        tint: isFocused ? AppColors.green : null,
        tintStrength: 0.12,
        rimWidth: isFocused ? 1.5 : 1,
        rimColor: isFocused ? AppColors.green : AppColors.glassBorder,
        padding: const EdgeInsets.only(
          left: AppSpacing.lg,
          right: AppSpacing.sm,
        ),
        child: Row(
          children: [
            Icon(AppIcons.search, color: AppColors.textSecondary, size: 26),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                isEmpty ? placeholder : value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: isEmpty ? AppColors.textMuted : AppColors.textPrimary,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            Tooltip(
              message: isListening
                  ? stopVoiceSearchTooltip
                  : voiceSearchTooltip,
              child: InkWell(
                onTap: onMicTap,
                customBorder: const CircleBorder(),
                child: AnimatedContainer(
                  duration: AppMotion.control,
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isListening
                        ? AppColors.green
                        : hasVoiceSearchError
                        ? AppColors.red.withValues(alpha: 0.85)
                        : null,
                    border: Border.all(
                      color: isListening
                          ? AppColors.green
                          : hasVoiceSearchError
                          ? AppColors.red
                          : AppColors.white10,
                      width: isListening || hasVoiceSearchError ? 2 : 1,
                    ),
                    boxShadow: isListening || hasVoiceSearchError
                        ? [
                            BoxShadow(
                              color:
                                  (isListening
                                          ? AppColors.green
                                          : AppColors.red)
                                      .withValues(alpha: 0.72),
                              blurRadius: 18,
                              spreadRadius: 2,
                            ),
                          ]
                        : null,
                  ),
                  child: Icon(
                    hasVoiceSearchError
                        ? AppIcons.microphoneOff
                        : AppIcons.microphone,
                    color: isListening || hasVoiceSearchError
                        ? AppColors.background
                        : AppColors.textSecondary,
                    size: 24,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
