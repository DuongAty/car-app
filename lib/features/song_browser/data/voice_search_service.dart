import 'package:speech_to_text/speech_to_text.dart';

enum VoiceSearchAvailability { available, permissionDenied, unavailable }

abstract interface class VoiceSearchService {
  Future<VoiceSearchAvailability> initialize({
    required void Function() onStopped,
    required void Function() onError,
  });

  Future<void> start({
    required void Function(String transcript, bool isFinal) onResult,
  });

  Future<void> stop();
}

class SpeechToTextVoiceSearchService implements VoiceSearchService {
  SpeechToTextVoiceSearchService({SpeechToText? speech})
    : _speech = speech ?? SpeechToText();

  final SpeechToText _speech;

  @override
  Future<VoiceSearchAvailability> initialize({
    required void Function() onStopped,
    required void Function() onError,
  }) async {
    final isAvailable = await _speech.initialize(
      onStatus: (status) {
        if (status == 'done' || status == 'notListening') {
          onStopped();
        }
      },
      onError: (error) {
        onError();
      },
    );
    if (isAvailable) {
      return VoiceSearchAvailability.available;
    }
    return await _speech.hasPermission
        ? VoiceSearchAvailability.unavailable
        : VoiceSearchAvailability.permissionDenied;
  }

  @override
  Future<void> start({
    required void Function(String transcript, bool isFinal) onResult,
  }) {
    return _speech.listen(
      onResult: (result) =>
          onResult(result.recognizedWords, result.finalResult),
      listenOptions: SpeechListenOptions(
        listenMode: ListenMode.search,
        partialResults: true,
        cancelOnError: true,
      ),
    );
  }

  @override
  Future<void> stop() => _speech.stop();
}
