import '../../../l10n/app_localizations.dart';
import '../../source_selection/data/models/music_source.dart';

class SongCategory {
  const SongCategory({
    required this.label,
    required this.subtitle,
    required this.seedQuery,
    required this.imageAsset,
    required this.imageSourceUrl,
  });

  final String label;
  final String subtitle;
  final String seedQuery;
  final String imageAsset;
  final String imageSourceUrl;
}

class SongArtist {
  const SongArtist({
    required this.name,
    required this.subtitle,
    required this.seedQuery,
    required this.imageAsset,
    required this.imageSourceUrl,
  });

  final String name;
  final String subtitle;
  final String seedQuery;
  final String imageAsset;
  final String imageSourceUrl;
}

// Attribution/provenance for the bundled preview images. Not shown in the UI —
// genre art comes from Openverse (CC), artist portraits from Wikimedia Commons.
const _genreImageSource = 'https://openverse.org';
const _wikiSource = 'https://commons.wikimedia.org';

/// Curated preset search queries standing in for a real category API — same
/// approach as [recommendationSeedQuery] — tuned per source.
List<SongCategory> songCategoriesFor(
  AppLocalizations l10n,
  MusicSourceLogoStyle style,
) {
  final youtube = [
    SongCategory(
      label: l10n.categoryPopular,
      subtitle: 'Hit V-Pop, ballad mới, bài dễ hát cho phòng karaoke',
      seedQuery: 'nhạc trẻ hot',
      imageAsset: 'assets/browse/pop.jpg',
      imageSourceUrl: _genreImageSource,
    ),
    SongCategory(
      label: l10n.categoryBolero,
      subtitle: 'Bolero, trữ tình, nhạc quê hương và song ca chậm',
      seedQuery: 'bolero trữ tình',
      imageAsset: 'assets/browse/bolero.jpg',
      imageSourceUrl: _genreImageSource,
    ),
    SongCategory(
      label: l10n.categoryRemix,
      subtitle: 'Beat sôi động, remix club, EDM Việt và Vinahouse',
      seedQuery: 'nhạc remix',
      imageAsset: 'assets/browse/remix.jpg',
      imageSourceUrl: _genreImageSource,
    ),
    SongCategory(
      label: 'Ballad',
      subtitle: 'Bản tình ca chậm, dễ vào tone, hợp hát solo',
      seedQuery: 'ballad việt',
      imageAsset: 'assets/browse/genre_ballad.jpg',
      imageSourceUrl: _genreImageSource,
    ),
    SongCategory(
      label: 'Rap / Hip-hop',
      subtitle: 'Rap Việt, R&B, melody rap và bản phối có lời chạy nhanh',
      seedQuery: 'rap việt',
      imageAsset: 'assets/browse/genre_rap.jpg',
      imageSourceUrl: _genreImageSource,
    ),
    SongCategory(
      label: 'Acoustic',
      subtitle: 'Guitar, piano, unplugged, bản hát nhẹ cho giọng mộc',
      seedQuery: 'acoustic việt',
      imageAsset: 'assets/browse/genre_acoustic.jpg',
      imageSourceUrl: _genreImageSource,
    ),
    SongCategory(
      label: 'Song ca',
      subtitle: 'Nam nữ song ca, duet gia đình, bài hát theo cặp',
      seedQuery: 'song ca nam nữ',
      imageAsset: 'assets/browse/genre_duet.jpg',
      imageSourceUrl: _genreImageSource,
    ),
    SongCategory(
      label: 'Nhạc vàng',
      subtitle: 'Tình khúc xưa, nhạc trước 1975, tone nam/nữ phổ biến',
      seedQuery: 'nhạc vàng',
      imageAsset: 'assets/browse/genre_nhac_vang.jpg',
      imageSourceUrl: _genreImageSource,
    ),
    SongCategory(
      label: 'Nhạc xuân',
      subtitle: 'Tết, mùa xuân, liên khúc vui cho gia đình',
      seedQuery: 'nhạc xuân',
      imageAsset: 'assets/browse/genre_xuan.jpg',
      imageSourceUrl: _genreImageSource,
    ),
    SongCategory(
      label: l10n.categoryKids,
      subtitle: 'Thiếu nhi, gia đình, bài vui dễ hát cho trẻ em',
      seedQuery: 'nhạc thiếu nhi',
      imageAsset: 'assets/browse/kids.jpg',
      imageSourceUrl: _genreImageSource,
    ),
    SongCategory(
      label: 'US-UK / K-Pop',
      subtitle: 'Pop quốc tế, K-Pop, hit tiếng Anh và tiếng Hàn',
      seedQuery: 'US UK Kpop',
      imageAsset: 'assets/browse/genre_usuk.jpg',
      imageSourceUrl: _genreImageSource,
    ),
    SongCategory(
      label: 'EDM / Dance',
      subtitle: 'Nhạc sàn, dance pop, beat mạnh cho không khí sôi động',
      seedQuery: 'edm dance việt',
      imageAsset: 'assets/browse/genre_edm.jpg',
      imageSourceUrl: _genreImageSource,
    ),
    SongCategory(
      label: 'Rock Việt',
      subtitle: 'Rock, alternative, ban nhạc và bản hát bốc lửa',
      seedQuery: 'rock việt',
      imageAsset: 'assets/browse/genre_rock.jpg',
      imageSourceUrl: _genreImageSource,
    ),
    SongCategory(
      label: 'Nhạc Trịnh',
      subtitle: 'Trịnh Công Sơn, tình ca da vàng, giai điệu mộc mạc',
      seedQuery: 'nhạc Trịnh Công Sơn',
      imageAsset: 'assets/browse/genre_trinh.jpg',
      imageSourceUrl: _genreImageSource,
    ),
    SongCategory(
      label: 'Dân ca / Quê hương',
      subtitle: 'Dân ca ba miền, quê hương, ví dặm và lý điệu cổ',
      seedQuery: 'dân ca quê hương',
      imageAsset: 'assets/browse/genre_dan_ca.jpg',
      imageSourceUrl: _genreImageSource,
    ),
    SongCategory(
      label: 'Nhạc phim / OST',
      subtitle: 'Nhạc phim Việt và quốc tế, ca khúc chủ đề gây thương nhớ',
      seedQuery: 'nhạc phim OST',
      imageAsset: 'assets/browse/genre_ost.jpg',
      imageSourceUrl: _genreImageSource,
    ),
    SongCategory(
      label: 'Hòa tấu / Không lời',
      subtitle: 'Beat không lời, hòa tấu, nhạc nền cho luyện giọng',
      seedQuery: 'hòa tấu không lời',
      imageAsset: 'assets/browse/genre_instrumental.jpg',
      imageSourceUrl: _genreImageSource,
    ),
    SongCategory(
      label: l10n.categoryTopSearched,
      subtitle: 'Các bài karaoke được tìm nhiều nhất hiện nay',
      seedQuery: 'việt nam hot nhất',
      imageAsset: 'assets/browse/top.jpg',
      imageSourceUrl: _genreImageSource,
    ),
  ];

  return switch (style) {
    MusicSourceLogoStyle.youtube => youtube,
    MusicSourceLogoStyle.soundcloud => [
      ...youtube.take(12),
      SongCategory(
        label: 'Mashup',
        subtitle: 'Mashup, cover, bản phối cộng đồng và remix độc lập',
        seedQuery: 'mashup remix việt',
        imageAsset: 'assets/browse/genre_mashup.jpg',
        imageSourceUrl: _genreImageSource,
      ),
      SongCategory(
        label: 'Indie / Underground',
        subtitle: 'Indie Việt, underground, sáng tác độc lập và bản demo',
        seedQuery: 'indie underground việt',
        imageAsset: 'assets/browse/genre_acoustic.jpg',
        imageSourceUrl: _genreImageSource,
      ),
    ],
  };
}

