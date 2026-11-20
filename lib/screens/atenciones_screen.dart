import 'package:flutter/material.dart';
import '../models/form_entry.dart';
import '../services/voice_form_parser.dart';
import '../widgets/form_widgets.dart';
import '../widgets/voice_text_field.dart';
import 'form_base.dart';

/// Opciones de la columna «Fallecido» del formato.
const deathOptions = {'': 'No', 'foco': 'En foco', 'traslado': 'Durante el traslado'};
const priorityOptions = ['I', 'II', 'III', 'IV'];

/// REGISTRO DE ATENCIONES DIARIAS: un registro por paciente atendido.
/// El PDF mensual reúne todas las atenciones del mes en la hoja del formato.
class AtencionesScreen extends StatefulWidget {
  const AtencionesScreen({super.key, this.entry});
  final FormEntry? entry;
  @override
  State<AtencionesScreen> createState() => _AtencionesScreenState();
}

class _AtencionesScreenState extends State<AtencionesScreen> with FormScreenState<AtencionesScreen> {
  late String sexo = entry.text('sexo');
  late String prioridad = entry.text('prioridad');
  late String fallecido = entry.text('fallecido');
  late bool masiva = entry.data['emergenciaMasiva'] == true;
  late bool caida = entry.data['caida'] == true;
  late bool transito = entry.data['transito'] == true;
  late bool cancelado = entry.data['cancelado'] == true;

  @override
  FormEntry? get initialEntry => widget.entry;
  @override
  FormType get formType => FormType.atenciones;

  @override
  void onReady() {
    prefill('unidad', settings.ambulance);
    prefill('placa', settings.plate);
    prefill('medico', settings.doctor);
  }

  @override
  void collect() {
    collectControllers();
    entry.data
      ..['sexo'] = sexo
      ..['prioridad'] = prioridad
      ..['fallecido'] = fallecido
      ..['emergenciaMasiva'] = masiva
      ..['caida'] = caida
      ..['transito'] = transito
      ..['cancelado'] = cancelado;
  }

  @override
  String? validate() => entry.text('paciente').isEmpty && !cancelado ? 'Escribe el nombre del paciente (o marca la atención como cancelada).' : null;

  @override
  List<VoiceField> voiceFields() => [
        ...vText('unidad', 'Unidad móvil', ['unidad móvil', 'unidad']),
        ...vText('placa', 'Placa', ['placa', 'número de placa']),
        ...vText('ficha', 'N° de ficha', ['ficha', 'número de ficha', 'número de la ficha']),
        ...vText('paciente', 'Apellidos y nombres', ['paciente', 'nombre del paciente', 'apellidos y nombres', 'nombres y apellidos']),
        vNumber('edad', 'Edad', ['edad'], integer: true),
        VoiceField.choice('Sexo', ['sexo'], {'M': ['masculino', 'hombre', 'varón'], 'F': ['femenino', 'mujer']}, (v) => sexo = v),
        ...vText('direccion', 'Dirección (distrito)', ['dirección', 'distrito', 'domicilio']),
        VoiceField.choice('Prioridad', ['prioridad'], {
          'I': ['uno', '1'],
          'II': ['dos', '2'],
          'III': ['tres', '3'],
          'IV': ['cuatro', '4'],
        }, (v) => prioridad = v),
        VoiceField.choice('Fallecido', ['fallecido', 'falleció'], {
          'foco': ['en foco', 'en el foco', 'foco'],
          'traslado': ['durante el traslado', 'en el traslado', 'traslado'],
          'no': ['no', 'ninguno'],
        }, (v) => fallecido = v == 'no' ? '' : v),
        VoiceField.command('Emergencia masiva', ['emergencia masiva'], () => masiva = true),
        VoiceField.command('Heridos por caída', ['heridos por caída', 'herido por caída'], () => caida = true),
        VoiceField.command('Accidente de tránsito', ['accidente de tránsito', 'accidentes de tránsito'], () => transito = true),
        VoiceField.command('Cancelado', ['cancelado', 'servicio cancelado', 'atención cancelada'], () => cancelado = true),
        vNumber('preventivoHoras', 'Servicio preventivo / especial (horas)', ['servicio preventivo', 'servicio especial', 'horas de servicio preventivo']),
        vNumber('retencionHoras', 'Retención de camilla (horas)', ['retención de camilla', 'retención', 'camilla retenida']),
        ...vText('diagnostico', 'Diagnóstico', ['diagnóstico', 'dx']),
        ...vText('medico', 'Médico de la atención', ['médico', 'doctor', 'médico de la atención']),
      ];

