// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Viet KTV';

  @override
  String get languageVi => 'VI';

  @override
  String get languageEn => 'EN';

  @override
  String get homeWelcome => 'WELCOME TO';

  @override
  String get homeSubtitle => 'Choose a music source to begin';

  @override
  String get sourceYoutubeSubtitle => 'A massive music & video\nlibrary';

  @override
  String get sourceSoundcloudSubtitle => 'Exclusive DJ & Remix\ntracks';

  @override
  String get sourceMcloudSubtitle => 'High-quality DJ Sets\n& Podcasts';

  @override
  String get topConnectPhone => 'PHONE LINK';

  @override
  String get topSettings => 'SETTINGS';

  @override
  String get topExit => 'EXIT';

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
  String get songSearch => 'SEARCH';

  @override
  String get songList => 'LIST';

  @override
  String get songSelected => 'SELECTED';

  @override
  String get karaokeLabel => 'Karaoke';

  @override
  String get panelSuggestions => 'RECOMMENDED FOR YOU';

  @override
  String get panelSearchResults => 'SEARCH RESULTS';

  @override
  String get searchPlaceholder => 'Search songs, singers, or keywords...';

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
  String get playbackLoading => 'Loading video...';

  @override
  String get playbackFailed => 'Couldn\'t play this video.';

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
}
