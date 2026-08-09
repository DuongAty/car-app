import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/providers/locale_provider.dart';
import 'core/theme/app_theme.dart';
import 'features/history/presentation/providers/history_controller.dart';
import 'features/playback/presentation/providers/background_playback_provider.dart';
import 'l10n/app_localizations.dart';
import 'routes/app_router.dart';

class VietKtvApp extends ConsumerWidget {
  const VietKtvApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(appLocaleProvider);
    // Keeps the play-history recorder alive for the whole app lifetime — it
    // must exist before the first song is played, not only once the history
    // page happens to be opened.
    ref.watch(historyControllerProvider);
    // Keeps the media notification, audio-focus handling, and background
    // lifecycle behaviour alive for the whole app lifetime.
    ref.watch(backgroundPlaybackProvider);

    return MaterialApp(
      onGenerateTitle: (context) =>
          AppLocalizations.of(context)?.appTitle ?? 'car-app',
      debugShowCheckedModeBanner: false,
      // Removes the pull-past-edge stretch/glow on every scrollable: it is a
      // per-frame transform of the whole list content (costly on a 1-core box)
      // and the product wants no overscroll effect.
      scrollBehavior: const _NoOverscrollScrollBehavior(),
      theme: AppTheme.dark(),
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      onGenerateRoute: AppRouter.onGenerateRoute,
      initialRoute: AppRouter.splash,
    );
  }
}

/// Suppresses the overscroll indicator (glow on older Android, stretch on
/// Android 12+) app-wide, keeping the default scroll physics and scrollbars.
class _NoOverscrollScrollBehavior extends MaterialScrollBehavior {
  const _NoOverscrollScrollBehavior();

  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    return child;
  }
}