List<SongArtist> vietnameseArtists() => const [
  SongArtist(
    name: 'Sơn Tùng M-TP',
    subtitle: 'V-Pop • Pop/R&B • nhiều bản hit karaoke',
    seedQuery: 'Sơn Tùng M-TP',
    imageAsset: 'assets/browse/son_tung.jpg',
    imageSourceUrl: _wikiSource,
  ),
  SongArtist(
    name: 'Mỹ Tâm',
    subtitle: 'Ballad • pop Việt • giọng nữ kinh điển',
    seedQuery: 'Mỹ Tâm',
    imageAsset: 'assets/browse/my_tam.jpg',
    imageSourceUrl: _wikiSource,
  ),
  SongArtist(
    name: 'Mỹ Anh',
    subtitle: 'R&B • soul • pop trẻ',
    seedQuery: 'Mỹ Anh',
    imageAsset: 'assets/browse/my_anh.jpg',
    imageSourceUrl: _wikiSource,
  ),
  SongArtist(
    name: 'Đen Vâu',
    subtitle: 'Rap Việt • melody rap • lời nhiều cảm xúc',
    seedQuery: 'Đen Vâu',
    imageAsset: 'assets/browse/den_vau.jpg',
    imageSourceUrl: _wikiSource,
  ),
  SongArtist(
    name: 'Hòa Minzy',
    subtitle: 'Pop ballad • giọng nữ cao • bài hát cảm xúc',
    seedQuery: 'Hòa Minzy',
    imageAsset: 'assets/browse/hoa_minzy.jpg',
    imageSourceUrl: _wikiSource,
  ),
  SongArtist(
    name: 'Noo Phước Thịnh',
    subtitle: 'Pop • dance • ballad nam',
    seedQuery: 'Noo Phước Thịnh',
    imageAsset: 'assets/browse/noo_phuoc_thinh.jpg',
    imageSourceUrl: _wikiSource,
  ),
  SongArtist(
    name: 'Bích Phương',
    subtitle: 'Pop • ballad • hit dễ hát',
    seedQuery: 'Bích Phương',
    imageAsset: 'assets/browse/bich_phuong.jpg',
    imageSourceUrl: _wikiSource,
  ),
  SongArtist(
    name: 'Erik',
    subtitle: 'Pop ballad • vocal nam trẻ',
    seedQuery: 'Erik',
    imageAsset: 'assets/browse/erik.jpg',
    imageSourceUrl: _wikiSource,
  ),
  SongArtist(
    name: 'Đức Phúc',
    subtitle: 'Ballad • tình ca • tone nam sáng',
    seedQuery: 'Đức Phúc',
    imageAsset: 'assets/browse/duc_phuc.jpg',
    imageSourceUrl: _wikiSource,
  ),
  SongArtist(
    name: 'Min',
    subtitle: 'Pop • dance pop • bài hát hiện đại',
    seedQuery: 'Min',
    imageAsset: 'assets/browse/min.jpg',
    imageSourceUrl: _wikiSource,
  ),
  SongArtist(
    name: 'Tóc Tiên',
    subtitle: 'Dance pop • diva pop • sân khấu sôi động',
    seedQuery: 'Tóc Tiên',
    imageAsset: 'assets/browse/toc_tien.jpg',
    imageSourceUrl: _wikiSource,
  ),
  SongArtist(
    name: 'Trúc Nhân',
    subtitle: 'Pop theatrical • lời vui • nhiều bài bắt tai',
    seedQuery: 'Trúc Nhân',
    imageAsset: 'assets/browse/truc_nhan.jpg',
    imageSourceUrl: _wikiSource,
  ),
  SongArtist(
    name: 'Vũ.',
    subtitle: 'Indie pop • acoustic • ballad nhẹ',
    seedQuery: 'Vũ',
    imageAsset: 'assets/browse/vu.jpg',
    imageSourceUrl: _wikiSource,
  ),
  SongArtist(
    name: 'Hoàng Dũng',
    subtitle: 'Indie ballad • tình ca trẻ',
    seedQuery: 'Hoàng Dũng',
    imageAsset: 'assets/browse/hoang_dung.jpg',
    imageSourceUrl: _wikiSource,
  ),
  SongArtist(
    name: 'Phan Mạnh Quỳnh',
    subtitle: 'Ballad tự sự • nhạc phim • lời sâu',
    seedQuery: 'Phan Mạnh Quỳnh',
    imageAsset: 'assets/browse/phan_manh_quynh.jpg',
    imageSourceUrl: _wikiSource,
  ),
  SongArtist(
    name: 'Lệ Quyên',
    subtitle: 'Bolero • trữ tình • nhạc xưa',
    seedQuery: 'Lệ Quyên',
    imageAsset: 'assets/browse/le_quyen.jpg',
    imageSourceUrl: _wikiSource,
  ),
  SongArtist(
    name: 'Quang Lê',
    subtitle: 'Bolero • quê hương • tone nam trữ tình',
    seedQuery: 'Quang Lê',
    imageAsset: 'assets/browse/quang_le.jpg',
    imageSourceUrl: _wikiSource,
  ),
  SongArtist(
    name: 'Như Quỳnh',
    subtitle: 'Nhạc vàng • bolero • giọng nữ trữ tình',
    seedQuery: 'Như Quỳnh',
    imageAsset: 'assets/browse/bolero.jpg',
    imageSourceUrl: _genreImageSource,
  ),
  SongArtist(
    name: 'Hồ Ngọc Hà',
    subtitle: 'Pop • dance • diva sân khấu',
    seedQuery: 'Hồ Ngọc Hà',
    imageAsset: 'assets/browse/ho_ngoc_ha.jpg',
    imageSourceUrl: _wikiSource,
  ),
  SongArtist(
    name: 'Đông Nhi',
    subtitle: 'Pop • dance pop • hit tuổi teen',
    seedQuery: 'Đông Nhi',
    imageAsset: 'assets/browse/dong_nhi.jpg',
    imageSourceUrl: _wikiSource,
  ),
  SongArtist(
    name: 'Soobin Hoàng Sơn',
    subtitle: 'Pop • R&B • rap melody',
    seedQuery: 'Soobin Hoàng Sơn',
    imageAsset: 'assets/browse/soobin.jpg',
    imageSourceUrl: _wikiSource,
  ),
  SongArtist(
    name: 'Jack - J97',
    subtitle: 'Pop • ballad • giai điệu bắt tai',
    seedQuery: 'Jack J97',
    imageAsset: 'assets/browse/jack_j97.jpg',
    imageSourceUrl: _wikiSource,
  ),
  SongArtist(
    name: 'AMEE',
    subtitle: 'Pop • bubblegum pop • giọng nữ trẻ',
    seedQuery: 'AMEE',
    imageAsset: 'assets/browse/amee.jpg',
    imageSourceUrl: _wikiSource,
  ),
  SongArtist(
    name: 'HIEUTHUHAI',
    subtitle: 'Rap • pop rap • hit trẻ thịnh hành',
    seedQuery: 'HIEUTHUHAI',
    imageAsset: 'assets/browse/hieuthuhai.jpg',
    imageSourceUrl: _wikiSource,
  ),
  SongArtist(
    name: 'Hương Tràm',
    subtitle: 'Ballad • vocal nữ nội lực',
    seedQuery: 'Hương Tràm',
    imageAsset: 'assets/browse/huong_tram.jpg',
    imageSourceUrl: _wikiSource,
  ),
  SongArtist(
    name: 'Uyên Linh',
    subtitle: 'Ballad • jazz pop • giọng hát trầm ấm',
    seedQuery: 'Uyên Linh',
    imageAsset: 'assets/browse/uyen_linh.jpg',
    imageSourceUrl: _wikiSource,
  ),
  SongArtist(
    name: 'Đàm Vĩnh Hưng',
    subtitle: 'Pop • bolero • nhạc trữ tình sân khấu',
    seedQuery: 'Đàm Vĩnh Hưng',
    imageAsset: 'assets/browse/dam_vinh_hung.jpg',
    imageSourceUrl: _wikiSource,
  ),
  SongArtist(
    name: 'Tuấn Hưng',
    subtitle: 'Pop • ballad • tone nam cao',
    seedQuery: 'Tuấn Hưng',
    imageAsset: 'assets/browse/tuan_hung.jpg',
    imageSourceUrl: _wikiSource,
  ),
  SongArtist(
    name: 'Cẩm Ly',
    subtitle: 'Dân ca • bolero • quê hương',
    seedQuery: 'Cẩm Ly',
    imageAsset: 'assets/browse/cam_ly.jpg',
    imageSourceUrl: _wikiSource,
  ),
  SongArtist(
    name: 'Chi Pu',
    subtitle: 'Pop • dance • sân khấu trình diễn',
    seedQuery: 'Chi Pu',
    imageAsset: 'assets/browse/chi_pu.jpg',
    imageSourceUrl: _wikiSource,
  ),
  SongArtist(
    name: 'Isaac',
    subtitle: 'Pop • dance pop • vocal nam',
    seedQuery: 'Isaac',
    imageAsset: 'assets/browse/isaac.jpg',
    imageSourceUrl: _wikiSource,
  ),
  SongArtist(
    name: 'Karik',
    subtitle: 'Rap Việt • hip-hop • bản phối bắt tai',
    seedQuery: 'Karik',
    imageAsset: 'assets/browse/karik.jpg',
    imageSourceUrl: _wikiSource,
  ),
  SongArtist(
    name: 'Wren Evans',
    subtitle: 'Indie pop • funk • màu nhạc mới lạ',
    seedQuery: 'Wren Evans',
    imageAsset: 'assets/browse/wren_evans.jpg',
    imageSourceUrl: _wikiSource,
  ),
];

