import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:viet_ktv/features/history/data/history_repository.dart';

import '../../../support/fake_local_storage_service.dart';

void main() {
  test('skips_an_entry_with_an_unknown_source_and_keeps_the_rest', () async {
    final storage = FakeLocalStorageService();
    storage.store['history.v1'] = jsonEncode([
      {
        'song': {
          'id': '1',
          'title': 'Song One',
          'subtitle': 'Artist One',
          'duration': '3:00',
          'thumbnailSeed': 1,
          'imageUrl': null,
          'badge': null,
        },
        'source': 'youtube',
        'at': DateTime.utc(2026, 1, 1).toIso8601String(),
      },
      {
        'song': {
          'id': '2',
          'title': 'Removed Source Song',
          'subtitle': 'Artist Two',
          'duration': '4:00',
          'thumbnailSeed': 2,
          'imageUrl': null,
          'badge': null,
        },
        // No longer a valid MusicSourceLogoStyle value after removing
        // Mixcloud — must be skipped, not crash the whole list.
        'source': 'mixcloud',
        'at': DateTime.utc(2026, 1, 2).toIso8601String(),
      },
      {
        'song': {
          'id': '3',
          'title': 'Song Three',
          'subtitle': 'Artist Three',
          'duration': '2:30',
          'thumbnailSeed': 3,
          'imageUrl': null,
          'badge': null,
        },
        'source': 'soundcloud',
        'at': DateTime.utc(2026, 1, 3).toIso8601String(),
      },
    ]);

    final repository = HistoryRepository(storage);
    final entries = await repository.load();

    expect(entries.length, 2);
    expect(entries.map((e) => e.song.id), ['1', '3']);
  });
}
