import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/catalogs.dart';
import '../models/form_entry.dart';
import '../services/voice_form_parser.dart';
import '../widgets/form_widgets.dart';
import '../widgets/voice_text_field.dart';
import 'form_base.dart';

class SoapieScreen extends StatefulWidget {
  const SoapieScreen({super.key, this.entry});
  final FormEntry? entry;
  @override
  State<SoapieScreen> createState() => _SoapieScreenState();
}

class _SoapieScreenState extends State<SoapieScreen> with FormScreenState<SoapieScreen> {
  late final vitals = {for (final v in vitalSigns) v.key: TextEditingController(text: (entry.map('vitals')[v.key] ?? '').toString())..addListener(_vitalChanged)};
  late String sexo = entry.text('sexo');
  late String seguro = entry.text('seguro');

  @override
  FormEntry? get initialEntry => widget.entry;
  @override
  FormType get formType => FormType.soapie;

  @override
  void onReady() {
    prefill('medico', settings.doctor);
    prefill('enfermera', settings.nurse);
    prefill('piloto', settings.pilot);
  }

  void _vitalChanged() => setState(() => dirty = true);

  static const _vitalAliases = {
    'spo2': ['saturación', 'saturación de oxígeno', 'spo2', 'sato2'],
    'fc': ['frecuencia cardiaca', 'frecuencia cardíaca', 'pulso', 'fc'],
    'temp': ['temperatura', 'temp'],
    'pa': ['presión arterial', 'presión', 'pa'],
    'fr': ['frecuencia respiratoria', 'fr'],
    'hgt': ['glucosa', 'glicemia', 'glucemia', 'hemoglucotest', 'hgt'],
  };

  static const _sectionAliases = {
    'S': ['subjetivo', 'dato subjetivo'],
    'O': ['objetivo', 'dato objetivo'],
    'A': ['análisis', 'diagnóstico de enfermería'],
    'P': ['planificación', 'plan de cuidados'],
    'I': ['intervención', 'intervenciones'],
    'E': ['evaluación'],
  };

  @override
  List<VoiceField> voiceFields() => [
        ...vText('ficha', 'N° ficha APH', ['ficha', 'número de ficha', 'ficha aph']),
        ...vText('medico', 'Médico', ['médico', 'doctor']),
        ...vText('enfermera', 'Enfermera(o)', ['enfermera', 'enfermero', 'licenciada', 'licenciado']),
        ...vText('piloto', 'Piloto', ['piloto', 'conductor']),
        ...vText('paciente', 'Paciente', ['paciente', 'nombre del paciente', 'nombres y apellidos']),
        vNumber('edad', 'Edad', ['edad'], integer: true),
        VoiceField(
          label: 'DNI',
          aliases: const ['dni', 'documento', 'documento de identidad'],
          hint: '8 dígitos',
          apply: (v) {
            var digits = v.replaceAll(RegExp(r'\D'), '');
            if (digits.isEmpty) digits = spokenNumber(v)?.round().toString() ?? '';
            if (digits.isEmpty) return null;
            ctl('dni').text = digits;
            return digits;
          },
        ),
        VoiceField.choice('Sexo', ['sexo'], {'M': ['masculino', 'hombre', 'varón'], 'F': ['femenino', 'mujer']}, (v) => sexo = v),
        VoiceField.choice('Seguro', ['seguro'], {
          'SIS': ['sis'],
          'ESSALUD': ['essalud', 'es salud', 'seguro social'],
          'SOAT': ['soat'],
          'OTROS': ['otro', 'otros', 'particular', 'ninguno'],
        }, (v) => seguro = v),
        ...vText('dx', 'Dx médico', ['diagnóstico', 'diagnóstico médico', 'dx']),
        for (final v in vitalSigns)
          v.key == 'pa'
              ? VoiceField(
                  label: v.label,
                  aliases: _vitalAliases[v.key]!,
                  hint: '120 sobre 80',
                  apply: (s) {
                    final p = spokenPressure(s);
                    if (p != null) vitals['pa']!.text = p;
                    return p;
                  },
                )
              : VoiceField.number(v.label, _vitalAliases[v.key]!, (s) => vitals[v.key]!.text = s),
        for (final s in soapieSections.keys) ...vText(s, '$s · ${soapieSections[s]!.split(' (').first}', _sectionAliases[s]!, freeText: true),
        ...vText('observaciones', 'Observaciones', ['observaciones', 'observación'], freeText: true),
      ];

  @override
  void collect() {
    collectControllers();
    entry.data['vitals'] = {for (final e in vitals.entries) e.key: e.value.text.trim()};
    entry.data['sexo'] = sexo;
    entry.data['seguro'] = seguro;
  }

  @override
  String? validate() {
    if (entry.text('paciente').isEmpty) return 'Ingresa el nombre del paciente.';
    final dni = entry.text('dni');
    if (dni.isNotEmpty && !RegExp(r'^\d{8}$').hasMatch(dni)) return 'El DNI debe tener 8 dígitos.';
    return null;
  }

  @override
  void dispose() {
    for (final c in vitals.values) {
      c.dispose();
    }
    super.dispose();
  }

  Widget _text(String key, String label, {TextInputType? keyboard, List<TextInputFormatter>? formatters}) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextField(
          controller: ctl(key),
          keyboardType: keyboard,
          inputFormatters: formatters,
          textCapitalization: keyboard == null ? TextCapitalization.words : TextCapitalization.none,
          decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
        ),
      );

