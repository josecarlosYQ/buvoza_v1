import 'package:flutter/material.dart';
import '../services/speech_service.dart';

/// Comparte el reconocedor de voz entre los campos de una pantalla y el modo «Llenar por voz».
class VoiceDictation extends ChangeNotifier {
  final _speech = SpeechService.instance;

  /// Campo que recibe el dictado, o null.
  TextEditingController? active;

  /// Modo «Llenar por voz»: recibe cada frase y escucha de nuevo hasta que se detenga.
  void Function(String phrase)? _formHandler;
  bool get formActive => _formHandler != null;
  bool get listening => active != null || formActive;
  int _silentRounds = 0;

  String partial = '';
  String? error;
  bool _disposed = false;

  @override
  void notifyListeners() {
    // El plugin puede avisar de cambios de estado después de cerrar la pantalla.
    if (!_disposed) super.notifyListeners();
  }

  bool isActive(TextEditingController c) => identical(active, c);

  Future<bool> _ensureReady() async {
    _speech.onStatus = _onStatus;
    _speech.onError = _onError;
    if (await _speech.initialize()) return true;
    error = 'Reconocimiento de voz no disponible. Revisa el permiso del micrófono o la conexión.';
    notifyListeners();
    return false;
  }

  void _onStatus(String s) {
    if (_disposed || (s != 'done' && s != 'notListening')) return;
    if (formActive) {
      // Algunos reconocedores cierran la sesión sin marcar el resultado como final:
      // se usa lo último que se oyó. Se vuelve a escuchar solo cuando la sesión terminó («done»).
      if (partial.trim().isNotEmpty) {
        final phrase = partial.trim();
        partial = '';
        _heardThisRound = true;
        _silentRounds = 0;
        _formHandler!(phrase);
        notifyListeners();
      }
      if (s == 'done') _restartForm();
    } else if (active != null) {
      if (partial.trim().isNotEmpty) _appendTo(active!, partial.trim());
      active = null;
      partial = '';
      notifyListeners();
    }
  }

  static void _appendTo(TextEditingController c, String text) {
    c.text = c.text.trim().isEmpty ? _capitalize(text) : '${c.text.trim()} $text';
    c.selection = TextSelection.collapsed(offset: c.text.length);
  }

  void _onError(String e, bool permanent) {
    if (_disposed) return;
    // Silencio o nada reconocido: en el modo formulario se vuelve a escuchar (hasta 3 silencios seguidos).
    final silence = e == 'error_speech_timeout' || e == 'error_no_match';
    if (silence && formActive) return;
    if (!silence) {
      error = e.contains('permission')
          ? 'Sin permiso de micrófono. Actívalo en los ajustes del teléfono.'
          : 'No se pudo reconocer la voz ($e). Intenta nuevamente.';
      _formHandler = null;
    }
    active = null;
    partial = '';
    notifyListeners();
  }

  /// Dicta en un campo concreto (añade al final de lo que ya tenga).
  Future<void> toggle(TextEditingController c) async {
    if (isActive(c)) return stop();
    if (listening) await stop();
    if (!await _ensureReady()) return;
    error = null;
    active = c;
    partial = '';
    notifyListeners();
    await _speech.listen(
      listenFor: const Duration(seconds: 60),
      onResult: (text, finalResult) {
        if (!identical(active, c)) return;
        partial = finalResult ? '' : text;
        if (finalResult && text.trim().isNotEmpty) _appendTo(c, text.trim());
        notifyListeners();
      },
    );
  }

  /// Activa o detiene el modo «Llenar por voz».
  Future<void> toggleForm(void Function(String phrase) onPhrase) async {
    if (formActive) return stop();
    if (listening) await stop();
    if (!await _ensureReady()) return;
    error = null;
    _formHandler = onPhrase;
    _silentRounds = 0;
    notifyListeners();
    await _listenForm();
  }

  Future<void> _listenForm() async {
    partial = '';
    _heardThisRound = false;
    notifyListeners();
    await _speech.listen(
      listenFor: const Duration(seconds: 60),
      pauseFor: const Duration(seconds: 4),
      onResult: (text, finalResult) {
        if (!formActive) return;
        partial = finalResult ? '' : text;
        if (finalResult && text.trim().isNotEmpty) {
          _heardThisRound = true;
          _silentRounds = 0;
          _formHandler!(text.trim());
        }
        notifyListeners();
      },
    );
  }

  bool _heardThisRound = false, _restarting = false;

  void _restartForm() {
    if (_restarting || !formActive) return;
    if (!_heardThisRound) _silentRounds++;
    if (_silentRounds >= 3) {
      // Tras varios silencios seguidos se apaga para no quedarse escuchando.
      _formHandler = null;
      partial = '';
      notifyListeners();
      return;
    }
    _restarting = true;
    // Si se pide escuchar antes de que Android cierre la sesión anterior, lo ignora.
    Future.delayed(const Duration(milliseconds: 900), () async {
      _restarting = false;
      if (formActive && !_disposed && !_speech.isListening) await _listenForm();
    });
  }

  Future<void> stop() async {
    // Al tocar «detener» a media frase, se aprovecha lo que ya se oyó.
    final pending = partial.trim();
    if (pending.isNotEmpty) {
      if (_formHandler != null) {
        _formHandler!(pending);
      } else if (active != null) {
        _appendTo(active!, pending);
      }
    }
    active = null;
    _formHandler = null;
    partial = '';
    await _speech.stop();
    notifyListeners();
  }

  static String _capitalize(String s) => s[0].toUpperCase() + s.substring(1);

  @override
  void dispose() {
    _disposed = true;
    active = null;
    _formHandler = null;
    _speech.stop();
    super.dispose();
  }
}

/// Campo de texto con botón de micrófono que añade lo dictado al final.
class VoiceTextField extends StatelessWidget {
  const VoiceTextField({
    super.key,
    required this.controller,
    required this.dictation,
    required this.label,
    this.hint,
    this.minLines = 1,
    this.maxLines = 1,
  });

  final TextEditingController controller;
  final VoiceDictation dictation;
  final String label;
  final String? hint;
  final int minLines, maxLines;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: dictation,
        builder: (context, _) {
          final on = dictation.isActive(controller);
          return TextField(
            controller: controller,
            minLines: minLines,
            maxLines: maxLines < minLines ? minLines : maxLines,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              labelText: label,
              hintText: hint,
              border: const OutlineInputBorder(),
              filled: on,
              fillColor: on ? Colors.red.withValues(alpha: .05) : null,
              helperText: on ? (dictation.partial.isEmpty ? 'Escuchando…' : dictation.partial) : null,
              helperMaxLines: 3,
              suffixIcon: IconButton(
                tooltip: on ? 'Detener dictado' : 'Dictar',
                icon: Icon(on ? Icons.stop_circle : Icons.mic, color: on ? Colors.red : const Color(0xFF1456C0)),
                onPressed: () => dictation.toggle(controller),
              ),
            ),
          );
        },
      );
}
