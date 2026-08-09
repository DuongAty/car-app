import 'dart:convert';

import '../../../core/services/local_storage_service.dart';
import '../../source_selection/data/models/music_source.dart';
import 'models/song_item.dart';

/// Persists the last successful "GỢI Ý CHO BẠN" list per source so the column
/// can be shown instantly on open instead of waiting on a network round-trip.
///
/// Same on-device storage split as [FavoritesRepository]: depends on the
/// [LocalStorageService] interface, not `shared_preferences` directly, so it
/// stays testable against an in-memory fake.
class RecommendationsCacheRepository {
  RecommendationsCacheRepository(this._storage);

  static const String _keyPrefix = 'recommendations.v1.';
  static const int maxItemsPerSource = 50;

  final LocalStorageService _storage;

  String _keyFor(MusicSourceLogoStyle source) => '$_keyPrefix${source.name}';

  Future<List<SongItem>?> load(MusicSourceLogoStyle source) async {
    try {
      final raw = await _storage.read(_keyFor(source));
      if (raw == null) {
        return null;
      }
      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded
          .take(maxItemsPerSource)
          .map((e) => SongItem.fromJson(e as Map<String, dynamic>))
          .toList(growable: false);
    } catch (_) {
      // A corrupt or schema-changed blob is treated as a cache miss; the live
      // search still runs and overwrites it.
      return null;
    }
  }

  Future<void> save(MusicSourceLogoStyle source, List<SongItem> items) async {
    try {
      final encoded = jsonEncode(
        items.take(maxItemsPerSource).map((e) => e.toJson()).toList(),
      );
      await _storage.write(_keyFor(source), encoded);
    } catch (_) {
      // Fail soft: a lost write just means the next open revalidates again.
    }
  }
}