  Widget _voice(String key, String label, {String? hint, int lines = 2}) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: VoiceTextField(controller: ctl(key), dictation: dictation, label: label, hint: hint, minLines: lines, maxLines: 8),
      );

  Widget _choice(String label, List<String> options, String value, ValueChanged<String> onChanged) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Wrap(spacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
          Text(label),
          for (final o in options)
            ChoiceChip(label: Text(o), selected: value == o, onSelected: (on) => setState(() { onChanged(on ? o : ''); dirty = true; })),
        ]),
      );

  @override
  Widget build(BuildContext context) => scaffold(
        children: [
          const InfoBanner(text: 'Toca el micrófono de cada campo para dictar. Las funciones vitales fuera de rango se marcan en rojo (referencia para adulto).'),
          const SectionTitle('Datos del equipo'),
          dateShift(),
          const SizedBox(height: 12),
          _text('ficha', 'N° ficha APH', keyboard: TextInputType.text),
          _text('medico', 'Médico'),
          _text('enfermera', 'Enfermera(o)'),
          _text('piloto', 'Piloto'),
          _voice('observaciones', 'Observaciones', lines: 1),
          const SectionTitle('Datos del paciente'),
          _text('paciente', 'Nombres y apellidos *'),
          Row(children: [
            Expanded(child: _text('edad', 'Edad', keyboard: TextInputType.number, formatters: [FilteringTextInputFormatter.digitsOnly])),
            const SizedBox(width: 12),
            Expanded(flex: 2, child: _text('dni', 'DNI', keyboard: TextInputType.number, formatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(8)])),
          ]),
          _choice('Sexo:', const ['M', 'F'], sexo, (v) => sexo = v),
          _choice('Seguro:', insuranceTypes, seguro, (v) => seguro = v),
          _voice('dx', 'Dx médico', lines: 1),
          const SectionTitle('Funciones vitales'),
          Wrap(spacing: 10, runSpacing: 10, children: [
            for (final v in vitalSigns)
              SizedBox(
                width: 108,
                child: TextField(
                  controller: vitals[v.key],
                  keyboardType: v.key == 'pa' ? TextInputType.text : const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: v.label,
                    hintText: v.key == 'pa' ? '120/80' : null,
                    suffixText: v.unit,
                    border: const OutlineInputBorder(),
                    errorText: v.warning(vitals[v.key]!.text),
                    errorMaxLines: 2,
                  ),
                ),
              ),
          ]),
          const SectionTitle('SOAPIE'),
          for (final s in soapieSections.entries) _voice(s.key, '${s.key} · ${s.value}', lines: 3),
          const SizedBox(height: 8),
          ...finalButtons(),
        ],
      );
}
