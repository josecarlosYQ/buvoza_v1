import 'package:flutter/material.dart';
import '../models/driver_catalogs.dart';
import '../models/form_entry.dart';
import '../services/voice_form_parser.dart';
import '../widgets/form_widgets.dart';
import '../widgets/voice_text_field.dart';
import 'form_base.dart';

/// ACTA DE CONFORMIDAD MECÁNICA DE LA UNIDAD VEHICULAR (al inicio del relevo).
class ActaScreen extends StatefulWidget {
  const ActaScreen({super.key, this.entry});
  final FormEntry? entry;
  @override
  State<ActaScreen> createState() => _ActaScreenState();
}

class _ActaScreenState extends State<ActaScreen> with FormScreenState<ActaScreen> {
  late final Map<String, String> items = {for (final e in entry.map('items').entries) e.key: e.value.toString()};
  late int? fuelStart = (entry.data['combustibleInicio'] as num?)?.toInt();
  late int? fuelEnd = (entry.data['combustibleFinal'] as num?)?.toInt();
  late String fuelType = entry.text('tipoCombustible');
  bool onlyProblems = false;

  static final allItems = [for (final g in actaGroups.values) ...g];

  @override
  FormEntry? get initialEntry => widget.entry;
  @override
  FormType get formType => FormType.actaMecanica;

  @override
  void onReady() {
    prefill('samu', settings.samu);
    prefill('establecimiento', settings.base);
    prefill('placa', settings.plate);
    prefill('conductor', settings.pilot);
    prefill('pilotoEntrante', settings.pilot);
    prefill('medicoEntrante', settings.doctor);
    if (!isNew) return;
    prefill('horaInicio', hhmm(TimeOfDay.now()));
    lastValue(FormType.actaMecanica, 'kmFinal').then((km) {
      if (mounted && km.isNotEmpty && ctl('kmInicio').text.isEmpty) {
        ctl('kmInicio').text = km;
        dirty = false;
      }
    });
    lastValue(FormType.actaMecanica, 'proxMantenimiento').then((v) {
      if (mounted) prefill('proxMantenimiento', v);
    });
  }

  void _set(String item, String? value) => setState(() {
        if (value == null) {
          items.remove(item);
        } else {
          items[item] = value;
        }
        dirty = true;
      });

  void _markGroupOk(List<String> group) => setState(() {
        for (final item in group) {
          items.putIfAbsent(item, () => actaOptions(item).first);
        }
        dirty = true;
      });

  @override
  List<VoiceField> voiceFields() => [
        ...vText('samu', 'SAMU N°', ['samu', 'samu número']),
        ...vText('placa', 'Placa', ['placa']),
        ...vText('establecimiento', 'Establecimiento', ['establecimiento']),
        ...vText('ciaBomberos', 'Cía. de bomberos', ['compañía de bomberos', 'bomberos']),
        ...vText('conductor', 'Conductor', ['conductor']),
        vTime('horaInicio', 'Hora inicio', ['hora inicio', 'hora inicial', 'hora de inicio']),
        vTime('horaFinal', 'Hora final', ['hora final', 'hora de término']),
        vNumber('kmInicio', 'Km inicio', ['km inicio', 'km inicial', 'km de inicio'], integer: true),
        vNumber('kmFinal', 'Km final', ['km final'], integer: true),
        vFuel('Combustible inicio', ['combustible inicio', 'combustible inicial', 'combustible al inicio'], (v) => fuelStart = v),
        vFuel('Combustible final', ['combustible final', 'combustible al final'], (v) => fuelEnd = v),
        ...vText('proxMantenimiento', 'Próximo mantenimiento', ['próximo mantenimiento', 'mantenimiento']),
        VoiceField.choice('Tipo de combustible', ['tipo de combustible'], fuelSpokenNames, (v) => fuelType = v),
        VoiceField.command('Marcar pendientes como conformes', ['todo conforme', 'todos conformes', 'todo lo demás conforme', 'el resto conforme', 'todo operativo'],
            () => _markGroupOk(allItems)),
        for (final item in allItems)
          VoiceField.choice(item, actaItemAliases(item), {for (final o in actaOptions(item)) o: actaSpokenOptions[o]!}, (v) => items[item] = v),
        ...vText('observaciones', 'Observaciones', ['observaciones', 'observación'], freeText: true),
        ...vText('pilotoEntrante', 'Piloto entrante', ['piloto entrante']),
        ...vText('pilotoSaliente', 'Piloto saliente', ['piloto saliente']),
        ...vText('medicoEntrante', 'Médico entrante', ['médico entrante']),
      ];

  @override
  void collect() {
    collectControllers();
    entry.data['items'] = items;
    entry.data['combustibleInicio'] = fuelStart;
    entry.data['combustibleFinal'] = fuelEnd;
    entry.data['tipoCombustible'] = fuelType;
  }

  @override
  String? validate() {
    final missing = allItems.where((i) => !items.containsKey(i)).length;
    if (missing > 0) return 'Faltan $missing ítems por revisar. Usa «Marcar pendientes como conformes» en cada grupo si corresponde.';
    final problems = allItems.where((i) => actaIsProblem(i, items[i])).length;
    if (problems > 0 && entry.text('observaciones').isEmpty) return 'Hay $problems ítems con observación: descríbelos en Observaciones.';
    return null;
  }

