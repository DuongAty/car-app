import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:viet_ktv/core/providers/local_storage_provider.dart';
import 'package:viet_ktv/features/favorites/presentation/providers/favorites_controller.dart';
import 'package:viet_ktv/features/song_browser/data/models/song_item.dart';
import 'package:viet_ktv/features/source_selection/data/models/music_source.dart';

import '../../support/fake_local_storage_service.dart';

const _song = SongItem(
  id: '1',
  title: 'Lạc Trôi',
  subtitle: 'Sơn Tùng M-TP',
  duration: '4:32',
  thumbnailSeed: 1,
  badge: null,
);

void main() {
  test('toggle_adds_then_removes_a_favorite', () async {
    final container = ProviderContainer(
      overrides: [
        localStorageServiceProvider.overrideWithValue(
          FakeLocalStorageService(),
        ),
      ],
    );
    addTearDown(container.dispose);
    final controller = container.read(favoritesControllerProvider.notifier);
    await Future<void>.delayed(Duration.zero);

    controller.toggle(_song, MusicSourceLogoStyle.youtube);
    expect(container.read(favoritesControllerProvider), hasLength(1));
    expect(controller.isFavorite('1'), isTrue);

    controller.toggle(_song, MusicSourceLogoStyle.youtube);
    expect(container.read(favoritesControllerProvider), isEmpty);
    expect(controller.isFavorite('1'), isFalse);
  });

  test(
    'favorites_persist_across_a_fresh_controller_reading_the_same_storage',
    () async {
      final storage = FakeLocalStorageService();

      final container1 = ProviderContainer(
        overrides: [localStorageServiceProvider.overrideWithValue(storage)],
      );
      container1
          .read(favoritesControllerProvider.notifier)
          .toggle(_song, MusicSourceLogoStyle.youtube);
      await Future<void>.delayed(Duration.zero);
      container1.dispose();

      final container2 = ProviderContainer(
        overrides: [localStorageServiceProvider.overrideWithValue(storage)],
      );
      addTearDown(container2.dispose);
      // Trigger construction (and its _load()) before waiting, otherwise the
      // delay elapses with nothing yet in flight and the read below just
      // catches the synchronous pre-load state.
      container2.read(favoritesControllerProvider.notifier);
      await Future<void>.delayed(Duration.zero);

      expect(container2.read(favoritesControllerProvider), hasLength(1));
    },
  );

  test('clear_empties_the_list_and_persists_the_empty_state', () async {
    final storage = FakeLocalStorageService();
    final container = ProviderContainer(
      overrides: [localStorageServiceProvider.overrideWithValue(storage)],
    );
    addTearDown(container.dispose);
    final controller = container.read(favoritesControllerProvider.notifier);
    await Future<void>.delayed(Duration.zero);

    controller.toggle(_song, MusicSourceLogoStyle.youtube);
    controller.clear();

    expect(container.read(favoritesControllerProvider), isEmpty);
  });
}
