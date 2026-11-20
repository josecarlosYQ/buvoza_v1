import 'package:flutter/material.dart';
import '../models/catalogs.dart';
import '../models/form_entry.dart';
import '../services/voice_form_parser.dart';
import '../widgets/form_widgets.dart';
import '../widgets/voice_text_field.dart';
import 'form_base.dart';

class TurnoScreen extends StatefulWidget {
  const TurnoScreen({super.key, this.entry});
  final FormEntry? entry;
  @override
  State<TurnoScreen> createState() => _TurnoScreenState();
}

class _TurnoScreenState extends State<TurnoScreen> with FormScreenState<TurnoScreen> {
  late final Map<String, bool> ok = {
    for (final a in turnoAreas.keys) a: (entry.map('areas')[a] as Map?)?['ok'] != false,
  };
  late final Map<String, TextEditingController> faltas = {
    for (final a in turnoAreas.keys) a: TextEditingController(text: ((entry.map('areas')[a] as Map?)?['falta'] ?? '').toString())..addListener(markDirty),
  };

  @override
  FormEntry? get initialEntry => widget.entry;
  @override
  FormType get formType => FormType.turno;

  @override
  void onReady() {
    prefill('ambulancia', settings.ambulance);
    prefill('licenciada', settings.nurse);
  }

  static const _areaAliases = {
    'MEDICAMENTOS': ['medicamentos', 'maletín de medicamentos'],
    'FLUIDOS + EQUIPOS DE VÍA': ['fluidos', 'equipos de vía', 'fluidos y equipos de vía'],
    'MALETÍN DE ATAQUE GRANDE': ['maletín de ataque', 'maletín grande'],
    'BALÓN DE OXÍGENO': ['balón de oxígeno', 'oxígeno', 'balones'],
    'EQUIPOS BIOMÉDICOS': ['equipos biomédicos', 'biomédicos', 'equipos'],
    'LIMPIEZA': ['limpieza'],
    'OTROS': ['otros'],
  };

  /// «conforme» / «completo» marca el área; «falta …» o «no hay …» la desmarca y guarda lo que falta.
  String? _applyArea(String area, String v) {
    final s = stripAccents(v.toLowerCase());
    if (RegExp(r'\bsin novedad').hasMatch(s)) {
      ok[area] = true;
      return 'conforme';
    }
    final missing = RegExp(r'\b(falta|faltan|no hay|incompleto|incompleta|no tiene|no cuenta con)\b').firstMatch(s);
    if (missing != null) {
      final what = cleanText(v.substring(missing.end));
      ok[area] = false;
      if (what.isNotEmpty) faltas[area]!.text = what;
      return what.isEmpty ? 'con faltas' : 'falta $what';
    }
    if (RegExp(r'\b(conforme|completo|completa|ok|bien|todo|operativo|limpia|limpio|si)\b').hasMatch(s)) {
      ok[area] = true;
      return 'conforme';
    }
    return null;
  }

  @override
  List<VoiceField> voiceFields() => [
        ...vText('ambulancia', 'Ambulancia', ['ambulancia', 'unidad']),
        ...vText('licenciada', 'Licenciada(o)', ['licenciada', 'licenciado', 'enfermera', 'enfermero']),
        VoiceField.command('Todo conforme', ['todo conforme', 'todas conformes', 'todo completo'], () {
          for (final a in ok.keys) {
            ok[a] = true;
          }
        }),
        for (final area in turnoAreas.keys)
          VoiceField(label: area, aliases: _areaAliases[area]!, hint: 'conforme / falta …', apply: (v) => _applyArea(area, v)),
        ...vText('pendientes', 'Pendientes', ['pendientes', 'pendiente'], freeText: true),
        ...vText('observaciones', 'Observaciones', ['observaciones', 'observación'], freeText: true),
      ];

  @override
  void collect() {
    collectControllers();
    entry.data['areas'] = {
      for (final a in turnoAreas.keys) a: {'ok': ok[a], if (!ok[a]!) 'falta': faltas[a]!.text.trim()},
    };
  }

  @override
  String? validate() {
    if (entry.text('licenciada').isEmpty) return 'Indica la licenciada(o) a cargo.';
    final missing = turnoAreas.keys.where((a) => !ok[a]! && faltas[a]!.text.trim().isEmpty);
    if (missing.isNotEmpty) return 'Describe qué falta en: ${missing.join(', ')}.';
    return null;
  }

  @override
  void dispose() {
    for (final c in faltas.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pending = ok.values.where((v) => !v).length;
    return scaffold(children: [
      const InfoBanner(text: 'Marca cada área como conforme al recibir el turno. Si falta algo, desmárcala y describe la falta.'),
      const SectionTitle('Turno'),
      dateShift(),
      const SizedBox(height: 12),
      TextField(controller: ctl('ambulancia'), decoration: const InputDecoration(labelText: 'Ambulancia', prefixIcon: Icon(Icons.local_shipping), border: OutlineInputBorder())),
      const SizedBox(height: 12),
      TextField(controller: ctl('licenciada'), textCapitalization: TextCapitalization.words, decoration: const InputDecoration(labelText: 'Licenciada(o) a cargo *', prefixIcon: Icon(Icons.person), border: OutlineInputBorder())),
      SectionTitle('Áreas a evaluar ${pending == 0 ? '· todo conforme' : '· $pending con faltas'}'),
      for (final area in turnoAreas.entries)
        Card(
          margin: const EdgeInsets.only(bottom: 10),
          color: ok[area.key]! ? null : Colors.red.withValues(alpha: .06),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(4, 4, 12, 8),
            child: Column(children: [
              SwitchListTile(
                contentPadding: const EdgeInsets.only(left: 12),
                value: ok[area.key]!,
                title: Text(area.key, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(area.value),
                secondary: Icon(ok[area.key]! ? Icons.check_circle : Icons.error, color: ok[area.key]! ? Colors.green : Colors.red),
                onChanged: (v) => setState(() { ok[area.key] = v; dirty = true; }),
              ),
              if (!ok[area.key]!)
                Padding(
                  padding: const EdgeInsets.only(left: 12),
                  child: VoiceTextField(controller: faltas[area.key]!, dictation: dictation, label: '¿Qué falta? *', maxLines: 3),
                ),
            ]),
          ),
        ),
      VoiceTextField(controller: ctl('pendientes'), dictation: dictation, label: 'Pendientes', minLines: 2, maxLines: 5),
      const SizedBox(height: 12),
      VoiceTextField(controller: ctl('observaciones'), dictation: dictation, label: 'Observaciones', minLines: 2, maxLines: 5),
      const SizedBox(height: 20),
      saveButton(),
    ]);
  }
}
