import 'package:flutter/material.dart';
import '../models/driver_catalogs.dart';
import '../models/form_entry.dart';
import '../services/voice_form_parser.dart';
import '../widgets/form_widgets.dart';
import '../widgets/voice_text_field.dart';
import 'form_base.dart';

/// REGISTRO DE HORAS DE LA EMERGENCIA: una fila por emergencia atendida en el turno.
class HorasScreen extends StatefulWidget {
  const HorasScreen({super.key, this.entry});
  final FormEntry? entry;
  @override
  State<HorasScreen> createState() => _HorasScreenState();
}

class _HorasScreenState extends State<HorasScreen> with FormScreenState<HorasScreen> {
  static const rowKeys = [
    'salida', 'direccion', 'distrito', 'focoLlegada', 'focoKm', 'focoSalida',
    'hospital', 'hospLlegada', 'hospKm', 'hospSalida', 'baseLlegada', 'baseKm', 'motivo',
  ];
  late final List<Map<String, TextEditingController>> rows = [
    for (final r in (entry.data['emergencias'] as List?) ?? const []) _rowControllers(Map<String, dynamic>.from(r as Map)),
  ];
  late final List<String> outcomes = [
    for (final r in (entry.data['emergencias'] as List?) ?? const []) ((r as Map)['servicio'] ?? '').toString(),
  ];
  late final List<bool> empalmes = [
    for (final r in (entry.data['emergencias'] as List?) ?? const []) (r as Map)['empalme'] == true,
  ];
  late int? fuelStart = (entry.data['combustibleInicio'] as num?)?.toInt();
  late int? fuelEnd = (entry.data['combustibleFinal'] as num?)?.toInt();

  @override
  FormEntry? get initialEntry => widget.entry;
  @override
  FormType get formType => FormType.horasEmergencia;

  @override
  void onReady() {
    prefill('base', settings.base);
    prefill('samu', settings.samu);
    prefill('piloto', settings.pilot);
    prefill('medico', settings.doctor);
    prefill('licenciado', settings.nurse);
    if (!isNew) return;
    lastValue(FormType.horasEmergencia, 'kmFinal').then((km) {
      if (mounted && km.isNotEmpty && ctl('kmInicio').text.isEmpty) {
        ctl('kmInicio').text = km;
        dirty = false;
      }
    });
  }

  Map<String, TextEditingController> _rowControllers([Map<String, dynamic> values = const {}]) => {
        for (final k in rowKeys) k: TextEditingController(text: (values[k] ?? '').toString())..addListener(markDirty),
      };

  void _addRow({bool empalme = false}) {
    final values = <String, dynamic>{'salida': hhmm(TimeOfDay.now())};
    if (empalme && rows.isNotEmpty) {
      // Nota del formato: en un empalme, la hora de llegada al nuevo llamado se toma como nueva hora de salida.
      final prev = rows.last;
      values['salida'] = [prev['hospSalida']!.text, prev['focoSalida']!.text, hhmm(TimeOfDay.now())].firstWhere((t) => t.isNotEmpty);
    }
    setState(() {
      rows.add(_rowControllers(values));
      outcomes.add('');
      empalmes.add(empalme);
      dirty = true;
    });
  }

  void _removeRow(int i) => setState(() {
        for (final c in rows.removeAt(i).values) {
          c.dispose();
        }
        outcomes.removeAt(i);
        empalmes.removeAt(i);
        dirty = true;
      });

  /// Por voz, los datos de emergencia van a la última fila (se crea si no hay ninguna).
  Map<String, TextEditingController> get _currentRow {
    if (rows.isEmpty) _addRow();
    return rows.last;
  }

  VoiceField _rowText(String key, String label, List<String> aliases) => VoiceField.text(label, aliases, (v) => _currentRow[key]!.text = v);
  VoiceField _rowTime(String key, String label, List<String> aliases) => VoiceField.time(label, aliases, (v) => _currentRow[key]!.text = v);
  VoiceField _rowKm(String key, String label, List<String> aliases) =>
      VoiceField.number(label, aliases, (v) => _currentRow[key]!.text = v, integer: true);