List<SongArtist> internationalArtists() => const [
  SongArtist(
    name: 'Taylor Swift',
    subtitle: 'Pop • country pop • ballad tiếng Anh',
    seedQuery: 'Taylor Swift',
    imageAsset: 'assets/browse/taylor_swift.jpg',
    imageSourceUrl: _wikiSource,
  ),
  SongArtist(
    name: 'Bruno Mars',
    subtitle: 'Pop funk • R&B • party classics',
    seedQuery: 'Bruno Mars',
    imageAsset: 'assets/browse/bruno_mars.jpg',
    imageSourceUrl: _wikiSource,
  ),
  SongArtist(
    name: 'Adele',
    subtitle: 'Soul ballad • vocal nữ mạnh',
    seedQuery: 'Adele',
    imageAsset: 'assets/browse/adele.jpg',
    imageSourceUrl: _wikiSource,
  ),
  SongArtist(
    name: 'Ed Sheeran',
    subtitle: 'Acoustic pop • guitar ballad',
    seedQuery: 'Ed Sheeran',
    imageAsset: 'assets/browse/ed_sheeran.jpg',
    imageSourceUrl: _wikiSource,
  ),
  SongArtist(
    name: 'The Weeknd',
    subtitle: 'Synth pop • R&B • high vocal',
    seedQuery: 'The Weeknd',
    imageAsset: 'assets/browse/the_weeknd.jpg',
    imageSourceUrl: _wikiSource,
  ),
  SongArtist(
    name: 'BLACKPINK',
    subtitle: 'K-Pop • dance pop • nhóm nữ',
    seedQuery: 'BLACKPINK',
    imageAsset: 'assets/browse/blackpink.jpg',
    imageSourceUrl: _wikiSource,
  ),
  SongArtist(
    name: 'BTS',
    subtitle: 'K-Pop • pop/hip-hop • nhóm nam',
    seedQuery: 'BTS',
    imageAsset: 'assets/browse/bts.jpg',
    imageSourceUrl: _wikiSource,
  ),
  SongArtist(
    name: 'Ariana Grande',
    subtitle: 'Pop/R&B • vocal nữ cao',
    seedQuery: 'Ariana Grande',
    imageAsset: 'assets/browse/ariana_grande.jpg',
    imageSourceUrl: _wikiSource,
  ),
  SongArtist(
    name: 'Billie Eilish',
    subtitle: 'Alt-pop • dark pop • vocal nhẹ',
    seedQuery: 'Billie Eilish',
    imageAsset: 'assets/browse/billie_eilish.jpg',
    imageSourceUrl: _wikiSource,
  ),
  SongArtist(
    name: 'Justin Bieber',
    subtitle: 'Pop/R&B • hit radio',
    seedQuery: 'Justin Bieber',
    imageAsset: 'assets/browse/justin_bieber.jpg',
    imageSourceUrl: _wikiSource,
  ),
  SongArtist(
    name: 'Dua Lipa',
    subtitle: 'Dance pop • disco pop',
    seedQuery: 'Dua Lipa',
    imageAsset: 'assets/browse/dua_lipa.jpg',
    imageSourceUrl: _wikiSource,
  ),
  SongArtist(
    name: 'Lady Gaga',
    subtitle: 'Pop • dance • power ballad',
    seedQuery: 'Lady Gaga',
    imageAsset: 'assets/browse/lady_gaga.jpg',
    imageSourceUrl: _wikiSource,
  ),
  SongArtist(
    name: 'Rihanna',
    subtitle: 'Pop/R&B • dancehall • club hits',
    seedQuery: 'Rihanna',
    imageAsset: 'assets/browse/rihanna.jpg',
    imageSourceUrl: _wikiSource,
  ),
  SongArtist(
    name: 'Maroon 5',
    subtitle: 'Pop rock • band hits • dễ hát nhóm',
    seedQuery: 'Maroon 5',
    imageAsset: 'assets/browse/maroon5.jpg',
    imageSourceUrl: _wikiSource,
  ),
  SongArtist(
    name: 'Coldplay',
    subtitle: 'Alternative pop • stadium ballad',
    seedQuery: 'Coldplay',
    imageAsset: 'assets/browse/coldplay.jpg',
    imageSourceUrl: _wikiSource,
  ),
  SongArtist(
    name: 'Imagine Dragons',
    subtitle: 'Pop rock • anthem • hát nhóm',
    seedQuery: 'Imagine Dragons',
    imageAsset: 'assets/browse/imagine_dragons.jpg',
    imageSourceUrl: _wikiSource,
  ),
  SongArtist(
    name: 'IU',
    subtitle: 'K-Pop ballad • vocal nữ mềm',
    seedQuery: 'IU',
    imageAsset: 'assets/browse/iu.jpg',
    imageSourceUrl: _wikiSource,
  ),
  SongArtist(
    name: 'NewJeans',
    subtitle: 'K-Pop • pop/R&B • dance nhẹ',
    seedQuery: 'NewJeans',
    imageAsset: 'assets/browse/newjeans.jpg',
    imageSourceUrl: _wikiSource,
  ),
  SongArtist(
    name: 'Charlie Puth',
    subtitle: 'Pop • vocal nam • giai điệu bắt tai',
    seedQuery: 'Charlie Puth',
    imageAsset: 'assets/browse/charlie_puth.jpg',
    imageSourceUrl: _wikiSource,
  ),
  SongArtist(
    name: 'Shawn Mendes',
    subtitle: 'Pop • acoustic pop • ballad nam',
    seedQuery: 'Shawn Mendes',
    imageAsset: 'assets/browse/shawn_mendes.jpg',
    imageSourceUrl: _wikiSource,
  ),
  SongArtist(
    name: 'Sia',
    subtitle: 'Pop • power vocal • bài hát cảm xúc',
    seedQuery: 'Sia',
    imageAsset: 'assets/browse/sia.jpg',
    imageSourceUrl: _wikiSource,
  ),
  SongArtist(
    name: 'Katy Perry',
    subtitle: 'Pop • dance pop • hit sân khấu',
    seedQuery: 'Katy Perry',
    imageAsset: 'assets/browse/katy_perry.jpg',
    imageSourceUrl: _wikiSource,
  ),
  SongArtist(
    name: 'Beyoncé',
    subtitle: 'R&B • pop • diva quyền lực',
    seedQuery: 'Beyoncé',
    imageAsset: 'assets/browse/beyonce.jpg',
    imageSourceUrl: _wikiSource,
  ),
  SongArtist(
    name: 'TWICE',
    subtitle: 'K-Pop • bubblegum pop • nhóm nữ',
    seedQuery: 'TWICE',
    imageAsset: 'assets/browse/twice.jpg',
    imageSourceUrl: _wikiSource,
  ),
  SongArtist(
    name: 'BIGBANG',
    subtitle: 'K-Pop • hip-hop • nhóm nam huyền thoại',
    seedQuery: 'BIGBANG',
    imageAsset: 'assets/browse/bigbang.jpg',
    imageSourceUrl: _wikiSource,
  ),
  SongArtist(
    name: 'Westlife',
    subtitle: 'Pop ballad • boyband • hit kinh điển',
    seedQuery: 'Westlife',
    imageAsset: 'assets/browse/westlife.jpg',
    imageSourceUrl: _wikiSource,
  ),
  SongArtist(
    name: 'Backstreet Boys',
    subtitle: 'Pop • boyband • hit thập niên 90-2000',
    seedQuery: 'Backstreet Boys',
    imageAsset: 'assets/browse/backstreet_boys.jpg',
    imageSourceUrl: _wikiSource,
  ),
  SongArtist(
    name: 'Michael Jackson',
    subtitle: 'Pop • funk • ông hoàng nhạc pop',
    seedQuery: 'Michael Jackson',
    imageAsset: 'assets/browse/michael_jackson.jpg',
    imageSourceUrl: _wikiSource,
  ),
  SongArtist(
    name: 'Whitney Houston',
    subtitle: 'Soul • R&B • diva giọng ca huyền thoại',
    seedQuery: 'Whitney Houston',
    imageAsset: 'assets/browse/whitney_houston.jpg',
    imageSourceUrl: _wikiSource,
  ),
];