  Widget _text(String key, String label, {TextInputType? keyboard, String? suffix, IconData? icon}) => TextField(
        controller: ctl(key),
        keyboardType: keyboard,
        textCapitalization: keyboard == null ? TextCapitalization.words : TextCapitalization.none,
        decoration: InputDecoration(labelText: label, suffixText: suffix, prefixIcon: icon == null ? null : Icon(icon), border: const OutlineInputBorder(), isDense: true),
      );

  Widget _pair(Widget a, Widget b) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(children: [Expanded(child: a), const SizedBox(width: 10), Expanded(child: b)]),
      );

  Widget _chips<T>(String label, Map<T, String> options, T value, ValueChanged<T> onChanged) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Wrap(spacing: 6, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
          Text('$label:'),
          for (final o in options.entries)
            ChoiceChip(label: Text(o.value), selected: value == o.key, onSelected: (_) => setState(() { onChanged(o.key); dirty = true; })),
        ]),
      );

  Widget _flag(String label, bool value, ValueChanged<bool> onChanged) => FilterChip(
        label: Text(label),
        selected: value,
        onSelected: (on) => setState(() { onChanged(on); dirty = true; }),
      );

  @override
  Widget build(BuildContext context) => scaffold(children: [
        const InfoBanner(text: 'Un registro por paciente atendido. Desde la lista genera el PDF del mes con todas las atenciones en la hoja del formato.'),
        _pair(_text('unidad', 'Unidad móvil'), _text('placa', 'N° placa')),
        const SectionTitle('Fecha y turno'),
        dateShift(),
        const SizedBox(height: 12),
        _text('ficha', 'N° de ficha', keyboard: TextInputType.number, icon: Icons.confirmation_number),
        const SectionTitle('Datos del paciente'),
        _text('paciente', 'Apellidos y nombres', icon: Icons.person),
        const SizedBox(height: 10),
        _pair(_text('edad', 'Edad', keyboard: TextInputType.number, suffix: 'años'), _chips('Sexo', const {'M': 'M', 'F': 'F'}, sexo, (v) => sexo = sexo == v ? '' : v)),
        _text('direccion', 'Dirección (distrito)', icon: Icons.place),
        const SectionTitle('Atención'),
        _chips('Prioridad', {for (final p in priorityOptions) p: p}, prioridad, (v) => prioridad = prioridad == v ? '' : v),
        _chips('Fallecido', deathOptions, fallecido, (v) => fallecido = v),
        Wrap(spacing: 8, runSpacing: 4, children: [
          _flag('Emergencia masiva', masiva, (v) => masiva = v),
          _flag('Heridos por caída', caida, (v) => caida = v),
          _flag('Accidente de tránsito', transito, (v) => transito = v),
        ]),
        const SizedBox(height: 12),
        _pair(
          _text('preventivoHoras', 'Serv. preventivo / especial', keyboard: const TextInputType.numberWithOptions(decimal: true), suffix: 'h'),
          _text('retencionHoras', 'Retención de camilla', keyboard: const TextInputType.numberWithOptions(decimal: true), suffix: 'h'),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Atención cancelada'),
          subtitle: const Text('En el PDF la fila se marca como CANCELADO.'),
          value: cancelado,
          onChanged: (v) => setState(() { cancelado = v; dirty = true; }),
        ),
        VoiceTextField(controller: ctl('diagnostico'), dictation: dictation, label: 'Diagnóstico', maxLines: 3),
        const SizedBox(height: 10),
        _text('medico', 'Nombres y apellidos del médico de la atención', icon: Icons.medical_services),
        const SizedBox(height: 20),
        ...finalButtons(),
      ]);
}
