import 'package:flutter/material.dart';
import '../models/driver_catalogs.dart';
import '../models/form_entry.dart';
import '../services/voice_form_parser.dart';
import '../widgets/form_widgets.dart';
import '../widgets/voice_text_field.dart';
import 'form_base.dart';

/// BITÁCORA DE SERVICIO del conductor: turno, kilometraje y recorridos de la ambulancia.
class BitacoraScreen extends StatefulWidget {
  const BitacoraScreen({super.key, this.entry});
  final FormEntry? entry;
  @override
  State<BitacoraScreen> createState() => _BitacoraScreenState();
}

class _BitacoraScreenState extends State<BitacoraScreen> with FormScreenState<BitacoraScreen> {
  static const tripKeys = ['horaSalida', 'direccion', 'nosocomio', 'horaLlegada', 'kmLlegada'];
  late final List<Map<String, TextEditingController>> trips = [
    for (final t in (entry.data['recorridos'] as List?) ?? const []) _tripControllers(Map<String, dynamic>.from(t as Map)),
  ];

  @override
  FormEntry? get initialEntry => widget.entry;
  @override
  FormType get formType => FormType.bitacora;

  @override
  void onReady() {
    prefill('base', settings.base);
    prefill('conductor', settings.pilot);
    prefill('placa', settings.plate);
    prefill('piloto', settings.pilot);
    prefill('enfermera', settings.nurse);
    prefill('medico', settings.doctor);
    if (!isNew) return;
    prefill('horaInicio', hhmm(TimeOfDay.now()));
    lastValue(FormType.bitacora, 'kmFinal').then((km) {
      if (mounted && km.isNotEmpty && ctl('kmInicio').text.isEmpty) {
        ctl('kmInicio').text = km;
        dirty = false;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Kilometraje inicial tomado de la bitácora anterior: $km km')));
      }
    });
  }

  Map<String, TextEditingController> _tripControllers([Map<String, dynamic> values = const {}]) => {
        for (final k in tripKeys) k: TextEditingController(text: (values[k] ?? '').toString())..addListener(markDirty),
      };

  void _addTrip([Map<String, dynamic> values = const {}]) => setState(() {
        trips.add(_tripControllers(values));
        dirty = true;
      });

  void _removeTrip(int i) => setState(() {
        for (final c in trips.removeAt(i).values) {
          c.dispose();
        }
        dirty = true;
      });

  /// Km del recorrido i = km de llegada a base − km anterior (inicio de turno o recorrido previo).
  int? _tripKm(int i) {
    final end = parseKm(trips[i]['kmLlegada']!.text);
    final start = i == 0 ? parseKm(ctl('kmInicio').text) : parseKm(trips[i - 1]['kmLlegada']!.text);
    if (end == null || start == null) return null;
    return end - start;
  }

  int? get _shiftKm {
    final a = parseKm(ctl('kmInicio').text), b = parseKm(ctl('kmFinal').text);
    return a == null || b == null ? null : b - a;
  }

