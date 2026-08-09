import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/voice_search_service.dart';

final voiceSearchServiceProvider = Provider<VoiceSearchService>(
  (ref) => SpeechToTextVoiceSearchService(),
);

final voiceSearchProvider =
    StateNotifierProvider.autoDispose<VoiceSearchController, VoiceSearchState>(
      (ref) => VoiceSearchController(ref.watch(voiceSearchServiceProvider)),
    );

class VoiceSearchState {
  const VoiceSearchState({this.isListening = false, this.failure});

  final bool isListening;
  final VoiceSearchAvailability? failure;
}

class VoiceSearchController extends StateNotifier<VoiceSearchState> {
  VoiceSearchController(this._service) : super(const VoiceSearchState());

  final VoiceSearchService _service;

  Future<VoiceSearchAvailability?> toggle({
    required Future<void> Function(String transcript) onFinalResult,
  }) async {
    if (state.isListening) {
      await _service.stop();
      if (mounted) {
        state = const VoiceSearchState();
      }
      return null;
    }

    final availability = await _service.initialize(
      onStopped: _stopListening,
      onError: _stopListening,
    );
    if (availability != VoiceSearchAvailability.available) {
      if (mounted) {
        state = VoiceSearchState(failure: availability);
      }
      return availability;
    }

    state = const VoiceSearchState(isListening: true);
    await _service.start(
      onResult: (transcript, isFinal) {
        if (!isFinal || transcript.trim().isEmpty) {
          return;
        }
        _stopListening();
        onFinalResult(transcript);
      },
    );
    return null;
  }

  void _stopListening() {
    if (mounted) {
      state = const VoiceSearchState();
    }
  }

  @override
  void dispose() {
    _service.stop();
    super.dispose();
  }
}
