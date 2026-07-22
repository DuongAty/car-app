import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/providers/locale_provider.dart';
import 'core/theme/app_theme.dart';
import 'l10n/app_localizations.dart';
import 'routes/app_router.dart';

class VietKtvApp extends ConsumerWidget {
  const VietKtvApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(appLocaleProvider);

    return MaterialApp(
      onGenerateTitle: (context) =>
          AppLocalizations.of(context)?.appTitle ?? 'Viet KTV',
      debugShowCheckedModeBanner: false,
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
      initialRoute: AppRouter.home,
    );
  }
}