  @override
  List<VoiceField> voiceFields() => [
        ...vText('base', 'Base', ['base']),
        ...vText('samu', 'SAMU', ['samu']),
        ...vText('piloto', 'Piloto', ['piloto', 'conductor']),
        ...vText('medico', 'Médico', ['médico', 'doctor']),
        ...vText('licenciado', 'Licenciada(o)', ['licenciada', 'licenciado', 'enfermera', 'enfermero']),
        vNumber('kmInicio', 'Km inicio', ['km inicio', 'km inicial', 'km de inicio'], integer: true),
        vNumber('kmFinal', 'Km final', ['km final'], integer: true),
        vFuel('Combustible inicio', ['combustible inicio', 'combustible inicial', 'combustible al inicio'], (v) => fuelStart = v),
        vFuel('Combustible final', ['combustible final', 'combustible al final'], (v) => fuelEnd = v),
        VoiceField.command('Nueva emergencia', ['nueva emergencia', 'otra emergencia', 'siguiente emergencia'], () => _addRow()),
        VoiceField.command('Empalme', ['empalme', 'nuevo empalme'], () => _addRow(empalme: rows.isNotEmpty)),
        _rowTime('salida', 'Salida de base', ['salida', 'hora de salida', 'salida de base']),
        _rowText('distrito', 'Distrito', ['distrito']),
        _rowText('direccion', 'Dirección del foco', ['dirección', 'dirección del foco', 'lugar']),
        _rowTime('focoLlegada', 'Llegada al foco', ['llegada al foco', 'llegada foco', 'hora de llegada al foco']),
        _rowTime('focoSalida', 'Salida del foco', ['salida del foco', 'salida foco']),
        _rowKm('focoKm', 'Km al foco', ['km foco', 'km del foco', 'km al foco', 'km llegada al foco']),
        _rowText('hospital', 'Hospital / clínica', ['hospital', 'clínica', 'nosocomio']),
        _rowTime('hospLlegada', 'Llegada al hospital', ['llegada al hospital', 'llegada hospital', 'llegada a la clínica']),
        _rowTime('hospSalida', 'Salida del hospital', ['salida del hospital', 'salida hospital', 'salida de la clínica']),
        _rowKm('hospKm', 'Km al hospital', ['km hospital', 'km del hospital', 'km al hospital', 'km llegada al hospital', 'km clínica']),
        _rowTime('baseLlegada', 'Llegada a base', ['llegada a base', 'llegada base', 'retorno a base', 'retorno']),
        _rowKm('baseKm', 'Km llegada a base', ['km base', 'km de base', 'km llegada a base', 'km de retorno']),
        _rowText('motivo', 'Motivo de llamada', ['motivo', 'motivo de llamada', 'motivo de la llamada']),
        VoiceField.choice('Servicio', ['servicio', 'resultado'], {
          'R': ['retenido'],
          'F': ['fallecido'],
          'C': ['cancelado'],
          'FR': ['frustro', 'frustrado'],
        }, (v) {
          if (rows.isEmpty) _addRow();
          outcomes[rows.length - 1] = v;
        }),
      ];

  /// Avisa si los km de una fila no van en aumento (foco → hospital → base).
  String? _kmWarning(int i, String key) {
    final order = ['focoKm', 'hospKm', 'baseKm'];
    final value = parseKm(rows[i][key]!.text);
    if (value == null) return null;
    final start = parseKm(ctl('kmInicio').text);
    if (start != null && value < start) return 'Menor que km inicio';
    for (final prev in order.sublist(0, order.indexOf(key))) {
      final p = parseKm(rows[i][prev]!.text);
      if (p != null && value < p) return 'Menor que el km anterior';
    }
    return null;
  }

  @override
  void collect() {
    collectControllers();
    entry.data['combustibleInicio'] = fuelStart;
    entry.data['combustibleFinal'] = fuelEnd;
    entry.data['emergencias'] = [
      for (var i = 0; i < rows.length; i++)
        {for (final k in rowKeys) k: rows[i][k]!.text.trim(), 'servicio': outcomes[i], 'empalme': empalmes[i]},
    ];
  }

  @override
  String? validate() {
    final a = parseKm(entry.text('kmInicio')), b = parseKm(entry.text('kmFinal'));
    if (a != null && b != null && b < a) return 'El km final no puede ser menor que el km de inicio.';
    for (var i = 0; i < rows.length; i++) {
      for (final k in const ['focoKm', 'hospKm', 'baseKm']) {
        final w = _kmWarning(i, k);
        if (w != null) return 'Emergencia ${i + 1}: $w.';
      }
    }
    return null;
  }

  @override
  void dispose() {
    for (final r in rows) {
      for (final c in r.values) {
        c.dispose();
      }
    }
    super.dispose();
  }

  Widget _field(String key, String label) => TextField(
        controller: ctl(key),
        textCapitalization: TextCapitalization.words,
        decoration: InputDecoration(labelText: label, border: const OutlineInputBorder(), isDense: true),
      );

