import 'dart:convert';

import '../../../core/models/persisted_song_entry.dart';
import '../../../core/services/local_storage_service.dart';

class HistoryRepository {
  HistoryRepository(this._storage);

  static const String _key = 'history.v1';
  static const int maxEntries = 50;

  final LocalStorageService _storage;

  Future<List<PersistedSongEntry>> load() async {
    try {
      final raw = await _storage.read(_key);
      if (raw == null) {
        return const [];
      }
      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded
          .take(maxEntries)
          .map((e) => PersistedSongEntry.tryFromJson(e as Map<String, dynamic>))
          .whereType<PersistedSongEntry>()
          .toList(growable: false);
    } catch (_) {
      return const [];
    }
  }

  Future<void> save(List<PersistedSongEntry> entries) async {
    try {
      final capped = entries.take(maxEntries).toList();
      final encoded = jsonEncode(capped.map((e) => e.toJson()).toList());
      await _storage.write(_key, encoded);
    } catch (_) {
      // Fail soft: a lost write is retried on the next mutation.
    }
  }
}