  /// Copia los servicios del Registro de horas del mismo día y turno.
  Future<void> _importFromHoras() async {
    final source = (await store.list(FormType.horasEmergencia))
        .where((e) => DateUtils.isSameDay(e.date, entry.date) && e.shift == entry.shift)
        .toList();
    if (!mounted) return;
    if (source.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('No hay Registro de horas del ${entry.date.day}/${entry.date.month} turno ${entry.shift}.')));
      return;
    }
    final rows = [for (final e in source.reversed) ...((e.data['emergencias'] as List?) ?? const [])];
    for (final r in rows) {
      final m = Map<String, dynamic>.from(r as Map);
      _addTrip({
        'horaSalida': m['salida'],
        'direccion': [m['direccion'], m['distrito']].where((x) => (x ?? '').toString().isNotEmpty).join(', '),
        'nosocomio': m['hospital'],
        'horaLlegada': m['baseLlegada'],
        'kmLlegada': m['baseKm'],
      });
    }
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Se importaron ${rows.length} recorrido(s).')));
    if (ctl('kmFinal').text.isEmpty && source.first.text('kmFinal').isNotEmpty) ctl('kmFinal').text = source.first.text('kmFinal');
  }

  /// Por voz, los datos de recorrido van al último (se crea si no hay ninguno).
  Map<String, TextEditingController> get _currentTrip {
    if (trips.isEmpty) _addTrip({'horaSalida': hhmm(TimeOfDay.now())});
    return trips.last;
  }

  @override
  List<VoiceField> voiceFields() => [
        ...vText('base', 'Base', ['base']),
        VoiceField.text('Placa', ['placa'], (v) => ctl('placa').text = v.toUpperCase()),
        ...vText('conductor', 'Conductor', ['conductor', 'conductor de ambulancia']),
        vTime('horaInicio', 'Hora inicio', ['hora inicio', 'hora inicial', 'hora de inicio']),
        vNumber('kmInicio', 'Km inicio', ['km inicio', 'km inicial', 'km de inicio'], integer: true),
        vTime('horaFinal', 'Hora final', ['hora final', 'hora de término']),
        vNumber('kmFinal', 'Km final', ['km final'], integer: true),
        VoiceField.command('Nuevo recorrido', ['nuevo recorrido', 'otro recorrido', 'siguiente recorrido'], () => _addTrip({'horaSalida': hhmm(TimeOfDay.now())})),
        VoiceField.command('Importar del Registro de horas', ['importar', 'importar recorridos', 'importar del registro de horas'], _importFromHoras),
        VoiceField.time('Hora de salida', ['salida', 'hora de salida'], (v) => _currentTrip['horaSalida']!.text = v),
        VoiceField.time('Llegada a base', ['llegada', 'llegada a base', 'hora de llegada'], (v) => _currentTrip['horaLlegada']!.text = v),
        VoiceField.text('Dirección y distrito', ['dirección', 'distrito', 'lugar'], (v) => _currentTrip['direccion']!.text = v),
        VoiceField.text('Nosocomio', ['nosocomio', 'hospital', 'clínica'], (v) => _currentTrip['nosocomio']!.text = v),
        VoiceField.number('Km de llegada', ['km llegada', 'km de llegada', 'km llegada a base', 'km del recorrido'], (v) => _currentTrip['kmLlegada']!.text = v, integer: true),
        ...vText('piloto', 'Piloto responsable', ['piloto', 'piloto responsable']),
        ...vText('enfermera', 'Enfermera responsable', ['enfermera', 'enfermero', 'licenciada', 'licenciado']),
        ...vText('medico', 'Médico responsable', ['médico', 'doctor']),
        ...vText('observaciones', 'Observaciones', ['observaciones', 'observación'], freeText: true),
      ];

  @override
  void collect() {
    collectControllers();
    entry.data['recorridos'] = [
      for (var i = 0; i < trips.length; i++)
        {for (final k in tripKeys) k: trips[i][k]!.text.trim(), 'kmRecorrido': _tripKm(i)?.toString() ?? ''},
    ];
  }

  @override
  String? validate() {
    if (entry.text('conductor').isEmpty) return 'Indica el conductor de la ambulancia.';
    if (entry.text('kmInicio').isEmpty) return 'Registra el kilometraje de inicio de turno.';
    if ((_shiftKm ?? 0) < 0) return 'El kilometraje final no puede ser menor que el inicial.';
    for (var i = 0; i < trips.length; i++) {
      if ((_tripKm(i) ?? 0) < 0) return 'Recorrido ${i + 1}: el km de llegada es menor que el anterior.';
    }
    return null;
  }

  @override
  void dispose() {
    for (final t in trips) {
      for (final c in t.values) {
        c.dispose();
      }
    }
    super.dispose();
  }

  Widget _field(String key, String label, {TextCapitalization caps = TextCapitalization.words}) => TextField(
        controller: ctl(key),
        textCapitalization: caps,
        decoration: InputDecoration(labelText: label, border: const OutlineInputBorder(), isDense: true),
      );

  @override
  Widget build(BuildContext context) {
    final shiftKm = _shiftKm;
    return scaffold(children: [
      const InfoBanner(text: 'El kilometraje inicial se toma de la bitácora anterior. Puedes importar los recorridos desde el Registro de horas del mismo turno.'),
      const SectionTitle('Datos del servicio'),
      dateShift(),
      const SizedBox(height: 12),
      Row(children: [
        Expanded(child: _field('base', 'Base')),
        const SizedBox(width: 10),
        Expanded(child: _field('placa', 'Placa', caps: TextCapitalization.characters)),
      ]),
      const SizedBox(height: 12),
      _field('conductor', 'Conductor de ambulancia *'),
      const SectionTitle('Inicio y final de turno'),
      Row(children: [
        Expanded(child: TimeField(controller: ctl('horaInicio'), label: 'Hora inicio')),
        const SizedBox(width: 10),
        Expanded(child: KmField(controller: ctl('kmInicio'), label: 'Km inicio *', onChanged: (_) => setState(() {}))),
      ]),
      const SizedBox(height: 12),
      Row(children: [
        Expanded(child: TimeField(controller: ctl('horaFinal'), label: 'Hora final')),
        const SizedBox(width: 10),
        Expanded(
          child: KmField(
            controller: ctl('kmFinal'),
            label: 'Km final',
            onChanged: (_) => setState(() {}),
            error: shiftKm != null && shiftKm < 0 ? 'Menor que el inicial' : null,
          ),
        ),
      ]),
      if (shiftKm != null && shiftKm >= 0)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text('Recorrido total del turno: $shiftKm km', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1456C0))),
        ),
      SectionTitle('Recorrido de la ambulancia (${trips.length})'),
      for (var i = 0; i < trips.length; i++)
        Card(
          margin: const EdgeInsets.only(bottom: 10),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 4, 12),
            child: Column(children: [
              Row(children: [
                Text('Recorrido ${i + 1}', style: const TextStyle(fontWeight: FontWeight.bold)),
                const Spacer(),
                if (_tripKm(i) != null)
                  Text('${_tripKm(i)} km', style: TextStyle(fontWeight: FontWeight.bold, color: _tripKm(i)! < 0 ? Colors.red : const Color(0xFF1456C0))),
                IconButton(tooltip: 'Quitar', icon: const Icon(Icons.delete_outline), onPressed: () => _removeTrip(i)),
              ]),
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Column(children: [
                  Row(children: [
                    Expanded(child: TimeField(controller: trips[i]['horaSalida']!, label: 'Hora de salida')),
                    const SizedBox(width: 10),
                    Expanded(child: TimeField(controller: trips[i]['horaLlegada']!, label: 'Llegada a base')),
                  ]),
                  const SizedBox(height: 10),
                  VoiceTextField(controller: trips[i]['direccion']!, dictation: dictation, label: 'Dirección y distrito', maxLines: 3),
                  const SizedBox(height: 10),
                  VoiceTextField(controller: trips[i]['nosocomio']!, dictation: dictation, label: 'I. Nosocomio (hospital / clínica)'),
                  const SizedBox(height: 10),
                  KmField(
                    controller: trips[i]['kmLlegada']!,
                    label: 'Km de llegada a base',
                    onChanged: (_) => setState(() {}),
                    error: (_tripKm(i) ?? 0) < 0 ? 'Menor que el km anterior' : null,
                  ),
                ]),
              ),
            ]),
          ),
        ),
      Wrap(spacing: 8, runSpacing: 8, children: [
        OutlinedButton.icon(onPressed: () => _addTrip({'horaSalida': hhmm(TimeOfDay.now())}), icon: const Icon(Icons.add), label: const Text('Añadir recorrido')),
        OutlinedButton.icon(onPressed: _importFromHoras, icon: const Icon(Icons.download), label: const Text('Importar del Registro de horas')),
      ]),
      const SectionTitle('Responsables de turno'),
      _field('piloto', 'Piloto responsable'),
      const SizedBox(height: 10),
      _field('enfermera', 'Enfermera responsable'),
      const SizedBox(height: 10),
      _field('medico', 'Médico responsable'),
      const SizedBox(height: 12),
      VoiceTextField(controller: ctl('observaciones'), dictation: dictation, label: 'Observaciones', minLines: 2, maxLines: 5),
      const SizedBox(height: 20),
      ...finalButtons(),
    ]);
  }
}
