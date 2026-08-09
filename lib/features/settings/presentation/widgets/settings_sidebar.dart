import 'package:flutter/material.dart';

import '../../../../core/shared/widgets/focusable_tile.dart';
import '../../../../core/shared/widgets/panel_frame.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_glows.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../l10n/l10n.dart';
import '../../data/models/app_settings.dart';
import 'settings_copy.dart';

class SettingsSidebar extends StatelessWidget {
  const SettingsSidebar({
    super.key,
    required this.selectedCategory,
    required this.onSelected,
  });

  final SettingsCategory selectedCategory;
  final ValueChanged<SettingsCategory> onSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return PanelFrame(
      title: l10n.topSettings,
      padding: const EdgeInsets.all(AppSpacing.sm),
      opacity: 0.48,
      child: ListView.separated(
        padding: EdgeInsets.zero,
        itemCount: SettingsCategory.values.length,
        separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.xs),
        itemBuilder: (context, index) {
          final category = SettingsCategory.values[index];
          return _SidebarItem(
            category: category,
            selected: category == selectedCategory,
            onPressed: () => onSelected(category),
          );
        },
      ),
    );
  }
}

class _SidebarItem extends StatelessWidget {
  const _SidebarItem({
    required this.category,
    required this.selected,
    required this.onPressed,
  });

  final SettingsCategory category;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final accent = settingsCategoryAccent(category);

    return FocusableTile(
      onPressed: onPressed,
      builder: (context, focused) {
        final active = selected || focused;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.xs,
          ),
          decoration: BoxDecoration(
            color: active ? accent.withValues(alpha: 0.14) : Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadius.sm),
            border: Border.all(
              color: active ? accent : Colors.transparent,
              width: 1.3,
            ),
            boxShadow: active ? AppGlows.control(accent, focused: true) : null,
          ),
          child: Row(
            children: [
              Icon(
                settingsCategoryIcon(category),
                color: active ? AppColors.textPrimary : AppColors.textSecondary,
                size: 26,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  settingsCategoryLabel(context.l10n, category),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: active
                        ? AppColors.textPrimary
                        : AppColors.textSecondary,
                    fontWeight: active ? FontWeight.w700 : FontWeight.w500,
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
