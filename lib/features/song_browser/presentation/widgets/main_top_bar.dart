import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';

import '../../../../core/providers/locale_provider.dart';
import '../../../../core/services/app_system_service.dart';
import '../../../../core/shared/widgets/app_top_nav.dart';
import '../../../../core/shared/widgets/circle_icon_button.dart';
import '../../../../core/shared/widgets/language_toggle.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_icons.dart';
import '../../../../core/theme/app_layout.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../l10n/l10n.dart';
import '../../../../routes/app_router.dart';
import '../../../playback/presentation/providers/now_playing_controller.dart';
import '../../../queue/presentation/providers/queue_provider.dart';
import '../../../source_selection/data/mock/source_selection_mock_data.dart';
import '../../../source_selection/data/models/music_source.dart';
import '../../../source_selection/presentation/providers/source_selection_provider.dart';
import '../../../source_selection/presentation/widgets/source_badge.dart';
import '../../data/mock/song_browser_mock_data.dart';

class MainTopBar extends ConsumerWidget {
  const MainTopBar({
    super.key,
    required this.selectedIndex,
    this.currentSource,
    this.onSearchSelected,
    this.onCategorySelected,
    this.onOtherSelected,
  });

  final int? selectedIndex;
  final MusicSource? currentSource;
  final VoidCallback? onSearchSelected;
  final VoidCallback? onCategorySelected;
  final ValueChanged<int>? onOtherSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final locale = ref.watch(appLocaleProvider);
    final localeController = ref.read(appLocaleProvider.notifier);
    final queueCount = ref.watch(
      queueProvider.select((state) => state.items.length),
    );
    final activeSource = ref.watch(
      nowPlayingProvider.select((state) => state.activeSource),
    );
    final selectedSource = ref.watch(
      sourceSelectionProvider.select((state) => state.selectedSource),
    );

    return SizedBox(
      height: AppLayout.topNavItemHeight,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Row(
            children: [
              // Indicator only, not a control: excluded from focus/semantics
              // so it never becomes a D-pad stop.
              ExcludeSemantics(child: SourceMark(source: selectedSource)),
              const Spacer(),
              LanguageToggle(
                isVietnamese: locale.languageCode == 'vi',
                onToggle: localeController.toggle,
                compact: true,
              ),
              const SizedBox(width: AppSpacing.sm),
              CircleIconButton(
                icon: AppIcons.language,
                onPressed: localeController.toggle,
              ),
            ],
          ),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: AppTopNav(
              actions: SongBrowserMockData.topActions(l10n, queueCount),
              selectedIndex: selectedIndex,
              onSelected: (index) =>
                  _handleSelected(context, index, activeSource),
              spacing: AppSpacing.xl,
            ),
          ),
        ],
      ),
    );
  }

  void _handleSelected(
    BuildContext context,
    int index,
    MusicSourceLogoStyle activeSource,
  ) {
    switch (index) {
      case SongBrowserMockData.homeTabIndex:
        Navigator.of(context).popUntil((route) => route.isFirst);
      case SongBrowserMockData.searchTabIndex:
        if (onSearchSelected != null) {
          onSearchSelected!();
        } else {
          _openSongBrowser(context, activeSource, index);
        }
      case SongBrowserMockData.categoryTabIndex:
        if (onCategorySelected != null) {
          onCategorySelected!();
        } else {
          _openSongBrowser(context, activeSource, index);
        }
      case SongBrowserMockData.selectedTabIndex:
        _pushIfAbsent(context, AppRouter.selectedQueue);
      case SongBrowserMockData.settingsTabIndex:
        _pushIfAbsent(context, AppRouter.settings);
      case SongBrowserMockData.exitTabIndex:
        _showExitDialog(context);
      default:
        onOtherSelected?.call(index);
    }
  }

  Future<void> _showExitDialog(BuildContext context) async {
    final l10n = context.l10n;
    final action = await showDialog<_ExitAction>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.panelStrong,
        title: Text(l10n.exitDialogTitle),
        content: Text(l10n.exitDialogMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(_ExitAction.cancel),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(_ExitAction.restart),
            child: Text(l10n.restartApp),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(_ExitAction.shutdown),
            child: Text(l10n.shutdownDevice),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(_ExitAction.exit),
            child: Text(l10n.exitApp),
          ),
        ],
      ),
    );
    if (!context.mounted || action == null || action == _ExitAction.cancel) {
      return;
    }
    switch (action) {
      case _ExitAction.exit:
        SystemNavigator.pop();
      case _ExitAction.restart:
        try {
          await const AppSystemService().restartApp();
        } catch (_) {
          if (!context.mounted) return;
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(l10n.restartUnavailable)));
        }
      case _ExitAction.shutdown:
        try {
          await const AppSystemService().shutdownDevice();
        } catch (_) {
          if (!context.mounted) return;
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(l10n.shutdownUnavailable)));
        }
      case _ExitAction.cancel:
        break;
    }
  }

  void _pushIfAbsent(BuildContext context, String route) {
    if (ModalRoute.of(context)?.settings.name == route) {
      return;
    }
    Navigator.of(context).pushNamed(route);
  }

  void _openSongBrowser(
    BuildContext context,
    MusicSourceLogoStyle activeSource,
    int topActionIndex,
  ) {
    final navigator = Navigator.of(context);
    var foundSongBrowser = false;
    MusicSource? existingSource;

    navigator.popUntil((route) {
      if (route.settings.name == AppRouter.songBrowser) {
        foundSongBrowser = true;
        existingSource = _sourceFromArguments(route.settings.arguments);
        return true;
      }
      return route.isFirst;
    });

    final sources = SourceSelectionMockData.localizedSources(context.l10n);
    final fallbackSource = sources.firstWhere(
      (source) => source.logoStyle == activeSource,
      orElse: () => sources.first,
    );
    final arguments = SongBrowserRouteArguments(
      source: existingSource ?? currentSource ?? fallbackSource,
      initialTopActionIndex: topActionIndex,
    );
    if (foundSongBrowser) {
      navigator.pushReplacementNamed(
        AppRouter.songBrowser,
        arguments: arguments,
      );
    } else {
      navigator.pushNamed(AppRouter.songBrowser, arguments: arguments);
    }
  }

  MusicSource? _sourceFromArguments(Object? arguments) {
    return switch (arguments) {
      SongBrowserRouteArguments(:final source) => source,
      final MusicSource source => source,
      _ => null,
    };
  }
}

enum _ExitAction { exit, restart, shutdown, cancel }