  Widget _field(String key, String label, {TextInputType? keyboard}) => TextField(
        controller: ctl(key),
        keyboardType: keyboard,
        textCapitalization: TextCapitalization.words,
        decoration: InputDecoration(labelText: label, border: const OutlineInputBorder(), isDense: true),
      );

  Widget _pair(Widget a, Widget b) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(children: [Expanded(child: a), const SizedBox(width: 10), Expanded(child: b)]),
      );

  Widget _itemRow(String item) {
    final value = items[item];
    final problem = actaIsProblem(item, value);
    return Container(
      color: problem ? Colors.red.withValues(alpha: .06) : null,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(children: [
        Expanded(child: Text(item, style: TextStyle(fontSize: 13, fontWeight: problem ? FontWeight.bold : null))),
        const SizedBox(width: 8),
        SegmentedButton<String>(
          emptySelectionAllowed: true,
          showSelectedIcon: false,
          style: const ButtonStyle(visualDensity: VisualDensity.compact, tapTargetSize: MaterialTapTargetSize.shrinkWrap),
          segments: [for (final o in actaOptions(item)) ButtonSegment(value: o, label: Text(o, style: const TextStyle(fontSize: 11)))],
          selected: {if (value != null) value},
          onSelectionChanged: (v) => _set(item, v.isEmpty ? null : v.first),
        ),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final checked = allItems.where(items.containsKey).length;
    final problems = allItems.where((i) => actaIsProblem(i, items[i])).toList();
    return scaffold(children: [
      const InfoBanner(text: 'Llenar al inicio del relevo de la unidad. $actaOptionHelp.'),
      const SectionTitle('Datos de la unidad'),
      dateShift(),
      const SizedBox(height: 12),
      _pair(_field('samu', 'SAMU N°'), _field('placa', 'Placa N°')),
      _pair(_field('establecimiento', 'Establecimiento'), _field('ciaBomberos', 'Cía. de bomberos')),
      _field('conductor', 'Conductor'),
      const SectionTitle('Inicio y final'),
      _pair(TimeField(controller: ctl('horaInicio'), label: 'Hora inicio'), KmField(controller: ctl('kmInicio'), label: 'Km inicio')),
      _pair(TimeField(controller: ctl('horaFinal'), label: 'Hora final'), KmField(controller: ctl('kmFinal'), label: 'Km final')),
      FuelLevelPicker(label: 'Combustible inicio', value: fuelStart, onChanged: (v) => setState(() { fuelStart = v; dirty = true; })),
      FuelLevelPicker(label: 'Combustible final', value: fuelEnd, onChanged: (v) => setState(() { fuelEnd = v; dirty = true; })),
      _field('proxMantenimiento', 'Próximo mantenimiento (km o fecha)'),
      const SizedBox(height: 10),
      Wrap(spacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
        const Text('Tipo de combustible:'),
        for (final f in fuelTypes)
          ChoiceChip(label: Text(f), selected: fuelType == f, onSelected: (on) => setState(() { fuelType = on ? f : ''; dirty = true; })),
      ]),
      SectionTitle('Revisión: $checked/${allItems.length} · ${problems.length} con observación'),
      LinearProgressIndicator(value: checked / allItems.length),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('Mostrar solo ítems con observación'),
        value: onlyProblems,
        onChanged: (v) => setState(() => onlyProblems = v),
      ),
      for (final group in actaGroups.entries)
        Card(
          margin: const EdgeInsets.only(bottom: 10),
          clipBehavior: Clip.antiAlias,
          child: ExpansionTile(
            title: Text(group.key, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text('${group.value.where(items.containsKey).length}/${group.value.length} revisados · '
                '${group.value.where((i) => actaIsProblem(i, items[i])).length} con observación'),
            children: [
              if (!onlyProblems && group.value.any((i) => !items.containsKey(i)))
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () => _markGroupOk(group.value),
                    icon: const Icon(Icons.done_all),
                    label: const Text('Marcar pendientes como conformes'),
                  ),
                ),
              for (final item in group.value)
                if (!onlyProblems || actaIsProblem(item, items[item])) _itemRow(item),
              const SizedBox(height: 8),
            ],
          ),
        ),
      const SizedBox(height: 8),
      VoiceTextField(
        controller: ctl('observaciones'),
        dictation: dictation,
        label: 'Observaciones (problemas mecánicos u otras ocurrencias)${problems.isNotEmpty ? ' *' : ''}',
        hint: problems.isEmpty ? null : 'Ítems observados: ${problems.take(4).join(', ')}${problems.length > 4 ? '…' : ''}',
        minLines: 3,
        maxLines: 8,
      ),
      const SectionTitle('Firmas'),
      _field('pilotoEntrante', 'Piloto entrante'),
      const SizedBox(height: 10),
      _field('pilotoSaliente', 'Piloto saliente'),
      const SizedBox(height: 10),
      _field('medicoEntrante', 'Médico entrante'),
      const SizedBox(height: 20),
      ...finalButtons(),
    ]);
  }
}
