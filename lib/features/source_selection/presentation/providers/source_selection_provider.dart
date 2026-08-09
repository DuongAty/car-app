import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/music_source.dart';

final sourceSelectionProvider =
    StateNotifierProvider<SourceSelectionController, SourceSelectionState>(
      (ref) => SourceSelectionController(),
    );

class SourceSelectionState {
  const SourceSelectionState({
    this.selectedSourceIndex = 0,
    this.selectedTopActionIndex,
    this.selectedSource = MusicSourceLogoStyle.youtube,
  });

  final int selectedSourceIndex;

  /// The top bar entries are one-off actions, so nothing is active until the
  /// user triggers one.
  final int? selectedTopActionIndex;

  /// The platform the user actually picked on the source picker, used to
  /// show a badge in every page's header. Deliberately not derived from
  /// [selectedSourceIndex] — that index into the source list stays valid
  /// even if the list changes shape, but shouldn't be trusted to still
  /// point at the same platform.
  final MusicSourceLogoStyle selectedSource;

  SourceSelectionState copyWith({
    int? selectedSourceIndex,
    int? selectedTopActionIndex,
    MusicSourceLogoStyle? selectedSource,
  }) {
    return SourceSelectionState(
      selectedSourceIndex: selectedSourceIndex ?? this.selectedSourceIndex,
      selectedTopActionIndex:
          selectedTopActionIndex ?? this.selectedTopActionIndex,
      selectedSource: selectedSource ?? this.selectedSource,
    );
  }
}

class SourceSelectionController extends StateNotifier<SourceSelectionState> {
  SourceSelectionController() : super(const SourceSelectionState());

  void selectSource(int index, MusicSource source) {
    state = state.copyWith(
      selectedSourceIndex: index,
      selectedSource: source.logoStyle,
    );
  }

  void selectTopAction(int index) {
    state = state.copyWith(selectedTopActionIndex: index);
  }
}
