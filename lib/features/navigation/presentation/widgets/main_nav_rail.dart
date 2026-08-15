import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/models/nav_rail_item.dart';
import '../../../../core/providers/locale_provider.dart';
import '../../../../core/services/app_system_service.dart';
import '../../../../core/shared/widgets/app_nav_rail.dart';
import '../../../../core/shared/widgets/language_toggle.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_icons.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../l10n/l10n.dart';
import '../../../../routes/app_router.dart';
import '../../../playback/presentation/providers/now_playing_controller.dart';
import '../../../playback/presentation/widgets/rail_mini_player.dart';
import '../../../settings/data/models/app_settings.dart';
import '../../../queue/presentation/providers/queue_provider.dart';
import '../../../song_browser/data/mock/song_browser_mock_data.dart';
import '../../../source_selection/data/mock/source_selection_mock_data.dart';
import '../../../source_selection/data/models/music_source.dart';
import '../../../source_selection/presentation/providers/source_selection_provider.dart';
import '../../../source_selection/presentation/widgets/source_badge.dart';
import 'volume_rail_entry.dart';

/// Destination ids for [MainNavRail]. Pages name the one they are, so a
/// destination can be reordered or hidden without renumbering every caller.
abstract final class NavDestination {
  static const String home = 'home';
  static const String search = 'search';
  static const String categories = 'categories';
  static const String queue = 'queue';
  static const String favorites = 'favorites';
  static const String connect = 'connect';
  static const String settings = 'settings';
  static const String exit = 'exit';
}

/// The single, app-wide left navigation rail.
///
/// Every page passes this to `KaraokeShell.navRail` instead of composing its
/// own chrome, so the destinations, the brand mark, and the language switch sit
/// in exactly the same place on every screen.
class MainNavRail extends ConsumerWidget {
  const MainNavRail({
    super.key,
    this.selectedId,
    this.currentSource,
    this.hasStagePlayer = false,
    this.onSearchSelected,
    this.onCategoriesSelected,
    this.onQueueSelected,
    this.onMiniPlayerTap,
  });

  /// Which destination reads as active, or null when none does.
  final String? selectedId;

  /// Source to reopen the browser with when navigating from a page that has
  /// one. Falls back to the active playback source.
  final MusicSource? currentSource;

  /// Whether the page already shows a full player stage. Stage pages never get
  /// the rail's mini-player; stage-less ones surface it whenever something is
  /// playing.
  final bool hasStagePlayer;

  /// Overrides for pages that handle a destination in place rather than by
  /// navigating — the browser switches tabs instead of pushing a route.
  final VoidCallback? onSearchSelected;
  final VoidCallback? onCategoriesSelected;
  final VoidCallback? onQueueSelected;
  final VoidCallback? onMiniPlayerTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final queueCount = ref.watch(
      queueProvider.select((state) => state.items.length),
    );
    final selectedSource = ref.watch(
      sourceSelectionProvider.select((state) => state.selectedSource),
    );

