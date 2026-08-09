import 'package:flutter_test/flutter_test.dart';
import 'package:viet_ktv/features/song_browser/data/voice_search_service.dart';
import 'package:viet_ktv/features/song_browser/presentation/providers/voice_search_provider.dart';

void main() {
  test('submits the final voice transcript and stops listening', () async {
    final service = _FakeVoiceSearchService();
    final controller = VoiceSearchController(service);
    String? submittedTranscript;

    await controller.toggle(
      onFinalResult: (transcript) async {
        submittedTranscript = transcript;
      },
    );
    expect(controller.state.isListening, isTrue);

    service.emitResult('Sơn Tùng M-TP', true);
    await Future<void>.delayed(Duration.zero);

    expect(submittedTranscript, 'Sơn Tùng M-TP');
    expect(controller.state.isListening, isFalse);
    controller.dispose();
  });

  test(
    'does not start listening when microphone permission is denied',
    () async {
      final service = _FakeVoiceSearchService(
        availability: VoiceSearchAvailability.permissionDenied,
      );
      final controller = VoiceSearchController(service);

      final result = await controller.toggle(onFinalResult: (_) async {});

      expect(result, VoiceSearchAvailability.permissionDenied);
      expect(service.started, isFalse);
      expect(controller.state.isListening, isFalse);
      expect(
        controller.state.failure,
        VoiceSearchAvailability.permissionDenied,
      );
      controller.dispose();
    },
  );
}

class _FakeVoiceSearchService implements VoiceSearchService {
  _FakeVoiceSearchService({
    this.availability = VoiceSearchAvailability.available,
  });

  final VoiceSearchAvailability availability;
  void Function(String transcript, bool isFinal)? _onResult;
  bool started = false;

  @override
  Future<VoiceSearchAvailability> initialize({
    required void Function() onStopped,
    required void Function() onError,
  }) async => availability;

  @override
  Future<void> start({
    required void Function(String transcript, bool isFinal) onResult,
  }) async {
    started = true;
    _onResult = onResult;
  }

  void emitResult(String transcript, bool isFinal) {
    _onResult?.call(transcript, isFinal);
  }

  @override
  Future<void> stop() async {}
}
