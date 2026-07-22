import 'package:flutter_riverpod/flutter_riverpod.dart';

final sourceSelectionProvider =
    StateNotifierProvider<SourceSelectionController, SourceSelectionState>(
      (ref) => SourceSelectionController(),
    );

class SourceSelectionState {
  const SourceSelectionState({
    this.selectedSourceIndex = 0,
    this.selectedTopActionIndex,
  });

  final int selectedSourceIndex;

  /// The top bar entries are one-off actions, so nothing is active until the
  /// user triggers one.
  final int? selectedTopActionIndex;

  SourceSelectionState copyWith({
    int? selectedSourceIndex,
    int? selectedTopActionIndex,
  }) {
    return SourceSelectionState(
      selectedSourceIndex: selectedSourceIndex ?? this.selectedSourceIndex,
      selectedTopActionIndex:
          selectedTopActionIndex ?? this.selectedTopActionIndex,
    );
  }
}

class SourceSelectionController extends StateNotifier<SourceSelectionState> {
  SourceSelectionController() : super(const SourceSelectionState());

  void selectSource(int index) {
    state = state.copyWith(selectedSourceIndex: index);
  }

  void selectTopAction(int index) {
    state = state.copyWith(selectedTopActionIndex: index);
  }
}
