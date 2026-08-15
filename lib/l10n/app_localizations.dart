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
  /// **'WeTube'**
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
  /// **'Chọn nguồn nhạc để bắt đầu'**
  String get homeWelcome;

  /// No description provided for @homeSubtitle.
  ///
  /// In vi, this message translates to:
  /// **'Dùng remote, nút điều hướng hoặc chạm màn hình để chọn'**
  String get homeSubtitle;

  /// No description provided for @splashTagline.
  ///
  /// In vi, this message translates to:
  /// **'Karaoke neon cho phòng hát hiện đại'**
  String get splashTagline;

  /// No description provided for @splashPreparing.
  ///
  /// In vi, this message translates to:
  /// **'Đang khởi động hệ thống...'**
  String get splashPreparing;

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

  /// No description provided for @settingsLanguage.
  ///
  /// In vi, this message translates to:
  /// **'Ngôn ngữ'**
  String get settingsLanguage;

  /// No description provided for @settingsClearFavorites.
  ///
  /// In vi, this message translates to:
  /// **'Xóa danh sách yêu thích'**
  String get settingsClearFavorites;

  /// No description provided for @settingsClearHistory.
  ///
  /// In vi, this message translates to:
  /// **'Xóa lịch sử đã hát'**
  String get settingsClearHistory;

  /// No description provided for @settingsConfirmAgain.
  ///
  /// In vi, this message translates to:
  /// **'Nhấn lần nữa để xác nhận xóa'**
  String get settingsConfirmAgain;

  /// No description provided for @settingsViewHistory.
  ///
  /// In vi, this message translates to:
  /// **'Xem lịch sử đã hát'**
  String get settingsViewHistory;

  /// No description provided for @settingsDevice.
  ///
  /// In vi, this message translates to:
  /// **'Kết nối thiết bị'**
  String get settingsDevice;

  /// No description provided for @settingsAudio.
  ///
  /// In vi, this message translates to:
  /// **'Âm thanh'**
  String get settingsAudio;

  /// No description provided for @settingsDisplay.
  ///
  /// In vi, this message translates to:
  /// **'Hiển thị'**
  String get settingsDisplay;

  /// No description provided for @settingsInterface.
  ///
  /// In vi, this message translates to:
  /// **'Giao diện'**
  String get settingsInterface;

  /// No description provided for @settingsVideoPlayback.
  ///
  /// In vi, this message translates to:
  /// **'Phát video'**
  String get settingsVideoPlayback;

  /// No description provided for @settingsLanguageSection.
  ///
  /// In vi, this message translates to:
  /// **'Ngôn ngữ'**
  String get settingsLanguageSection;

  /// No description provided for @settingsLanguageUnavailable.
  ///
  /// In vi, this message translates to:
  /// **'Ngôn ngữ này cần bổ sung gói bản dịch trước khi bật.'**
  String get settingsLanguageUnavailable;

  /// No description provided for @languageFrench.
  ///
  /// In vi, this message translates to:
  /// **'Tiếng Pháp'**
  String get languageFrench;

  /// No description provided for @languageSpanish.
  ///
  /// In vi, this message translates to:
  /// **'Tiếng Tây Ban Nha'**
  String get languageSpanish;

  /// No description provided for @languageGerman.
  ///
  /// In vi, this message translates to:
  /// **'Tiếng Đức'**
  String get languageGerman;

  /// No description provided for @languageJapanese.
  ///
  /// In vi, this message translates to:
  /// **'Tiếng Nhật'**
  String get languageJapanese;

  /// No description provided for @languageKorean.
  ///
  /// In vi, this message translates to:
  /// **'Tiếng Hàn'**
  String get languageKorean;

  /// No description provided for @languageChinese.
  ///
  /// In vi, this message translates to:
  /// **'Tiếng Trung'**
  String get languageChinese;

  /// No description provided for @languageThai.
  ///
  /// In vi, this message translates to:
  /// **'Tiếng Thái'**
  String get languageThai;

  /// No description provided for @languageIndonesian.
  ///
  /// In vi, this message translates to:
  /// **'Tiếng Indonesia'**
  String get languageIndonesian;

  /// No description provided for @languagePortuguese.
  ///
  /// In vi, this message translates to:
  /// **'Tiếng Bồ Đào Nha'**
  String get languagePortuguese;

  /// No description provided for @languageRussian.
  ///
  /// In vi, this message translates to:
  /// **'Tiếng Nga'**
  String get languageRussian;

  /// No description provided for @settingsSongManagement.
  ///
  /// In vi, this message translates to:
  /// **'Quản lý bài hát'**
  String get settingsSongManagement;

  /// No description provided for @settingsAccount.
  ///
  /// In vi, this message translates to:
  /// **'Tài khoản'**
  String get settingsAccount;

  /// No description provided for @settingsSystem.
  ///
  /// In vi, this message translates to:
  /// **'Hệ thống'**
  String get settingsSystem;

  /// No description provided for @settingsInfo.
  ///
  /// In vi, this message translates to:
  /// **'Thông tin'**
  String get settingsInfo;

  /// No description provided for @settingsPreview.
  ///
  /// In vi, this message translates to:
  /// **'XEM TRƯỚC'**
  String get settingsPreview;

  /// No description provided for @settingsOsdPreview.
  ///
  /// In vi, this message translates to:
  /// **'XEM TRƯỚC OSD'**
  String get settingsOsdPreview;

  /// No description provided for @settingsGuide.
  ///
  /// In vi, this message translates to:
  /// **'HƯỚNG DẪN'**
  String get settingsGuide;

  /// No description provided for @settingsQualitySection.
  ///
  /// In vi, this message translates to:
  /// **'1. CHẤT LƯỢNG PHÁT'**
  String get settingsQualitySection;

  /// No description provided for @settingsPlaybackModeSection.
  ///
  /// In vi, this message translates to:
  /// **'2. CHẾ ĐỘ PHÁT'**
  String get settingsPlaybackModeSection;

  /// No description provided for @settingsOtherOptionsSection.
  ///
  /// In vi, this message translates to:
  /// **'3. TÙY CHỌN KHÁC'**
  String get settingsOtherOptionsSection;

  /// No description provided for @settingsDemoVideoSection.
  ///
  /// In vi, this message translates to:
  /// **'4. VIDEO DEMO KHI CHƯA CHỌN BÀI'**
  String get settingsDemoVideoSection;

  /// No description provided for @settingsQuality4k.
  ///
  /// In vi, this message translates to:
  /// **'4K (2160p)'**
  String get settingsQuality4k;

  /// No description provided for @settingsQualityFhd.
  ///
  /// In vi, this message translates to:
  /// **'Full HD (1080p)'**
  String get settingsQualityFhd;

  /// No description provided for @settingsQualityHd.
  ///
  /// In vi, this message translates to:
  /// **'HD (720p)'**
  String get settingsQualityHd;

  /// No description provided for @settingsQualitySd.
  ///
  /// In vi, this message translates to:
  /// **'SD (480p)'**
  String get settingsQualitySd;

  /// No description provided for @settingsQualityAuto.
  ///
  /// In vi, this message translates to:
  /// **'Tự động'**
  String get settingsQualityAuto;

  /// No description provided for @settingsQualityAutoDescription.
  ///
  /// In vi, this message translates to:
  /// **'Chọn chất lượng theo mạng'**
  String get settingsQualityAutoDescription;

  /// No description provided for @settingsPlayContinuous.
  ///
  /// In vi, this message translates to:
  /// **'Phát liên tục'**
  String get settingsPlayContinuous;

  /// No description provided for @settingsPlayContinuousDescription.
  ///
  /// In vi, this message translates to:
  /// **'Tự động phát bài tiếp theo trong danh sách'**
  String get settingsPlayContinuousDescription;

  /// No description provided for @settingsRepeatAll.
  ///
  /// In vi, this message translates to:
  /// **'Phát lặp danh sách'**
  String get settingsRepeatAll;

  /// No description provided for @settingsRepeatAllDescription.
  ///
  /// In vi, this message translates to:
  /// **'Lặp lại toàn bộ danh sách hiện tại'**
  String get settingsRepeatAllDescription;

  /// No description provided for @settingsRepeatOne.
  ///
  /// In vi, this message translates to:
  /// **'Phát lặp một bài'**
  String get settingsRepeatOne;

  /// No description provided for @settingsRepeatOneDescription.
  ///
  /// In vi, this message translates to:
  /// **'Lặp lại bài đang phát'**
  String get settingsRepeatOneDescription;

  /// No description provided for @settingsShuffle.
  ///
  /// In vi, this message translates to:
  /// **'Phát ngẫu nhiên'**
  String get settingsShuffle;

  /// No description provided for @settingsShuffleDescription.
  ///
  /// In vi, this message translates to:
  /// **'Phát ngẫu nhiên các bài trong danh sách'**
  String get settingsShuffleDescription;

  /// No description provided for @settingsBuffer.
  ///
  /// In vi, this message translates to:
  /// **'Đệm trước (Buffer)'**
  String get settingsBuffer;

  /// No description provided for @settingsBufferDescription.
  ///
  /// In vi, this message translates to:
  /// **'Tăng thời gian đệm để video mượt hơn'**
  String get settingsBufferDescription;

  /// No description provided for @settingsSeconds.
  ///
  /// In vi, this message translates to:
  /// **'{count} giây'**
  String settingsSeconds(int count);

  /// No description provided for @settingsAutoMv.
  ///
  /// In vi, this message translates to:
  /// **'Tự động phát video MV'**
  String get settingsAutoMv;

  /// No description provided for @settingsAutoMvDescription.
  ///
  /// In vi, this message translates to:
  /// **'Tự động phát video MV nếu có'**
  String get settingsAutoMvDescription;

  /// No description provided for @settingsCaptions.
  ///
  /// In vi, this message translates to:
  /// **'Hiển thị phụ đề'**
  String get settingsCaptions;

  /// No description provided for @settingsCaptionsDescription.
  ///
  /// In vi, this message translates to:
  /// **'Tự động tải và hiển thị phụ đề nếu có'**
  String get settingsCaptionsDescription;

  /// No description provided for @settingsDemoEnabled.
  ///
  /// In vi, this message translates to:
  /// **'Bật video demo khi không có bài hát'**
  String get settingsDemoEnabled;

  /// No description provided for @settingsDemoEnabledDescription.
  ///
  /// In vi, this message translates to:
  /// **'Tự động phát video demo khi chưa chọn bài'**
  String get settingsDemoEnabledDescription;

  /// No description provided for @settingsDemoPick.
  ///
  /// In vi, this message translates to:
  /// **'Chọn video demo'**
  String get settingsDemoPick;

  /// No description provided for @settingsDemoFile.
  ///
  /// In vi, this message translates to:
  /// **'Tropical Beach.mp4'**
  String get settingsDemoFile;

  /// No description provided for @settingsOsdText.
  ///
  /// In vi, this message translates to:
  /// **'Nội dung text chạy OSD khi không có người hát'**
  String get settingsOsdText;

  /// No description provided for @settingsOsdTextValue.
  ///
  /// In vi, this message translates to:
  /// **'Mời chọn bài'**
  String get settingsOsdTextValue;

  /// No description provided for @settingsDemoCurrent.
  ///
  /// In vi, this message translates to:
  /// **'Video demo hiện tại: {file}'**
  String settingsDemoCurrent(Object file);

  /// No description provided for @settingsOsdDescription.
  ///
  /// In vi, this message translates to:
  /// **'Nội dung sẽ hiển thị dạng chữ chạy (OSD) khi không có người hát.'**
  String get settingsOsdDescription;

  /// No description provided for @settingsVideoGuide.
  ///
  /// In vi, this message translates to:
  /// **'Tính năng này giúp hiển thị video demo và nội dung OSD sinh động, thu hút người dùng khi chưa chọn bài hát.'**
  String get settingsVideoGuide;

  /// No description provided for @settingsDeviceQr.
  ///
  /// In vi, this message translates to:
  /// **'Mã QR kết nối điều khiển'**
  String get settingsDeviceQr;

  /// No description provided for @settingsDeviceName.
  ///
  /// In vi, this message translates to:
  /// **'Tên thiết bị: car-app'**
  String get settingsDeviceName;

  /// No description provided for @settingsDeviceHint.
  ///
  /// In vi, this message translates to:
  /// **'Quét QR bằng điện thoại để điều khiển chọn bài, âm lượng và hàng chờ.'**
  String get settingsDeviceHint;

  /// No description provided for @settingsMasterVolume.
  ///
  /// In vi, this message translates to:
  /// **'Âm lượng tổng'**
  String get settingsMasterVolume;

  /// No description provided for @settingsMusicVolume.
  ///
  /// In vi, this message translates to:
  /// **'Âm lượng nhạc nền'**
  String get settingsMusicVolume;

  /// No description provided for @settingsVocalBoost.
  ///
  /// In vi, this message translates to:
  /// **'Tăng giọng hát'**
  String get settingsVocalBoost;

  /// No description provided for @settingsAudioHint.
  ///
  /// In vi, this message translates to:
  /// **'Cân bằng âm lượng để nhạc nền rõ, giọng hát nổi và không bị chói.'**
  String get settingsAudioHint;

  /// No description provided for @settingsLyricSize.
  ///
  /// In vi, this message translates to:
  /// **'Kích thước lời bài hát'**
  String get settingsLyricSize;

  /// No description provided for @settingsVisualizer.
  ///
  /// In vi, this message translates to:
  /// **'Hiển thị visualizer'**
  String get settingsVisualizer;

  /// No description provided for @settingsGlowLevel.
  ///
  /// In vi, this message translates to:
  /// **'Mức hiệu ứng glow'**
  String get settingsGlowLevel;

  /// No description provided for @settingsDisplayHint.
  ///
  /// In vi, this message translates to:
  /// **'Điều chỉnh để lời bài hát dễ đọc trên TV và điện thoại Android.'**
  String get settingsDisplayHint;

  /// No description provided for @settingsTheme.
  ///
  /// In vi, this message translates to:
  /// **'Chủ đề neon'**
  String get settingsTheme;

  /// No description provided for @settingsThemeDefault.
  ///
  /// In vi, this message translates to:
  /// **'Karaoke neon'**
  String get settingsThemeDefault;

  /// No description provided for @settingsParticles.
  ///
  /// In vi, this message translates to:
  /// **'Hiệu ứng hạt nền'**
  String get settingsParticles;

  /// No description provided for @settingsInterfaceHint.
  ///
  /// In vi, this message translates to:
  /// **'Giữ giao diện nổi bật nhưng vẫn đủ nhẹ cho thiết bị Android phổ thông.'**
  String get settingsInterfaceHint;

  /// No description provided for @settingsDataSection.
  ///
  /// In vi, this message translates to:
  /// **'1. DỮ LIỆU BÀI HÁT'**
  String get settingsDataSection;

  /// No description provided for @settingsHistorySection.
  ///
  /// In vi, this message translates to:
  /// **'2. LỊCH SỬ & YÊU THÍCH'**
  String get settingsHistorySection;

  /// No description provided for @settingsManagementHint.
  ///
  /// In vi, this message translates to:
  /// **'Các thao tác xóa cần xác nhận hai lần để tránh mất dữ liệu ngoài ý muốn.'**
  String get settingsManagementHint;

  /// No description provided for @settingsAccountName.
  ///
  /// In vi, this message translates to:
  /// **'Tên tài khoản'**
  String get settingsAccountName;

  /// No description provided for @settingsAccountPlan.
  ///
  /// In vi, this message translates to:
  /// **'Gói hiện tại: Local'**
  String get settingsAccountPlan;

  /// No description provided for @settingsAccountHint.
  ///
  /// In vi, this message translates to:
  /// **'Có thể mở rộng đăng nhập và đồng bộ cloud sau này.'**
  String get settingsAccountHint;

  /// No description provided for @settingsNetworkCheck.
  ///
  /// In vi, this message translates to:
  /// **'Kiểm tra kết nối mạng'**
  String get settingsNetworkCheck;

  /// No description provided for @settingsSdkCheck.
  ///
  /// In vi, this message translates to:
  /// **'Kiểm tra Music SDK'**
  String get settingsSdkCheck;

  /// No description provided for @settingsClearCache.
  ///
  /// In vi, this message translates to:
  /// **'Xóa cache hình ảnh/video'**
  String get settingsClearCache;

  /// No description provided for @settingsNetworkStatus.
  ///
  /// In vi, this message translates to:
  /// **'Trạng thái mạng'**
  String get settingsNetworkStatus;

  /// No description provided for @settingsDeviceInfo.
  ///
  /// In vi, this message translates to:
  /// **'Thông tin thiết bị'**
  String get settingsDeviceInfo;

  /// No description provided for @settingsStorageInfo.
  ///
  /// In vi, this message translates to:
  /// **'Dung lượng'**
  String get settingsStorageInfo;

  /// No description provided for @settingsSystemLoading.
  ///
  /// In vi, this message translates to:
  /// **'Đang đọc thông tin hệ thống...'**
  String get settingsSystemLoading;

  /// No description provided for @settingsSystemUnavailable.
  ///
  /// In vi, this message translates to:
  /// **'Không đọc được thông tin hệ thống.'**
  String get settingsSystemUnavailable;

  /// No description provided for @settingsActionUnavailable.
  ///
  /// In vi, this message translates to:
  /// **'Tính năng này cần backend hoặc quyền hệ thống để hoàn thiện.'**
  String get settingsActionUnavailable;

  /// No description provided for @settingsNetworkOk.
  ///
  /// In vi, this message translates to:
  /// **'Ứng dụng đang hoạt động. Kiểm tra mạng chi tiết sẽ dùng backend phòng hát.'**
  String get settingsNetworkOk;

  /// No description provided for @settingsSdkOk.
  ///
  /// In vi, this message translates to:
  /// **'MusicSDK sẽ tự khởi tạo khi có license key hợp lệ.'**
  String get settingsSdkOk;

  /// No description provided for @settingsCacheCleared.
  ///
  /// In vi, this message translates to:
  /// **'Đã làm sạch cache ảnh trong bộ nhớ.'**
  String get settingsCacheCleared;

  /// No description provided for @settingsSystemHint.
  ///
  /// In vi, this message translates to:
  /// **'Dùng khi cần kiểm tra thiết bị, mạng hoặc làm sạch dữ liệu tạm.'**
  String get settingsSystemHint;

  /// No description provided for @settingsAppVersion.
  ///
  /// In vi, this message translates to:
  /// **'Phiên bản ứng dụng'**
  String get settingsAppVersion;

  /// No description provided for @settingsAndroidSupport.
  ///
  /// In vi, this message translates to:
  /// **'Hỗ trợ Android 10 trở lên'**
  String get settingsAndroidSupport;

  /// No description provided for @settingsInfoHint.
  ///
  /// In vi, this message translates to:
  /// **'Thông tin hệ thống và phiên bản phục vụ hỗ trợ kỹ thuật.'**
  String get settingsInfoHint;

  /// No description provided for @topHome.
  ///
  /// In vi, this message translates to:
  /// **'TRANG CHỦ'**
  String get topHome;

  /// No description provided for @topExit.
  ///
  /// In vi, this message translates to:
  /// **'THOÁT'**
  String get topExit;

  /// No description provided for @exitDialogTitle.
  ///
  /// In vi, this message translates to:
  /// **'Thoát ứng dụng?'**
  String get exitDialogTitle;

  /// No description provided for @exitDialogMessage.
  ///
  /// In vi, this message translates to:
  /// **'Chọn thao tác hệ thống cho thiết bị karaoke.'**
  String get exitDialogMessage;

  /// No description provided for @exitApp.
  ///
  /// In vi, this message translates to:
  /// **'Thoát'**
  String get exitApp;

  /// No description provided for @restartApp.
  ///
  /// In vi, this message translates to:
  /// **'Khởi động lại'**
  String get restartApp;

  /// No description provided for @shutdownDevice.
  ///
  /// In vi, this message translates to:
  /// **'Tắt máy'**
  String get shutdownDevice;

  /// No description provided for @cancel.
  ///
  /// In vi, this message translates to:
  /// **'Hủy'**
  String get cancel;

  /// No description provided for @restartUnavailable.
  ///
  /// In vi, this message translates to:
  /// **'Khởi động lại ứng dụng cần tích hợp native riêng.'**
  String get restartUnavailable;

  /// No description provided for @shutdownUnavailable.
  ///
  /// In vi, this message translates to:
  /// **'Tắt máy cần firmware cấp quyền hệ thống.'**
  String get shutdownUnavailable;

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

  /// Left navigation rail label for the favorites screen
  ///
  /// In vi, this message translates to:
  /// **'Yêu thích'**
  String get navFavorites;

  /// No description provided for @favoriteAddTooltip.
  ///
  /// In vi, this message translates to:
  /// **'Thêm vào yêu thích'**
  String get favoriteAddTooltip;

  /// No description provided for @favoriteRemoveTooltip.
  ///
  /// In vi, this message translates to:
  /// **'Bỏ khỏi yêu thích'**
  String get favoriteRemoveTooltip;

  /// No description provided for @favoritesEmpty.
  ///
  /// In vi, this message translates to:
  /// **'Chưa có bài hát yêu thích nào.\nBấm ♥ ở bài hát để thêm.'**
  String get favoritesEmpty;

  /// No description provided for @historyTitle.
  ///
  /// In vi, this message translates to:
  /// **'LỊCH SỬ ĐÃ HÁT'**
  String get historyTitle;

  /// No description provided for @historyEmpty.
  ///
  /// In vi, this message translates to:
  /// **'Chưa có bài hát nào trong lịch sử.'**
  String get historyEmpty;

  /// No description provided for @historyRemoveTooltip.
  ///
  /// In vi, this message translates to:
  /// **'Xóa khỏi lịch sử'**
  String get historyRemoveTooltip;

  /// No description provided for @historyJustNow.
  ///
  /// In vi, this message translates to:
  /// **'Vừa xong'**
  String get historyJustNow;

  /// No description provided for @historyMinutesAgo.
  ///
  /// In vi, this message translates to:
  /// **'{count} phút trước'**
  String historyMinutesAgo(int count);

  /// No description provided for @historyHoursAgo.
  ///
  /// In vi, this message translates to:
  /// **'{count} giờ trước'**
  String historyHoursAgo(int count);

  /// No description provided for @historyDaysAgo.
  ///
  /// In vi, this message translates to:
  /// **'{count} ngày trước'**
  String historyDaysAgo(int count);

  /// No description provided for @songSearch.
  ///
  /// In vi, this message translates to:
  /// **'TÌM BÀI'**
  String get songSearch;

  /// No description provided for @songList.
  ///
  /// In vi, this message translates to:
  /// **'DANH MỤC'**
  String get songList;

  /// No description provided for @songSelected.
  ///
  /// In vi, this message translates to:
  /// **'ĐÃ CHỌN'**
  String get songSelected;

  /// No description provided for @panelSuggestions.
  ///
  /// In vi, this message translates to:
  /// **'GỢI Ý CHO BẠN'**
  String get panelSuggestions;

  /// No description provided for @panelCategories.
  ///
  /// In vi, this message translates to:
  /// **'DANH MỤC'**
  String get panelCategories;

  /// No description provided for @browseGenres.
  ///
  /// In vi, this message translates to:
  /// **'Thể loại'**
  String get browseGenres;

  /// No description provided for @browseArtists.
  ///
  /// In vi, this message translates to:
  /// **'Nghệ sĩ'**
  String get browseArtists;

  /// No description provided for @artistVietnam.
  ///
  /// In vi, this message translates to:
  /// **'Việt Nam'**
  String get artistVietnam;

  /// No description provided for @artistInternational.
  ///
  /// In vi, this message translates to:
  /// **'Nước ngoài'**
  String get artistInternational;

  /// No description provided for @categoryPopular.
  ///
  /// In vi, this message translates to:
  /// **'Nhạc trẻ'**
  String get categoryPopular;

  /// No description provided for @categoryBolero.
  ///
  /// In vi, this message translates to:
  /// **'Bolero / Trữ tình'**
  String get categoryBolero;

  /// No description provided for @categoryRemix.
  ///
  /// In vi, this message translates to:
  /// **'Nhạc remix'**
  String get categoryRemix;

  /// No description provided for @categoryKids.
  ///
  /// In vi, this message translates to:
  /// **'Thiếu nhi'**
  String get categoryKids;

  /// No description provided for @categoryTopSearched.
  ///
  /// In vi, this message translates to:
  /// **'Tìm nhiều nhất'**
  String get categoryTopSearched;

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

  /// No description provided for @voiceSearch.
  ///
  /// In vi, this message translates to:
  /// **'Tìm kiếm bằng giọng nói'**
  String get voiceSearch;

  /// No description provided for @stopVoiceSearch.
  ///
  /// In vi, this message translates to:
  /// **'Dừng tìm kiếm bằng giọng nói'**
  String get stopVoiceSearch;

  /// No description provided for @voiceSearchPermissionDenied.
  ///
  /// In vi, this message translates to:
  /// **'Cần cho phép dùng micro để tìm kiếm bằng giọng nói.'**
  String get voiceSearchPermissionDenied;

  /// No description provided for @voiceSearchUnavailable.
  ///
  /// In vi, this message translates to:
  /// **'Thiết bị hiện không hỗ trợ tìm kiếm bằng giọng nói.'**
  String get voiceSearchUnavailable;

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

  /// No description provided for @playbackIdleOsd.
  ///
  /// In vi, this message translates to:
  /// **'Mời chọn bài'**
  String get playbackIdleOsd;

  /// No description provided for @playbackIdleDemo.
  ///
  /// In vi, this message translates to:
  /// **'VIDEO DEMO'**
  String get playbackIdleDemo;

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

  /// No description provided for @playbackRetrying.
  ///
  /// In vi, this message translates to:
  /// **'Đang thử lại video...'**
  String get playbackRetrying;

  /// No description provided for @queueAdded.
  ///
  /// In vi, this message translates to:
  /// **'Đã thêm vào hàng chờ'**
  String get queueAdded;

  /// No description provided for @queueDuplicate.
  ///
  /// In vi, this message translates to:
  /// **'Bài hát này đã có trong hàng chờ'**
  String get queueDuplicate;

  /// No description provided for @queueRemoved.
  ///
  /// In vi, this message translates to:
  /// **'Đã xóa khỏi hàng chờ'**
  String get queueRemoved;

  /// No description provided for @undo.
  ///
  /// In vi, this message translates to:
  /// **'Hoàn tác'**
  String get undo;

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

  /// No description provided for @queueRepeatOff.
  ///
  /// In vi, this message translates to:
  /// **'Lặp lại: Tắt'**
  String get queueRepeatOff;

  /// No description provided for @queueRepeatAll.
  ///
  /// In vi, this message translates to:
  /// **'Lặp lại: Tất cả'**
  String get queueRepeatAll;

  /// No description provided for @queueRepeatOne.
  ///
  /// In vi, this message translates to:
  /// **'Lặp lại: 1 bài'**
  String get queueRepeatOne;

  /// No description provided for @queueShuffle.
  ///
  /// In vi, this message translates to:
  /// **'Phát ngẫu nhiên'**
  String get queueShuffle;

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

  /// No description provided for @licenseInputTitle.
  ///
  /// In vi, this message translates to:
  /// **'Nhập mã bản quyền'**
  String get licenseInputTitle;

  /// No description provided for @licenseInputSubtitle.
  ///
  /// In vi, this message translates to:
  /// **'Nhập key được cấp để kích hoạt máy này'**
  String get licenseInputSubtitle;

  /// No description provided for @licenseInputPlaceholder.
  ///
  /// In vi, this message translates to:
  /// **'VD: VKTV-4F9A-2K7X'**
  String get licenseInputPlaceholder;

  /// No description provided for @licenseKeyboardSubmit.
  ///
  /// In vi, this message translates to:
  /// **'KÍCH HOẠT'**
  String get licenseKeyboardSubmit;

  /// No description provided for @licenseErrorNotFound.
  ///
  /// In vi, this message translates to:
  /// **'Key không tồn tại'**
  String get licenseErrorNotFound;

  /// No description provided for @licenseErrorActiveOther.
  ///
  /// In vi, this message translates to:
  /// **'Key đang dùng trên thiết bị khác'**
  String get licenseErrorActiveOther;

  /// No description provided for @licenseErrorNetwork.
  ///
  /// In vi, this message translates to:
  /// **'Không kết nối được máy chủ. Thử lại.'**
  String get licenseErrorNetwork;

  /// No description provided for @licenseCheckingMessage.
  ///
  /// In vi, this message translates to:
  /// **'Đang kiểm tra bản quyền...'**
  String get licenseCheckingMessage;

  /// No description provided for @licensePendingTitle.
  ///
  /// In vi, this message translates to:
  /// **'Đang chờ quản lý duyệt'**
  String get licensePendingTitle;

  /// No description provided for @licensePendingSubtitle.
  ///
  /// In vi, this message translates to:
  /// **'Yêu cầu kích hoạt đã được gửi. Máy sẽ tự vào ngay khi được duyệt.'**
  String get licensePendingSubtitle;

  /// No description provided for @licenseChangeKey.
  ///
  /// In vi, this message translates to:
  /// **'Nhập key khác'**
  String get licenseChangeKey;

  /// No description provided for @licenseLockedTitle.
  ///
  /// In vi, this message translates to:
  /// **'Key đã bị khoá'**
  String get licenseLockedTitle;

  /// No description provided for @licenseLockedSubtitle.
  ///
  /// In vi, this message translates to:
  /// **'Liên hệ quản lý để được hỗ trợ.'**
  String get licenseLockedSubtitle;

  /// No description provided for @licenseExpiredTitle.
  ///
  /// In vi, this message translates to:
  /// **'Key đã hết hạn'**
  String get licenseExpiredTitle;

  /// No description provided for @licenseExpiredSubtitle.
  ///
  /// In vi, this message translates to:
  /// **'Liên hệ quản lý để gia hạn.'**
  String get licenseExpiredSubtitle;

  /// No description provided for @licenseRetry.
  ///
  /// In vi, this message translates to:
  /// **'Kiểm tra lại'**
  String get licenseRetry;

  /// No description provided for @licenseOfflineTitle.
  ///
  /// In vi, this message translates to:
  /// **'Không có kết nối mạng'**
  String get licenseOfflineTitle;

  /// No description provided for @seekBadgeStep.
  ///
  /// In vi, this message translates to:
  /// **'10s'**
  String get seekBadgeStep;

  /// No description provided for @licenseOfflineSubtitle.
  ///
  /// In vi, this message translates to:
  /// **'Kiểm tra kết nối mạng của máy rồi thử lại.'**
  String get licenseOfflineSubtitle;

  /// No description provided for @settingsCheckUpdate.
  ///
  /// In vi, this message translates to:
  /// **'Kiểm tra cập nhật'**
  String get settingsCheckUpdate;

  /// No description provided for @settingsUpdateChecking.
  ///
  /// In vi, this message translates to:
  /// **'Đang kiểm tra...'**
  String get settingsUpdateChecking;

  /// No description provided for @settingsUpdateUpToDate.
  ///
  /// In vi, this message translates to:
  /// **'Không có bản cập nhật mới'**
  String get settingsUpdateUpToDate;

  /// No description provided for @settingsUpdateAvailable.
  ///
  /// In vi, this message translates to:
  /// **'Có bản mới {version}'**
  String settingsUpdateAvailable(String version);

  /// No description provided for @settingsUpdateInstall.
  ///
  /// In vi, this message translates to:
  /// **'Cập nhật'**
  String get settingsUpdateInstall;

  /// No description provided for @settingsUpdateDownloading.
  ///
  /// In vi, this message translates to:
  /// **'Đang tải {percent}%'**
  String settingsUpdateDownloading(int percent);

  /// No description provided for @settingsUpdateVerifying.
  ///
  /// In vi, this message translates to:
  /// **'Đang kiểm tra tệp...'**
  String get settingsUpdateVerifying;

  /// No description provided for @settingsUpdateInstalling.
  ///
  /// In vi, this message translates to:
  /// **'Đang cài đặt...'**
  String get settingsUpdateInstalling;

  /// No description provided for @settingsUpdateInstallRequestedTitle.
  ///
  /// In vi, this message translates to:
  /// **'Đã mở trình cài đặt'**
  String get settingsUpdateInstallRequestedTitle;

  /// No description provided for @settingsUpdateInstallRequestedSubtitle.
  ///
  /// In vi, this message translates to:
  /// **'Chưa rõ đã cài đặt xong chưa. Nếu ứng dụng chưa được cập nhật, hãy nhấn \"Cài đặt lại\".'**
  String get settingsUpdateInstallRequestedSubtitle;

  /// No description provided for @settingsUpdateReinstall.
  ///
  /// In vi, this message translates to:
  /// **'Cài đặt lại'**
  String get settingsUpdateReinstall;

  /// No description provided for @settingsUpdateInstalledTitle.
  ///
  /// In vi, this message translates to:
  /// **'Đã cập nhật xong'**
  String get settingsUpdateInstalledTitle;

  /// No description provided for @settingsUpdateInstalledSubtitle.
  ///
  /// In vi, this message translates to:
  /// **'Bản mới đã được cài đặt.'**
  String get settingsUpdateInstalledSubtitle;

  /// No description provided for @settingsUpdateErrorNetwork.
  ///
  /// In vi, this message translates to:
  /// **'Không kiểm tra được. Kiểm tra kết nối mạng rồi thử lại.'**
  String get settingsUpdateErrorNetwork;

  /// No description provided for @settingsUpdateErrorDownload.
  ///
  /// In vi, this message translates to:
  /// **'Tải bản cập nhật thất bại. Thử lại.'**
  String get settingsUpdateErrorDownload;

  /// No description provided for @settingsUpdateErrorChecksum.
  ///
  /// In vi, this message translates to:
  /// **'Tệp tải về bị hỏng. Đã xoá, vui lòng thử lại.'**
  String get settingsUpdateErrorChecksum;

  /// No description provided for @settingsUpdateErrorInstall.
  ///
  /// In vi, this message translates to:
  /// **'Không mở được trình cài đặt.'**
  String get settingsUpdateErrorInstall;

  /// No description provided for @settingsUpdateErrorInstallRejected.
  ///
  /// In vi, this message translates to:
  /// **'Hệ thống đã từ chối bản cập nhật này. Hãy kiểm tra lại bản mới.'**
  String get settingsUpdateErrorInstallRejected;

  /// No description provided for @settingsUpdateErrorInstallCancelled.
  ///
  /// In vi, this message translates to:
  /// **'Bạn đã huỷ cài đặt. Nhấn để cài lại tệp đã tải.'**
  String get settingsUpdateErrorInstallCancelled;

  /// No description provided for @settingsUpdateErrorPermission.
  ///
  /// In vi, this message translates to:
  /// **'Cần cho phép cài ứng dụng từ nguồn này.'**
  String get settingsUpdateErrorPermission;

  /// No description provided for @settingsUpdateOpenPermission.
  ///
  /// In vi, this message translates to:
  /// **'Mở cài đặt'**
  String get settingsUpdateOpenPermission;

  /// No description provided for @settingsUpdateRetry.
  ///
  /// In vi, this message translates to:
  /// **'Thử lại'**
  String get settingsUpdateRetry;

  /// No description provided for @settingsUpdateDownloadingIndeterminate.
  ///
  /// In vi, this message translates to:
  /// **'Đang tải...'**
  String get settingsUpdateDownloadingIndeterminate;

  /// No description provided for @remotePairingTitle.
  ///
  /// In vi, this message translates to:
  /// **'Kết nối điện thoại'**
  String get remotePairingTitle;

  /// No description provided for @remotePairingSubtitle.
  ///
  /// In vi, this message translates to:
  /// **'Mở ứng dụng WeTube Remote trên điện thoại, quét mã QR hoặc nhập mã 6 số bên dưới.'**
  String get remotePairingSubtitle;

  /// No description provided for @remotePairingCodeLabel.
  ///
  /// In vi, this message translates to:
  /// **'Mã ghép đôi'**
  String get remotePairingCodeLabel;

  /// No description provided for @remotePairingExpiresIn.
  ///
  /// In vi, this message translates to:
  /// **'Mã còn hiệu lực {time}'**
  String remotePairingExpiresIn(String time);

  /// No description provided for @remotePairingExpired.
  ///
  /// In vi, this message translates to:
  /// **'Mã đã hết hạn. Hãy cấp mã mới.'**
  String get remotePairingExpired;

  /// No description provided for @remotePairingNewCode.
  ///
  /// In vi, this message translates to:
  /// **'Cấp mã mới'**
  String get remotePairingNewCode;

  /// No description provided for @remotePairingRequesting.
  ///
  /// In vi, this message translates to:
  /// **'Đang lấy mã...'**
  String get remotePairingRequesting;

  /// No description provided for @remotePairingStatusTitle.
  ///
  /// In vi, this message translates to:
  /// **'Trạng thái kết nối'**
  String get remotePairingStatusTitle;

  /// No description provided for @remotePairingPhoneConnected.
  ///
  /// In vi, this message translates to:
  /// **'Đã kết nối điện thoại'**
  String get remotePairingPhoneConnected;

  /// No description provided for @remotePairingPhoneOffline.
  ///
  /// In vi, this message translates to:
  /// **'Điện thoại đang ngoại tuyến'**
  String get remotePairingPhoneOffline;

  /// No description provided for @remotePairingNotPaired.
  ///
  /// In vi, this message translates to:
  /// **'Chưa ghép đôi với điện thoại nào'**
  String get remotePairingNotPaired;

  /// No description provided for @remotePairingDisconnect.
  ///
  /// In vi, this message translates to:
  /// **'Ngắt kết nối điện thoại'**
  String get remotePairingDisconnect;

  /// No description provided for @remotePairingDisconnectHint.
  ///
  /// In vi, this message translates to:
  /// **'Điện thoại đang ghép đôi sẽ mất quyền điều khiển ngay lập tức.'**
  String get remotePairingDisconnectHint;

  /// No description provided for @remotePairingHint.
  ///
  /// In vi, this message translates to:
  /// **'Điện thoại và đầu xe không cần chung một mạng Wi-Fi.'**
  String get remotePairingHint;

  /// No description provided for @remotePairingErrorNetwork.
  ///
  /// In vi, this message translates to:
  /// **'Không kết nối được máy chủ. Kiểm tra mạng rồi thử lại.'**
  String get remotePairingErrorNetwork;

  /// No description provided for @remotePairingErrorBackend.
  ///
  /// In vi, this message translates to:
  /// **'Máy chủ từ chối yêu cầu. Vui lòng thử lại.'**
  String get remotePairingErrorBackend;

  /// No description provided for @remotePairingErrorMalformed.
  ///
  /// In vi, this message translates to:
  /// **'Máy chủ trả về dữ liệu không hợp lệ.'**
  String get remotePairingErrorMalformed;
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
