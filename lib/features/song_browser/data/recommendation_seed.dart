import '../../source_selection/data/models/music_source.dart';

/// A fixed query run against the real catalog to seed "GỢI Ý CHO BẠN" until the
/// app has an actual personalization signal to draw on. MusicSDK exposes no
/// recommendations endpoint, so a curated search stands in for one, tuned to
/// the flavor of content each source is picked for on the source screen.
String recommendationSeedQuery(MusicSourceLogoStyle style) {
  return switch (style) {
    MusicSourceLogoStyle.youtube => 'việt nam hot',
    MusicSourceLogoStyle.soundcloud => 'nhạc remix hot',
  };
}
