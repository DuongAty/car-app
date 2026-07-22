// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Vietnamese (`vi`).
class AppLocalizationsVi extends AppLocalizations {
  AppLocalizationsVi([String locale = 'vi']) : super(locale);

  @override
  String get appTitle => 'Viet KTV';

  @override
  String get languageVi => 'VI';

  @override
  String get languageEn => 'EN';

  @override
  String get homeWelcome => 'CHÀO MỪNG ĐẾN VỚI';

  @override
  String get homeSubtitle => 'Chọn nguồn nhạc để bắt đầu';

  @override
  String get sourceYoutubeSubtitle => 'Kho nhạc & Video\nkhổng lồ';

  @override
  String get sourceSoundcloudSubtitle => 'Nhạc DJ & Remix\nđộc quyền';

  @override
  String get sourceMcloudSubtitle => 'DJ Sets & Podcasts\nchất lượng cao';

  @override
  String get topConnectPhone => 'KẾT NỐI ĐT';

  @override
  String get topSettings => 'CÀI ĐẶT';

  @override
  String get topExit => 'THOÁT';

  @override
  String get hintSelect => 'Chọn';

  @override
  String get hintBack => 'Quay lại';

  @override
  String get hintClearQueue => 'Xóa tất cả hàng chờ';

  @override
  String hintQueueCount(int count) {
    return 'Danh sách chờ ($count)';
  }

  @override
  String get hintNavigate => 'Điều hướng';

  @override
  String get hintChooseAndPlay => 'Chọn / Phát bài';

  @override
  String hintSelectedQueue(int count) {
    return 'Xem danh sách đã chọn ($count)';
  }

  @override
  String get hintFavorites => 'Yêu thích';

  @override
  String get songSearch => 'TÌM BÀI';

  @override
  String get songList => 'DANH SÁCH';

  @override
  String get songSelected => 'ĐÃ CHỌN';

  @override
  String get karaokeLabel => 'Karaoke';

  @override
  String get panelSuggestions => 'GỢI Ý CHO BẠN';

  @override
  String get panelSearchResults => 'KẾT QUẢ TÌM KIẾM';

  @override
  String get searchPlaceholder => 'Tìm bài hát, ca sĩ hoặc từ khóa...';

  @override
  String searchResultCount(int count) {
    return '$count kết quả';
  }

  @override
  String get searchEmpty => 'Không có kết quả phù hợp';

  @override
  String get searchIdlePrompt => 'Nhập từ khóa rồi bấm TÌM để tìm kiếm';

  @override
  String get searchLoading => 'Đang tìm kiếm...';

  @override
  String get searchFailed => 'Không tải được kết quả. Thử lại.';

  @override
  String get recommendationsLoading => 'Đang tải gợi ý...';

  @override
  String get recommendationsFailed => 'Không tải được gợi ý.';

  @override
  String get recommendationsEmpty => 'Chưa có gợi ý nào.';

  @override
  String get playbackIdlePrompt => 'Chọn một bài hát để bắt đầu';

  @override
  String get playbackLoading => 'Đang tải video...';

  @override
  String get playbackFailed => 'Không phát được video này.';

  @override
  String queueItemCount(int count) {
    return '$count bài';
  }

  @override
  String get queueEmpty =>
      'Chưa có bài hát nào trong hàng chờ.\nBấm + ở kết quả tìm kiếm để thêm bài hát.';

  @override
  String get queueRemoveTooltip => 'Xóa khỏi hàng chờ';

  @override
  String get keyboardSearch => 'TÌM';

  @override
  String get keyboardClear => 'XÓA';

  @override
  String get keyboardSpace => 'DẤU CÁCH';

  @override
  String get keyboardBack => 'XÓA KÝ TỰ';

  @override
  String get keyboardNumberMode => '123';

  @override
  String get mockYoutubeChannel => 'Karaoke 4 You';

  @override
  String get mockOfficialChannel => 'Sơn Tùng M-TP Official';

  @override
  String get mockBeatChannel => 'Nhạc Karaoke Tuyển Chọn';

  @override
  String get mockToneNam => 'Karaoke Tone Nam';

  @override
  String get mockAcoustic => 'Bản phối Acoustic';

  @override
  String get mockPiano => 'Bản phối Piano';

  @override
  String get mockLive => 'Biểu diễn trực tiếp';

  @override
  String get mockDjRemix => 'Đại Mèo Remix';
}
