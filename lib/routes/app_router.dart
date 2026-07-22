import 'package:flutter/material.dart';

import '../features/queue/presentation/pages/selected_queue_page.dart';
import '../features/song_browser/presentation/pages/song_browser_page.dart';
import '../features/source_selection/data/models/music_source.dart';
import '../features/source_selection/presentation/pages/source_selection_page.dart';

abstract final class AppRouter {
  static const String home = '/';
  static const String songBrowser = '/song-browser';
  static const String selectedQueue = '/selected-queue';

  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case home:
        return MaterialPageRoute<void>(
          builder: (_) => const SourceSelectionPage(),
          settings: settings,
        );
      case songBrowser:
        final source = settings.arguments as MusicSource;
        return MaterialPageRoute<void>(
          builder: (_) => SongBrowserPage(source: source),
          settings: settings,
        );
      case selectedQueue:
        return MaterialPageRoute<void>(
          builder: (_) => const SelectedQueuePage(),
          settings: settings,
        );
      default:
        return MaterialPageRoute<void>(
          builder: (_) => const SourceSelectionPage(),
          settings: settings,
        );
    }
  }
}
