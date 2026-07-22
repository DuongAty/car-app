import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final appLocaleProvider = StateNotifierProvider<AppLocaleController, Locale>(
  (ref) => AppLocaleController(),
);

class AppLocaleController extends StateNotifier<Locale> {
  AppLocaleController() : super(const Locale('vi'));

  bool get isVietnamese => state.languageCode == 'vi';

  void toggle() {
    state = isVietnamese ? const Locale('en') : const Locale('vi');
  }

  void setLocale(Locale locale) {
    state = locale;
  }
}
