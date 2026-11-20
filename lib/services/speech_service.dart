import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

/// Reconocedor de voz único de la app: el plugin solo admite una inicialización,
/// así que cada pantalla cambia los callbacks en lugar de crear otro.
class SpeechService {
  SpeechService._();
  static final instance = SpeechService._();

  final stt.SpeechToText _speech = stt.SpeechToText();
  bool ready = false;
  bool get isListening => _speech.isListening;

  void Function(String status)? onStatus;
  void Function(String error, bool permanent)? onError;

  Future<bool> initialize() async {
    if (ready) return true;
    ready = await _speech.initialize(
      onStatus: (s) {
        _log('estado: $s');
        onStatus?.call(s);
      },
      onError: (e) {
        _log('error: ${e.errorMsg} (permanente: ${e.permanent})');
        onError?.call(e.errorMsg, e.permanent);
      },
    );
    return ready;
  }

  Future<void> listen({required void Function(String text, bool finalResult) onResult, Duration listenFor = const Duration(seconds: 20), Duration pauseFor = const Duration(seconds: 3)}) async {
    await _speech.listen(
      listenOptions: stt.SpeechListenOptions(
        localeId: 'es-PE',
        listenFor: listenFor,
        pauseFor: pauseFor,
        autoPunctuation: true,
        listenMode: stt.ListenMode.dictation,
      ),
      onResult: (result) {
        if (result.finalResult) _log('final: ${result.recognizedWords}');
        onResult(result.recognizedWords, result.finalResult);
      },
    );
  }

  static void _log(String m) {
    if (kDebugMode) debugPrint('[voz] $m');
  }

  Future<void> stop() => _speech.stop();
}