  Widget _pair(Widget a, Widget b) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(children: [Expanded(child: a), const SizedBox(width: 10), Expanded(child: b)]),
      );

  Widget _group(String title, List<Widget> children) => Padding(
        padding: const EdgeInsets.only(top: 6, bottom: 4),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.black54)),
          const SizedBox(height: 6),
          ...children,
        ]),
      );

  Widget _rowCard(int i) {
    final r = rows[i];
    KmField km(String key, String label) => KmField(controller: r[key]!, label: label, error: _kmWarning(i, key), onChanged: (_) => setState(() {}));
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            CircleAvatar(radius: 14, child: Text('${i + 1}', style: const TextStyle(fontSize: 13))),
            const SizedBox(width: 8),
            Text(empalmes[i] ? 'Emergencia (empalme)' : 'Emergencia', style: const TextStyle(fontWeight: FontWeight.bold)),
            const Spacer(),
            IconButton(tooltip: 'Quitar', icon: const Icon(Icons.delete_outline), onPressed: () => _removeRow(i)),
          ]),
          _pair(TimeField(controller: r['salida']!, label: empalmes[i] ? 'Salida (empalme)' : 'Salida de base'), _textOf(r['distrito']!, 'Distrito')),
          VoiceTextField(controller: r['direccion']!, dictation: dictation, label: 'Dirección del foco'),
          _group('Foco', [
            _pair(TimeField(controller: r['focoLlegada']!, label: 'Llegada'), TimeField(controller: r['focoSalida']!, label: 'Salida')),
            km('focoKm', 'Km llegada al foco'),
          ]),
          _group('Hospital / clínica', [
            Padding(padding: const EdgeInsets.only(bottom: 10), child: _textOf(r['hospital']!, 'Nombre del hospital / clínica')),
            _pair(TimeField(controller: r['hospLlegada']!, label: 'Llegada'), TimeField(controller: r['hospSalida']!, label: 'Salida')),
            km('hospKm', 'Km llegada al hospital'),
          ]),
          _group('Retorno a base', [
            _pair(TimeField(controller: r['baseLlegada']!, label: 'Llegada a base'), km('baseKm', 'Km llegada a base')),
          ]),
          VoiceTextField(controller: r['motivo']!, dictation: dictation, label: 'Motivo de llamada', hint: 'Accidente vehicular, caída, atropello…', maxLines: 3),
          const SizedBox(height: 10),
          Wrap(spacing: 6, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
            const Text('Servicio:'),
            for (final o in serviceOutcomes.entries)
              ChoiceChip(
                label: Text(o.value),
                selected: outcomes[i] == o.key,
                onSelected: (on) => setState(() { outcomes[i] = on ? o.key : ''; dirty = true; }),
              ),
          ]),
        ]),
      ),
    );
  }

  Widget _textOf(TextEditingController c, String label) => TextField(
        controller: c,
        textCapitalization: TextCapitalization.words,
        decoration: InputDecoration(labelText: label, border: const OutlineInputBorder(), isDense: true),
      );

  @override
  Widget build(BuildContext context) {
    final a = parseKm(ctl('kmInicio').text), b = parseKm(ctl('kmFinal').text);
    return scaffold(children: [
      const InfoBanner(text: 'Añade una emergencia por cada salida. Si sales a otra emergencia sin volver a base, usa «Empalme»: la hora de salida se toma de la última salida registrada.'),
      const SectionTitle('Turno'),
      dateShift(),
      const SizedBox(height: 12),
      _pair(_field('base', 'Base'), _field('samu', 'SAMU')),
      _field('piloto', 'Piloto'),
      const SizedBox(height: 10),
      _field('medico', 'Médico'),
      const SizedBox(height: 10),
      _field('licenciado', 'Licenciada(o)'),
      const SectionTitle('Kilometraje y combustible'),
      _pair(
        KmField(controller: ctl('kmInicio'), label: 'Km inicio', onChanged: (_) => setState(() {})),
        KmField(controller: ctl('kmFinal'), label: 'Km final', onChanged: (_) => setState(() {}), error: a != null && b != null && b < a ? 'Menor que el inicio' : null),
      ),
      if (a != null && b != null && b >= a) Text('Recorrido del turno: ${b - a} km', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1456C0))),
      FuelLevelPicker(label: 'Combustible al inicio', value: fuelStart, onChanged: (v) => setState(() { fuelStart = v; dirty = true; })),
      FuelLevelPicker(label: 'Combustible al final', value: fuelEnd, onChanged: (v) => setState(() { fuelEnd = v; dirty = true; })),
      SectionTitle('Emergencias (${rows.length})'),
      for (var i = 0; i < rows.length; i++) _rowCard(i),
      Wrap(spacing: 8, runSpacing: 8, children: [
        FilledButton.tonalIcon(onPressed: () => _addRow(), icon: const Icon(Icons.add), label: const Text('Nueva emergencia')),
        if (rows.isNotEmpty) OutlinedButton.icon(onPressed: () => _addRow(empalme: true), icon: const Icon(Icons.call_split), label: const Text('Empalme')),
      ]),
      const SizedBox(height: 20),
      ...finalButtons(),
    ]);
  }
}
