import 'package:flutter/material.dart';

import '../core/theme/app_motion.dart';
import '../features/favorites/presentation/pages/favorites_page.dart';
import '../features/history/presentation/pages/history_page.dart';
import '../features/license/presentation/pages/license_gate_page.dart';
import '../features/queue/presentation/pages/selected_queue_page.dart';
import '../features/remote/presentation/pages/pairing_page.dart';
import '../features/settings/presentation/pages/settings_page.dart';
import '../features/settings/data/models/app_settings.dart';
import '../features/song_browser/presentation/pages/song_browser_page.dart';
import '../features/source_selection/data/models/music_source.dart';
import '../features/source_selection/presentation/pages/source_selection_page.dart';
import '../features/startup/presentation/pages/splash_page.dart';

class SongBrowserRouteArguments {
  const SongBrowserRouteArguments({
    required this.source,
    this.initialTopActionIndex,
  });

  final MusicSource source;
  final int? initialTopActionIndex;
}

class SettingsRouteArguments {
  const SettingsRouteArguments({this.initialCategory});

  final SettingsCategory? initialCategory;
}

abstract final class AppRouter {
  static const String splash = '/splash';
  static const String license = '/license';
  static const String home = '/';
  static const String songBrowser = '/song-browser';
  static const String selectedQueue = '/selected-queue';
  static const String favorites = '/favorites';
  static const String history = '/history';
  static const String settings = '/settings';
  static const String pairing = '/pairing';

  static Route<dynamic> onGenerateRoute(RouteSettings routeSettings) {
    switch (routeSettings.name) {
      case splash:
        return _FadePageRoute<void>(
          builder: (_) => const SplashPage(),
          settings: routeSettings,
        );
      case license:
        return _FadePageRoute<void>(
          builder: (context) => LicenseGatePage(
            onUnlocked: () => Navigator.of(context).pushReplacementNamed(home),
          ),
          settings: routeSettings,
        );
      case home:
        return _FadePageRoute<void>(
          builder: (_) => const SourceSelectionPage(),
          settings: routeSettings,
        );
      case songBrowser:
        final arguments = routeSettings.arguments;
        final source = switch (arguments) {
          SongBrowserRouteArguments(:final source) => source,
          final MusicSource source => source,
          _ => throw ArgumentError(
            'Song browser route requires a MusicSource argument.',
          ),
        };
        final initialTopActionIndex = switch (arguments) {
          SongBrowserRouteArguments(:final initialTopActionIndex) =>
            initialTopActionIndex,
          _ => null,
        };
        return _FadePageRoute<void>(
          builder: (_) => SongBrowserPage(
            source: source,
            initialTopActionIndex: initialTopActionIndex,
          ),
          settings: routeSettings,
        );
      case selectedQueue:
        return _FadePageRoute<void>(
          builder: (_) => const SelectedQueuePage(),
          settings: routeSettings,
        );
      case favorites:
        return _FadePageRoute<void>(
          builder: (_) => const FavoritesPage(),
          settings: routeSettings,
        );
      case history:
        return _FadePageRoute<void>(
          builder: (_) => const HistoryPage(),
          settings: routeSettings,
        );
      case pairing:
        return _FadePageRoute<void>(
          builder: (_) => const PairingPage(),
          settings: routeSettings,
        );
      case settings:
        final arguments = routeSettings.arguments;
        final initialCategory = switch (arguments) {
          SettingsRouteArguments(:final initialCategory) => initialCategory,
          _ => null,
        };
        return _FadePageRoute<void>(
          builder: (_) => SettingsPage(initialCategory: initialCategory),
          settings: routeSettings,
        );
      default:
        return _FadePageRoute<void>(
          builder: (_) => const SourceSelectionPage(),
          settings: routeSettings,
        );
    }
  }
}

/// Page route that inherits the theme's fade transition but shortens it to a
/// light [AppMotion.route] (220ms). Kept as a MaterialPageRoute subclass so all
/// Material page semantics (barrier, maintainState, back gesture) are preserved.
class _FadePageRoute<T> extends MaterialPageRoute<T> {
  _FadePageRoute({required super.builder, super.settings});

  @override
  Duration get transitionDuration => AppMotion.route;

  @override
  Duration get reverseTransitionDuration => AppMotion.route;
}