    return AppNavRail(
      selectedId: selectedId,
      // Indicator only, not a control: excluded from focus/semantics so it
      // never becomes a D-pad stop.
      header: ExcludeSemantics(child: SourceMark(source: selectedSource)),
      items: [
        NavRailItem(
          id: NavDestination.home,
          label: l10n.topHome,
          icon: AppIcons.home,
        ),
        NavRailItem(
          id: NavDestination.search,
          label: l10n.songSearch,
          icon: AppIcons.search,
        ),
        NavRailItem(
          id: NavDestination.categories,
          label: l10n.songList,
          icon: AppIcons.categoryGrid,
        ),
        NavRailItem(
          id: NavDestination.queue,
          label: l10n.songSelected,
          icon: AppIcons.selectedQueue,
          badgeCount: queueCount > 0 ? queueCount : null,
        ),
        NavRailItem(
          id: NavDestination.favorites,
          label: l10n.navFavorites,
          icon: AppIcons.favorite,
          accentColor: AppColors.blue,
        ),
        NavRailItem(
          id: NavDestination.connect,
          label: l10n.topConnectPhone,
          icon: AppIcons.connectPhone,
        ),
        NavRailItem(
          id: NavDestination.settings,
          label: l10n.topSettings,
          icon: AppIcons.settings,
        ),
        NavRailItem(
          id: NavDestination.exit,
          label: l10n.topExit,
          icon: AppIcons.power,
          accentColor: AppColors.red,
        ),
      ],
      onSelected: (id) => _handleSelected(context, ref, id),
      footer: _RailFooter(
        hasStagePlayer: hasStagePlayer,
        onMiniPlayerTap: onMiniPlayerTap,
        currentSource: currentSource,
      ),
    );
  }

  void _handleSelected(BuildContext context, WidgetRef ref, String id) {
    switch (id) {
      case NavDestination.home:
        // Home is the initial route — pop back to the existing source picker
        // rather than pushing a second copy onto the stack.
        Navigator.of(context).popUntil((route) => route.isFirst);
      case NavDestination.search:
        if (onSearchSelected != null) {
          onSearchSelected!();
        } else {
          _openSongBrowser(context, ref, SongBrowserMockData.searchTabIndex);
        }
      case NavDestination.categories:
        if (onCategoriesSelected != null) {
          onCategoriesSelected!();
        } else {
          _openSongBrowser(context, ref, SongBrowserMockData.categoryTabIndex);
        }
      case NavDestination.queue:
        if (onQueueSelected != null) {
          onQueueSelected!();
        } else {
          _pushIfAbsent(context, AppRouter.selectedQueue);
        }
      case NavDestination.favorites:
        _pushIfAbsent(context, AppRouter.favorites);
      case NavDestination.connect:
        // Deep-links into the settings screen's device section, which holds the
        // pairing QR for controlling the box from a phone.
        _pushSettings(
          context,
          const SettingsRouteArguments(
            initialCategory: SettingsCategory.device,
          ),
        );
      case NavDestination.settings:
        _pushSettings(context, null);
      case NavDestination.exit:
        _showExitDialog(context);
    }
  }

  /// Settings needs its own push: the same route serves both the plain
  /// settings entry and the connect deep-link, so "already there" is not enough
  /// — arriving from connect must still switch the visible section.
  void _pushSettings(BuildContext context, SettingsRouteArguments? arguments) {
    final route = ModalRoute.of(context);
    if (route?.settings.name == AppRouter.settings) {
      if (arguments == null) {
        return;
      }
      Navigator.of(
        context,
      ).pushReplacementNamed(AppRouter.settings, arguments: arguments);
      return;
    }
    Navigator.of(context).pushNamed(AppRouter.settings, arguments: arguments);
  }

  void _pushIfAbsent(BuildContext context, String route) {
    if (ModalRoute.of(context)?.settings.name == route) {
      return;
    }
    Navigator.of(context).pushNamed(route);
  }

  void _openSongBrowser(
    BuildContext context,
    WidgetRef ref,
    int topActionIndex,
  ) {
    final activeSource = ref.read(nowPlayingProvider).activeSource;
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
}

/// Now-playing block, the volume control, and the language switch, in that
/// order down the foot of the rail.
///
/// Its own widget so the rail's destinations do not rebuild when a track
/// changes. There is no volume control here: the rail is kept as narrow as it
/// can be, hardware volume keys already work, and Settings → Âm thanh still
/// exposes a slider.
class _RailFooter extends ConsumerWidget {
  const _RailFooter({
    required this.hasStagePlayer,
    required this.onMiniPlayerTap,
    required this.currentSource,
  });

  final bool hasStagePlayer;
  final VoidCallback? onMiniPlayerTap;
  final MusicSource? currentSource;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isPlaying = ref.watch(
      nowPlayingProvider.select((state) => state.playback is! PlaybackIdle),
    );
    final locale = ref.watch(appLocaleProvider);
    final localeController = ref.read(appLocaleProvider.notifier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!hasStagePlayer && isPlaying) ...[
          RailMiniPlayer(
            onTap:
                onMiniPlayerTap ??
                () => _openSongBrowser(context, ref, currentSource),
          ),
          const SizedBox(height: AppSpacing.xxs),
        ],
        const VolumeRailEntry(),
        Center(
          child: LanguageToggle(
            isVietnamese: locale.languageCode == 'vi',
            onToggle: localeController.toggle,
            compact: true,
          ),
        ),
      ],
    );
  }

  void _openSongBrowser(
    BuildContext context,
    WidgetRef ref,
    MusicSource? currentSource,
  ) {
    final navigator = Navigator.of(context);
    var foundSongBrowser = false;

    navigator.popUntil((route) {
      if (route.settings.name == AppRouter.songBrowser) {
        foundSongBrowser = true;
        return true;
      }
      return route.isFirst;
    });

    if (foundSongBrowser) {
      return;
    }

    final activeSource = ref.read(nowPlayingProvider).activeSource;
    final sources = SourceSelectionMockData.localizedSources(context.l10n);
    final source =
        currentSource ??
        sources.firstWhere(
          (source) => source.logoStyle == activeSource,
          orElse: () => sources.first,
        );
    navigator.pushNamed(AppRouter.songBrowser, arguments: source);
  }
}

enum _ExitAction { exit, restart, shutdown, cancel }
