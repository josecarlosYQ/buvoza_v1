import 'package:flutter/material.dart';
import '../models/catalogs.dart';
import '../models/form_entry.dart';
import '../services/clinical_pdf_service.dart';
import '../services/record_store.dart';
import '../services/voice_form_parser.dart';
import '../widgets/form_widgets.dart';
import '../widgets/voice_text_field.dart';

/// Lógica común de las pantallas de registro: controladores, dictado, guardado y aviso de cambios sin guardar.
mixin FormScreenState<T extends StatefulWidget> on State<T> {
  final store = RecordStore();
  final dictation = VoiceDictation();
  final _controllers = <String, TextEditingController>{};
  late FormEntry entry;
  BaseSettings settings = BaseSettings();
  bool dirty = false, saving = false;

  /// Registro a editar, o null para uno nuevo.
  FormEntry? get initialEntry;
  FormType get formType;

  /// Se llama al abrir la pantalla, con los ajustes ya cargados.
  void onReady() {}

  /// Copia los controladores y selecciones al registro antes de guardar.
  void collect();

  /// Mensaje de error si falta algo obligatorio.
  String? validate() => null;

  /// Campos que se pueden llenar con «Llenar por voz» (además de fecha, turno y guardar).
  List<VoiceField> voiceFields() => const [];

  /// Última frase reconocida en «Llenar por voz» y lo que se hizo con ella.
  String? lastPhrase;
  VoiceFillResult? lastVoice;
  bool _saveRequested = false;

  bool get isNew => initialEntry == null;

  @override
  void initState() {
    super.initState();
    entry = initialEntry ?? FormEntry(type: formType, shift: defaultShift(formType));
    store.loadSettings().then((s) {
      if (!mounted) return;
      setState(() => settings = s);
      onReady();
      dirty = false;
    });
  }

  /// Controlador ligado a una clave de `entry.data`.
  TextEditingController ctl(String key) => _controllers.putIfAbsent(key, () {
        final c = TextEditingController(text: entry.text(key));
        c.addListener(markDirty);
        return c;
      });

  /// En registros nuevos, rellena un campo vacío con un valor de los ajustes.
  void prefill(String key, String value) {
    if (isNew && ctl(key).text.isEmpty && value.isNotEmpty) ctl(key).text = value;
  }

  void markDirty() {
    if (!dirty && mounted) setState(() => dirty = true);
  }

  void collectControllers() {
    for (final e in _controllers.entries) {
      entry.data[e.key] = e.value.text.trim();
    }
  }

  Future<bool> save() async {
    collect();
    final error = validate();
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
      return false;
    }
    setState(() => saving = true);
    try {
      await dictation.stop();
      await store.save(entry);
      dirty = false;
      return true;
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('No se pudo guardar: $e')));
      return false;
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Future<void> saveAndClose() async {
    if (await save() && mounted) Navigator.pop(context, true);
  }

  /// Guarda, genera el PDF de este registro y vuelve a la lista.
  Future<void> saveAndPdf() async {
    if (!await save()) return;
    try {
      final file = await ClinicalPdfService().forEntry(entry, settings);
      if (!mounted) return;
      await showPdfActions(context, file);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('No se pudo generar el PDF: $e')));
    }
  }

  // ---- Llenado por voz ----

  /// Campo de texto ligado a [key]. Los de texto libre se añaden a lo que ya haya.
  List<VoiceField> vText(String key, String label, List<String> aliases, {bool freeText = false}) => [
        VoiceField.text(label, aliases, (v) {
          final c = ctl(key);
          c.text = freeText && c.text.trim().isNotEmpty ? '${c.text.trim()} $v' : v;
        }, freeText: freeText),
        if (freeText) VoiceField.command('Borrar ${label.toLowerCase()}', ['borrar ${aliases.first}'], () => ctl(key).clear()),
      ];

  VoiceField vNumber(String key, String label, List<String> aliases, {bool integer = false}) =>
      VoiceField.number(label, aliases, (v) => ctl(key).text = v, integer: integer);

  VoiceField vTime(String key, String label, List<String> aliases) => VoiceField.time(label, aliases, (v) => ctl(key).text = v);

  /// Nivel de combustible (0–10) del selector de combustible.
  VoiceField vFuel(String label, List<String> aliases, void Function(int) set) => VoiceField(
        label: label,
        aliases: aliases,
        hint: 'de 0 a 10, lleno, medio tanque',
        apply: (v) {
          final n = spokenFuelLevel(v);
          if (n == null) return null;
          set(n);
          return '$n/10';
        },
      );

  List<VoiceField> _commonVoiceFields() => [
        VoiceField(
          label: 'Fecha',
          aliases: const ['fecha'],
          hint: 'hoy, ayer, 5 de octubre',
          apply: (v) {
            final d = spokenDate(v);
            if (d == null) return null;
            entry.date = d;
            return '${d.day}/${d.month}/${d.year}';
          },
        ),
        if (formType.shifts.isNotEmpty)
          VoiceField.choice('Turno', const ['turno'], {
            for (final s in formType.shifts) s: _shiftWords[s] ?? [shiftNames[s] ?? s],
          }, (v) => entry.shift = v),
        VoiceField.command('Guardar', const ['guardar', 'guarda el registro', 'guardar registro'], () => _saveRequested = true),
        VoiceField.command('Terminar el dictado', const ['terminar', 'terminar dictado', 'detener dictado', 'listo'], () => dictation.stop()),
      ];

  static const _shiftWords = {
    'D': ['día', 'diurno', 'de día'],
    'N': ['noche', 'nocturno'],
    'M': ['mañana'],
    'T': ['tarde'],
    'MT': ['mañana tarde', 'mañana y tarde'],
  };

  List<VoiceField> get allVoiceFields => [..._commonVoiceFields(), ...voiceFields()];

  /// Reparte una frase dictada entre los campos del formulario.
  void applyVoicePhrase(String phrase) {
    final result = applyUtterance(phrase, allVoiceFields);
    setState(() {
      lastPhrase = phrase;
      lastVoice = result;
      if (result.applied.isNotEmpty) dirty = true;
    });
    if (_saveRequested) {
      _saveRequested = false;
      save().then((ok) {
        if (ok && mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Registro guardado por voz.')));
      });
    }
  }

  void _showVoiceHelp() => showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (ctx) => DraggableScrollableSheet(
          expand: false,
          initialChildSize: .7,
          maxChildSize: .95,
          builder: (ctx, scroll) => ListView(controller: scroll, padding: const EdgeInsets.fromLTRB(20, 0, 20, 24), children: [
            Text('Qué puedes decir', style: Theme.of(ctx).textTheme.titleLarge),
            const SizedBox(height: 8),
            const Text('Di el nombre del campo y luego su valor. Puedes decir varios seguidos en una sola frase, por ejemplo: '
                '«km inicio 120350, hora de salida diez y cuarto, conductor Juan Quispe». '
                'Las horas se entienden como «10:15», «diez y cuarto» u «ocho y media de la noche»; «ahora» pone la hora actual. '
                'El micrófono sigue escuchando entre frases; di «terminar» o toca el botón para detenerlo.'),
            const SizedBox(height: 12),
            for (final f in allVoiceFields)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text('«${f.aliases.first}»${f.needsValue ? ' + ${f.hint}' : ''}'),
                subtitle: f.aliases.length > 1 ? Text('También: ${f.aliases.skip(1).map((a) => '«$a»').join(', ')}') : null,
              ),
          ]),
        ),
      );

  Widget _voiceBar() => ListenableBuilder(
        listenable: dictation,
        builder: (context, _) {
          final on = dictation.formActive;
          final r = lastVoice;
          final showPartial = on && dictation.partial.isNotEmpty;
          return Material(
            elevation: 8,
            color: Theme.of(context).colorScheme.surface,
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  if (showPartial)
                    Text('«${dictation.partial}»', maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontStyle: FontStyle.italic)),
                  if (r != null && !showPartial) _voiceSummary(r),
                  const SizedBox(height: 6),
                  Row(children: [
                    Expanded(
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(backgroundColor: on ? Colors.red : null, minimumSize: const Size.fromHeight(48)),
                        onPressed: () => dictation.toggleForm(applyVoicePhrase),
                        icon: Icon(on ? Icons.stop_circle : Icons.record_voice_over),
                        label: Text(on ? 'Escuchando… toca para detener' : 'Llenar por voz'),
                      ),
                    ),
                    IconButton(tooltip: 'Qué puedo decir', onPressed: _showVoiceHelp, icon: const Icon(Icons.help_outline)),
                  ]),
                ]),
              ),
            ),
          );
        },
      );

  Widget _voiceSummary(VoiceFillResult r) {
    final lines = <String>[
      for (final (label, value) in r.applied) '✓ $label: $value',
      for (final (label, heard) in r.failed) '✗ $label: ${heard.isEmpty ? 'falta el valor' : 'no entendí «$heard»'}',
      for (final u in r.unmatched) '? No sé a qué campo va: «$u»',
    ];
    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 96),
      child: SingleChildScrollView(
        reverse: true,
        child: Text(
          lines.isEmpty ? 'No entendí «$lastPhrase». Toca ? para ver qué decir.' : lines.join('\n'),
          style: TextStyle(fontSize: 13, color: r.failed.isEmpty && r.unmatched.isEmpty ? const Color(0xFF1B7F3B) : Colors.deepOrange),
        ),
      ),
    );
  }

  /// Valor de [key] en el último registro guardado de [type] (para continuar el kilometraje, etc.).
  Future<String> lastValue(FormType type, String key) async {
    final previous = (await store.list(type)).where((e) => e.id != entry.id);
    return previous.isEmpty ? '' : previous.first.text(key);
  }

  /// Botones finales: guardar + PDF (si el formato se imprime por registro) o solo guardar.
  List<Widget> finalButtons() => [
        if (formType.perEntryPdf) ...[
          FilledButton.icon(onPressed: saving ? null : saveAndPdf, icon: const Icon(Icons.picture_as_pdf), label: const Text('Guardar y generar PDF')),
          const SizedBox(height: 8),
          OutlinedButton.icon(onPressed: saving ? null : saveAndClose, icon: const Icon(Icons.save), label: const Text('Solo guardar')),
        ] else
          saveButton(),
      ];

  Widget dateShift() => DateShiftPicker(
        type: formType,
        date: entry.date,
        shift: entry.shift,
        onDate: (d) => setState(() { entry.date = DateUtils.dateOnly(d); dirty = true; }),
        onShift: (s) => setState(() { entry.shift = s; dirty = true; }),
      );

  Widget saveButton({String label = 'Guardar registro'}) => FilledButton.icon(
        onPressed: saving ? null : saveAndClose,
        icon: saving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.save),
        label: Text(saving ? 'Guardando…' : label),
      );

  Widget scaffold({required List<Widget> children, List<Widget>? actions}) => UnsavedGuard(
        dirty: dirty,
        child: Scaffold(
          appBar: AppBar(
            title: Text(isNew ? formType.title : 'Editar ${formType.title.toLowerCase()}'),
            actions: actions ??
                [if (formType.perEntryPdf) IconButton(tooltip: 'Guardar y generar PDF', onPressed: saving ? null : saveAndPdf, icon: const Icon(Icons.picture_as_pdf))],
          ),
          body: ListenableBuilder(
            listenable: dictation,
            builder: (context, child) => Column(children: [
              if (dictation.error != null)
                MaterialBanner(content: Text(dictation.error!), actions: [TextButton(onPressed: () => setState(() => dictation.error = null), child: const Text('OK'))]),
              Expanded(child: child!),
            ]),
            child: ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 32), children: children),
          ),
          bottomNavigationBar: _voiceBar(),
        ),
      );

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    dictation.dispose();
    super.dispose();
  }
}
