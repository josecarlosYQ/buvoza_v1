import 'package:speech_to_text/speech_to_text.dart' as stt;

class SpeechService {
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool ready = false;
  bool get isListening => _speech.isListening;

  Future<bool> initialize({required void Function(String) onStatus}) async {
    ready = await _speech.initialize(
      onStatus: onStatus,
      onError: (_) => onStatus('No se pudo reconocer la voz. Intenta nuevamente.'),
    );
    return ready;
  }

  Future<void> listen({required void Function(String text, bool finalResult) onResult}) async {
    await _speech.listen(
      localeId: 'es-PE',
      listenFor: const Duration(seconds: 20),
      pauseFor: const Duration(seconds: 3),
      onResult: (result) => onResult(result.recognizedWords, result.finalResult),
    );
  }

  Future<void> stop() => _speech.stop();
}
