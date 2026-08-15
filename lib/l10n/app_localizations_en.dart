// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'WeTube';

  @override
  String get languageVi => 'VI';

  @override
  String get languageEn => 'EN';

  @override
  String get homeWelcome => 'Choose a music source to begin';

  @override
  String get homeSubtitle => 'Use the remote, D-pad, or touch screen to select';

  @override
  String get splashTagline => 'Neon karaoke for modern rooms';

  @override
  String get splashPreparing => 'Starting the system...';

  @override
  String get sourceYoutubeSubtitle => 'A massive music & video\nlibrary';

  @override
  String get sourceSoundcloudSubtitle => 'Exclusive DJ & Remix\ntracks';

  @override
  String get topConnectPhone => 'PHONE LINK';

  @override
  String get topSettings => 'SETTINGS';

  @override
  String get settingsLanguage => 'Language';

  @override
  String get settingsClearFavorites => 'Clear favorites';

  @override
  String get settingsClearHistory => 'Clear play history';

  @override
  String get settingsConfirmAgain => 'Tap again to confirm';

  @override
  String get settingsViewHistory => 'View play history';

  @override
  String get settingsDevice => 'Device link';

  @override
  String get settingsAudio => 'Audio';

  @override
  String get settingsDisplay => 'Display';

  @override
  String get settingsInterface => 'Interface';

  @override
  String get settingsVideoPlayback => 'Video playback';

  @override
  String get settingsLanguageSection => 'Language';

  @override
  String get settingsLanguageUnavailable =>
      'This language needs a translation pack before it can be enabled.';

  @override
  String get languageFrench => 'French';

  @override
  String get languageSpanish => 'Spanish';

  @override
  String get languageGerman => 'German';

  @override
  String get languageJapanese => 'Japanese';

  @override
  String get languageKorean => 'Korean';

  @override
  String get languageChinese => 'Chinese';

  @override
  String get languageThai => 'Thai';

  @override
  String get languageIndonesian => 'Indonesian';

  @override
  String get languagePortuguese => 'Portuguese';

  @override
  String get languageRussian => 'Russian';

  @override
  String get settingsSongManagement => 'Song management';

  @override
  String get settingsAccount => 'Account';

  @override
  String get settingsSystem => 'System';

  @override
  String get settingsInfo => 'Info';

  @override
  String get settingsPreview => 'PREVIEW';

  @override
  String get settingsOsdPreview => 'OSD PREVIEW';

  @override
  String get settingsGuide => 'GUIDE';

  @override
  String get settingsQualitySection => '1. PLAYBACK QUALITY';

  @override
  String get settingsPlaybackModeSection => '2. PLAYBACK MODE';

  @override
  String get settingsOtherOptionsSection => '3. OTHER OPTIONS';

  @override
  String get settingsDemoVideoSection =>
      '4. DEMO VIDEO WHEN NO SONG IS SELECTED';

  @override
  String get settingsQuality4k => '4K (2160p)';

  @override
  String get settingsQualityFhd => 'Full HD (1080p)';

  @override
  String get settingsQualityHd => 'HD (720p)';

  @override
  String get settingsQualitySd => 'SD (480p)';

  @override
  String get settingsQualityAuto => 'Auto';

  @override
  String get settingsQualityAutoDescription => 'Choose quality from network';

  @override
  String get settingsPlayContinuous => 'Continuous playback';

  @override
  String get settingsPlayContinuousDescription =>
      'Automatically play the next queued song';

  @override
  String get settingsRepeatAll => 'Repeat playlist';

  @override
  String get settingsRepeatAllDescription => 'Repeat the current selected list';

  @override
  String get settingsRepeatOne => 'Repeat one song';

  @override
  String get settingsRepeatOneDescription =>
      'Repeat the currently playing song';

  @override
  String get settingsShuffle => 'Shuffle playback';

  @override
  String get settingsShuffleDescription => 'Play songs in the list randomly';

  @override
  String get settingsBuffer => 'Buffer ahead';

  @override
  String get settingsBufferDescription =>
      'Increase buffering time for smoother video';

  @override
  String settingsSeconds(int count) {
    return '$count sec';
  }

  @override
  String get settingsAutoMv => 'Auto-play MV video';

  @override
  String get settingsAutoMvDescription =>
      'Automatically play MV video when available';

  @override
  String get settingsCaptions => 'Show captions';

  @override
  String get settingsCaptionsDescription =>
      'Automatically load and show captions when available';

  @override
  String get settingsDemoEnabled =>
      'Enable demo video when no song is selected';

  @override
  String get settingsDemoEnabledDescription =>
      'Automatically play demo video before a song is chosen';

  @override
  String get settingsDemoPick => 'Choose demo video';

  @override
  String get settingsDemoFile => 'Tropical Beach.mp4';

  @override
  String get settingsOsdText => 'Scrolling OSD text when nobody is singing';

  @override
  String get settingsOsdTextValue => 'Choose a song';

  @override
  String settingsDemoCurrent(Object file) {
    return 'Current demo video: $file';
  }

  @override
  String get settingsOsdDescription =>
      'This content appears as scrolling OSD text when nobody is singing.';

  @override
  String get settingsVideoGuide =>
      'This feature shows lively demo video and OSD content to attract users before a song is selected.';

  @override
  String get settingsDeviceQr => 'Remote-control QR code';

  @override
  String get settingsDeviceName => 'Device name: car-app';

  @override
  String get settingsDeviceHint =>
      'Scan the QR code from a phone to control song selection, volume, and queue.';

  @override
  String get settingsMasterVolume => 'Master volume';

  @override
  String get settingsMusicVolume => 'Music volume';

  @override
  String get settingsVocalBoost => 'Vocal boost';

  @override
  String get settingsAudioHint =>
      'Balance levels so background music is clear and vocals stand out without harshness.';

  @override
  String get settingsLyricSize => 'Lyric text size';

  @override
  String get settingsVisualizer => 'Show visualizer';

  @override
  String get settingsGlowLevel => 'Glow intensity';

  @override
  String get settingsDisplayHint =>
      'Tune readability for TV and Android phone screens.';

  @override
  String get settingsTheme => 'Neon theme';

  @override
  String get settingsThemeDefault => 'Karaoke neon';

  @override
  String get settingsParticles => 'Background particles';

  @override
  String get settingsInterfaceHint =>
      'Keep the interface vivid while staying light enough for common Android devices.';

  @override
  String get settingsDataSection => '1. SONG DATA';

  @override
  String get settingsHistorySection => '2. HISTORY & FAVORITES';

  @override
  String get settingsManagementHint =>
      'Delete actions require two taps to prevent accidental data loss.';

  @override
  String get settingsAccountName => 'Account name';

  @override
  String get settingsAccountPlan => 'Current plan: Local';

  @override
  String get settingsAccountHint => 'Login and cloud sync can be added later.';

  @override
  String get settingsNetworkCheck => 'Check network connection';

  @override
  String get settingsSdkCheck => 'Check Music SDK';

  @override
  String get settingsClearCache => 'Clear image/video cache';

  @override
  String get settingsNetworkStatus => 'Network status';

  @override
  String get settingsDeviceInfo => 'Device information';

  @override
  String get settingsStorageInfo => 'Storage';

  @override
  String get settingsSystemLoading => 'Reading system information...';

  @override
  String get settingsSystemUnavailable => 'Couldn\'t read system information.';

  @override
  String get settingsActionUnavailable =>
      'This feature needs backend or system permission to be completed.';

  @override
  String get settingsNetworkOk =>
      'The app is running. Detailed network checks will use the room backend.';

  @override
  String get settingsSdkOk =>
      'MusicSDK initializes automatically when a valid license key is provided.';

  @override
  String get settingsCacheCleared => 'In-memory image cache cleared.';

  @override
  String get settingsSystemHint =>
      'Use this when checking device, network, or temporary data.';

  @override
  String get settingsAppVersion => 'App version';

  @override
  String get settingsAndroidSupport => 'Supports Android 10 and above';

  @override
  String get settingsInfoHint =>
      'System and version information for technical support.';

  @override
  String get topHome => 'HOME';

  @override
  String get topExit => 'EXIT';

  @override
  String get exitDialogTitle => 'Exit app?';

  @override
  String get exitDialogMessage =>
      'Choose a system action for the karaoke device.';

  @override
  String get exitApp => 'Exit';

  @override
  String get restartApp => 'Restart';

  @override
  String get shutdownDevice => 'Power off';

  @override
  String get cancel => 'Cancel';

  @override
  String get restartUnavailable =>
      'Restarting the app requires a native integration.';

  @override
  String get shutdownUnavailable =>
      'Power off requires firmware-level system permission.';

  @override
  String get hintSelect => 'Select';

  @override
  String get hintBack => 'Back';

  @override
  String get hintClearQueue => 'Clear entire queue';

  @override
  String hintQueueCount(int count) {
    return 'Queue list ($count)';
  }

  @override
  String get hintNavigate => 'Navigate';

  @override
  String get hintChooseAndPlay => 'Select / Play song';

  @override
  String hintSelectedQueue(int count) {
    return 'View selected list ($count)';
  }

  @override
  String get hintFavorites => 'Favorites';

  @override
  String get navFavorites => 'Favorites';

  @override
  String get favoriteAddTooltip => 'Add to favorites';

  @override
  String get favoriteRemoveTooltip => 'Remove from favorites';

  @override
  String get favoritesEmpty =>
      'No favorite songs yet.\nTap the heart on a song to add one.';

  @override
  String get historyTitle => 'PLAY HISTORY';

  @override
  String get historyEmpty => 'No songs in your history yet.';

  @override
  String get historyRemoveTooltip => 'Remove from history';

  @override
  String get historyJustNow => 'Just now';

  @override
  String historyMinutesAgo(int count) {
    return '$count min ago';
  }

  @override
  String historyHoursAgo(int count) {
    return '$count hr ago';
  }

  @override
  String historyDaysAgo(int count) {
    return '${count}d ago';
  }

  @override
  String get songSearch => 'SEARCH';

  @override
  String get songList => 'CATEGORIES';

  @override
  String get songSelected => 'SELECTED';

  @override
  String get panelSuggestions => 'RECOMMENDED FOR YOU';

  @override
  String get panelCategories => 'CATEGORIES';

  @override
  String get browseGenres => 'Genres';

  @override
  String get browseArtists => 'Artists';

  @override
  String get artistVietnam => 'Vietnam';

  @override
  String get artistInternational => 'International';

  @override
  String get categoryPopular => 'Pop hits';

  @override
  String get categoryBolero => 'Bolero / Ballad';

  @override
  String get categoryRemix => 'Remix';

  @override
  String get categoryKids => 'Kids';

  @override
  String get categoryTopSearched => 'Top searched';

  @override
  String get panelSearchResults => 'SEARCH RESULTS';

  @override
  String get searchPlaceholder => 'Search songs, singers, or keywords...';

  @override
  String get voiceSearch => 'Voice search';

  @override
  String get stopVoiceSearch => 'Stop voice search';

  @override
  String get voiceSearchPermissionDenied =>
      'Allow microphone access to search by voice.';

  @override
  String get voiceSearchUnavailable =>
      'Voice search is not available on this device.';

  @override
  String searchResultCount(int count) {
    return '$count results';
  }

  @override
  String get searchEmpty => 'No matching results found';

  @override
  String get searchIdlePrompt => 'Type a keyword and press TÌM to search';

  @override
  String get searchLoading => 'Searching...';

  @override
  String get searchFailed => 'Couldn\'t load results. Try again.';

  @override
  String get recommendationsLoading => 'Loading suggestions...';

  @override
  String get recommendationsFailed => 'Couldn\'t load suggestions.';

  @override
  String get recommendationsEmpty => 'No suggestions yet.';

  @override
  String get playbackIdlePrompt => 'Select a song to begin';

  @override
  String get playbackIdleOsd => 'Choose a song';

  @override
  String get playbackIdleDemo => 'DEMO VIDEO';

  @override
  String get playbackLoading => 'Loading video...';

  @override
  String get playbackFailed => 'Couldn\'t play this video.';

  @override
  String get playbackRetrying => 'Retrying video...';

  @override
  String get queueAdded => 'Added to queue';

  @override
  String get queueDuplicate => 'This song is already in the queue';

  @override
  String get queueRemoved => 'Removed from queue';

  @override
  String get undo => 'Undo';

  @override
  String queueItemCount(int count) {
    return '$count songs';
  }

  @override
  String get queueEmpty =>
      'No songs queued yet.\nPress + on a search result to add one.';

  @override
  String get queueRemoveTooltip => 'Remove from queue';

  @override
  String get queueRepeatOff => 'Repeat: Off';

  @override
  String get queueRepeatAll => 'Repeat: All';

  @override
  String get queueRepeatOne => 'Repeat: One';

  @override
  String get queueShuffle => 'Shuffle';

  @override
  String get keyboardSearch => 'SEARCH';

  @override
  String get keyboardClear => 'CLEAR';

  @override
  String get keyboardSpace => 'SPACE';

  @override
  String get keyboardBack => 'BACKSPACE';

  @override
  String get keyboardNumberMode => '123';

  @override
  String get mockYoutubeChannel => 'Karaoke 4 You';

  @override
  String get mockOfficialChannel => 'Son Tung M-TP Official';

  @override
  String get mockBeatChannel => 'Selected Karaoke Tracks';

  @override
  String get mockToneNam => 'Male Key Karaoke';

  @override
  String get mockAcoustic => 'Acoustic Cover';

  @override
  String get mockPiano => 'Piano Cover';

  @override
  String get mockLive => 'Live Performance';

  @override
  String get mockDjRemix => 'Dai Meo Remix';

  @override
  String get licenseInputTitle => 'Enter license key';

  @override
  String get licenseInputSubtitle =>
      'Enter the key issued for this machine to activate it';

  @override
  String get licenseInputPlaceholder => 'e.g. VKTV-4F9A-2K7X';

  @override
  String get licenseKeyboardSubmit => 'ACTIVATE';

  @override
  String get licenseErrorNotFound => 'Key not found';

  @override
  String get licenseErrorActiveOther =>
      'Key is already in use on another device';

  @override
  String get licenseErrorNetwork => 'Could not reach the server. Try again.';

  @override
  String get licenseCheckingMessage => 'Checking license...';

  @override
  String get licensePendingTitle => 'Waiting for admin approval';

  @override
  String get licensePendingSubtitle =>
      'Your activation request was sent. This device will unlock automatically once approved.';

  @override
  String get licenseChangeKey => 'Enter a different key';

  @override
  String get licenseLockedTitle => 'Key is locked';

  @override
  String get licenseLockedSubtitle => 'Contact your admin for help.';

  @override
  String get licenseExpiredTitle => 'Key has expired';

  @override
  String get licenseExpiredSubtitle => 'Contact your admin to renew.';

  @override
  String get licenseRetry => 'Check again';

  @override
  String get licenseOfflineTitle => 'No network connection';

  @override
  String get seekBadgeStep => '10s';

  @override
  String get licenseOfflineSubtitle =>
      'Check this device\'s network connection and try again.';

  @override
  String get settingsCheckUpdate => 'Check for updates';

  @override
  String get settingsUpdateChecking => 'Checking...';

  @override
  String get settingsUpdateUpToDate => 'No new version available';

  @override
  String settingsUpdateAvailable(String version) {
    return 'Version $version available';
  }

  @override
  String get settingsUpdateInstall => 'Update';

  @override
  String settingsUpdateDownloading(int percent) {
    return 'Downloading $percent%';
  }

  @override
  String get settingsUpdateVerifying => 'Verifying file...';

  @override
  String get settingsUpdateInstalling => 'Installing...';

  @override
  String get settingsUpdateInstallRequestedTitle => 'Installer opened';

  @override
  String get settingsUpdateInstallRequestedSubtitle =>
      'We can\'t tell if it finished. If the app hasn\'t updated, tap \"Reinstall\".';

  @override
  String get settingsUpdateReinstall => 'Reinstall';

  @override
  String get settingsUpdateInstalledTitle => 'Update installed';

  @override
  String get settingsUpdateInstalledSubtitle =>
      'The new version has been installed.';

  @override
  String get settingsUpdateErrorNetwork =>
      'Could not check. Check your connection and try again.';

  @override
  String get settingsUpdateErrorDownload => 'Download failed. Try again.';

  @override
  String get settingsUpdateErrorChecksum =>
      'The downloaded file was corrupt. It has been deleted; please try again.';

  @override
  String get settingsUpdateErrorInstall => 'Could not open the installer.';

  @override
  String get settingsUpdateErrorInstallRejected =>
      'The system rejected this update. Check for a new version.';

  @override
  String get settingsUpdateErrorInstallCancelled =>
      'You cancelled the installation. Tap to install the downloaded file again.';

  @override
  String get settingsUpdateErrorPermission =>
      'Allow installing apps from this source first.';

  @override
  String get settingsUpdateOpenPermission => 'Open settings';

  @override
  String get settingsUpdateRetry => 'Try again';

  @override
  String get settingsUpdateDownloadingIndeterminate => 'Downloading...';
}
