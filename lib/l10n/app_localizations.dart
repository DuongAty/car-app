import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_vi.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('vi'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In vi, this message translates to:
  /// **'Viet KTV'**
  String get appTitle;

  /// No description provided for @languageVi.
  ///
  /// In vi, this message translates to:
  /// **'VI'**
  String get languageVi;

  /// No description provided for @languageEn.
  ///
  /// In vi, this message translates to:
  /// **'EN'**
  String get languageEn;

  /// No description provided for @homeWelcome.
  ///
  /// In vi, this message translates to:
  /// **'CHÀO MỪNG ĐẾN VỚI'**
  String get homeWelcome;

  /// No description provided for @homeSubtitle.
  ///
  /// In vi, this message translates to:
  /// **'Chọn nguồn nhạc để bắt đầu'**
  String get homeSubtitle;

  /// No description provided for @sourceYoutubeSubtitle.
  ///
  /// In vi, this message translates to:
  /// **'Kho nhạc & Video\nkhổng lồ'**
  String get sourceYoutubeSubtitle;

  /// No description provided for @sourceSoundcloudSubtitle.
  ///
  /// In vi, this message translates to:
  /// **'Nhạc DJ & Remix\nđộc quyền'**
  String get sourceSoundcloudSubtitle;

  /// No description provided for @sourceMcloudSubtitle.
  ///
  /// In vi, this message translates to:
  /// **'DJ Sets & Podcasts\nchất lượng cao'**
  String get sourceMcloudSubtitle;

  /// No description provided for @topConnectPhone.
  ///
  /// In vi, this message translates to:
  /// **'KẾT NỐI ĐT'**
  String get topConnectPhone;

  /// No description provided for @topSettings.
  ///
  /// In vi, this message translates to:
  /// **'CÀI ĐẶT'**
  String get topSettings;

  /// No description provided for @topExit.
  ///
  /// In vi, this message translates to:
  /// **'THOÁT'**
  String get topExit;

  /// No description provided for @hintSelect.
  ///
  /// In vi, this message translates to:
  /// **'Chọn'**
  String get hintSelect;

  /// No description provided for @hintBack.
  ///
  /// In vi, this message translates to:
  /// **'Quay lại'**
  String get hintBack;

  /// No description provided for @hintClearQueue.
  ///
  /// In vi, this message translates to:
  /// **'Xóa tất cả hàng chờ'**
  String get hintClearQueue;

  /// No description provided for @hintQueueCount.
  ///
  /// In vi, this message translates to:
  /// **'Danh sách chờ ({count})'**
  String hintQueueCount(int count);

  /// No description provided for @hintNavigate.
  ///
  /// In vi, this message translates to:
  /// **'Điều hướng'**
  String get hintNavigate;

  /// No description provided for @hintChooseAndPlay.
  ///
  /// In vi, this message translates to:
  /// **'Chọn / Phát bài'**
  String get hintChooseAndPlay;

  /// No description provided for @hintSelectedQueue.
  ///
  /// In vi, this message translates to:
  /// **'Xem danh sách đã chọn ({count})'**
  String hintSelectedQueue(int count);

  /// No description provided for @hintFavorites.
  ///
  /// In vi, this message translates to:
  /// **'Yêu thích'**
  String get hintFavorites;

  /// No description provided for @songSearch.
  ///
  /// In vi, this message translates to:
  /// **'TÌM BÀI'**
  String get songSearch;

  /// No description provided for @songList.
  ///
  /// In vi, this message translates to:
  /// **'DANH SÁCH'**
  String get songList;

  /// No description provided for @songSelected.
  ///
  /// In vi, this message translates to:
  /// **'ĐÃ CHỌN'**
  String get songSelected;

  /// No description provided for @karaokeLabel.
  ///
  /// In vi, this message translates to:
  /// **'Karaoke'**
  String get karaokeLabel;

  /// No description provided for @panelSuggestions.
  ///
  /// In vi, this message translates to:
  /// **'GỢI Ý CHO BẠN'**
  String get panelSuggestions;

  /// No description provided for @panelSearchResults.
  ///
  /// In vi, this message translates to:
  /// **'KẾT QUẢ TÌM KIẾM'**
  String get panelSearchResults;

  /// No description provided for @searchPlaceholder.
  ///
  /// In vi, this message translates to:
  /// **'Tìm bài hát, ca sĩ hoặc từ khóa...'**
  String get searchPlaceholder;

  /// No description provided for @searchResultCount.
  ///
  /// In vi, this message translates to:
  /// **'{count} kết quả'**
  String searchResultCount(int count);

  /// No description provided for @searchEmpty.
  ///
  /// In vi, this message translates to:
  /// **'Không có kết quả phù hợp'**
  String get searchEmpty;

  /// No description provided for @searchIdlePrompt.
  ///
  /// In vi, this message translates to:
  /// **'Nhập từ khóa rồi bấm TÌM để tìm kiếm'**
  String get searchIdlePrompt;

  /// No description provided for @searchLoading.
  ///
  /// In vi, this message translates to:
  /// **'Đang tìm kiếm...'**
  String get searchLoading;

  /// No description provided for @searchFailed.
  ///
  /// In vi, this message translates to:
  /// **'Không tải được kết quả. Thử lại.'**
  String get searchFailed;

  /// No description provided for @recommendationsLoading.
  ///
  /// In vi, this message translates to:
  /// **'Đang tải gợi ý...'**
  String get recommendationsLoading;

  /// No description provided for @recommendationsFailed.
  ///
  /// In vi, this message translates to:
  /// **'Không tải được gợi ý.'**
  String get recommendationsFailed;

  /// No description provided for @recommendationsEmpty.
  ///
  /// In vi, this message translates to:
  /// **'Chưa có gợi ý nào.'**
  String get recommendationsEmpty;

  /// No description provided for @playbackIdlePrompt.
  ///
  /// In vi, this message translates to:
  /// **'Chọn một bài hát để bắt đầu'**
  String get playbackIdlePrompt;

  /// No description provided for @playbackLoading.
  ///
  /// In vi, this message translates to:
  /// **'Đang tải video...'**
  String get playbackLoading;

  /// No description provided for @playbackFailed.
  ///
  /// In vi, this message translates to:
  /// **'Không phát được video này.'**
  String get playbackFailed;

  /// No description provided for @queueItemCount.
  ///
  /// In vi, this message translates to:
  /// **'{count} bài'**
  String queueItemCount(int count);

  /// No description provided for @queueEmpty.
  ///
  /// In vi, this message translates to:
  /// **'Chưa có bài hát nào trong hàng chờ.\nBấm + ở kết quả tìm kiếm để thêm bài hát.'**
  String get queueEmpty;

  /// No description provided for @queueRemoveTooltip.
  ///
  /// In vi, this message translates to:
  /// **'Xóa khỏi hàng chờ'**
  String get queueRemoveTooltip;

  /// No description provided for @keyboardSearch.
  ///
  /// In vi, this message translates to:
  /// **'TÌM'**
  String get keyboardSearch;

  /// No description provided for @keyboardClear.
  ///
  /// In vi, this message translates to:
  /// **'XÓA'**
  String get keyboardClear;

  /// No description provided for @keyboardSpace.
  ///
  /// In vi, this message translates to:
  /// **'DẤU CÁCH'**
  String get keyboardSpace;

  /// No description provided for @keyboardBack.
  ///
  /// In vi, this message translates to:
  /// **'XÓA KÝ TỰ'**
  String get keyboardBack;

  /// No description provided for @keyboardNumberMode.
  ///
  /// In vi, this message translates to:
  /// **'123'**
  String get keyboardNumberMode;

  /// No description provided for @mockYoutubeChannel.
  ///
  /// In vi, this message translates to:
  /// **'Karaoke 4 You'**
  String get mockYoutubeChannel;

  /// No description provided for @mockOfficialChannel.
  ///
  /// In vi, this message translates to:
  /// **'Sơn Tùng M-TP Official'**
  String get mockOfficialChannel;

  /// No description provided for @mockBeatChannel.
  ///
  /// In vi, this message translates to:
  /// **'Nhạc Karaoke Tuyển Chọn'**
  String get mockBeatChannel;

  /// No description provided for @mockToneNam.
  ///
  /// In vi, this message translates to:
  /// **'Karaoke Tone Nam'**
  String get mockToneNam;

  /// No description provided for @mockAcoustic.
  ///
  /// In vi, this message translates to:
  /// **'Bản phối Acoustic'**
  String get mockAcoustic;

  /// No description provided for @mockPiano.
  ///
  /// In vi, this message translates to:
  /// **'Bản phối Piano'**
  String get mockPiano;

  /// No description provided for @mockLive.
  ///
  /// In vi, this message translates to:
  /// **'Biểu diễn trực tiếp'**
  String get mockLive;

  /// No description provided for @mockDjRemix.
  ///
  /// In vi, this message translates to:
  /// **'Đại Mèo Remix'**
  String get mockDjRemix;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'vi'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'vi':
      return AppLocalizationsVi();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
