import 'package:speech_to_text/speech_to_text.dart';

class VoiceOrderService {
  final SpeechToText _speech = SpeechToText();

  bool _ready = false;

  Future<bool> ensureReady() async {
    if (_ready) {
      return true;
    }
    _ready = await _speech.initialize();
    return _ready;
  }

  Future<void> listen({
    required void Function(String words) onWords,
    required void Function() onDone,
  }) async {
    final ready = await ensureReady();
    if (!ready) {
      onDone();
      return;
    }
    await _speech.listen(
      listenMode: ListenMode.search,
      partialResults: true,
      onResult: (result) {
        onWords(result.recognizedWords);
        if (result.finalResult) {
          onDone();
        }
      },
    );
  }

  Future<void> stop() => _speech.stop();
}
