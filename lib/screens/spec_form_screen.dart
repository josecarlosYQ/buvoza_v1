import 'package:flutter/material.dart';
import '../models/form_entry.dart';
import '../models/spec_forms.dart';
import '../services/voice_form_parser.dart';
import '../widgets/form_widgets.dart';
import '../widgets/voice_text_field.dart';
import 'form_base.dart';

/// Pantalla genérica para los formatos descritos en `spec_forms.dart`
/// (ficha de atención prehospitalaria, CRUE y reporte médico diario).
class SpecFormScreen extends StatefulWidget {
  const SpecFormScreen({super.key, required this.spec, this.entry});
  final FormSpec spec;
  final FormEntry? entry;
  @override
  State<SpecFormScreen> createState() => SpecFormScreenState();
}

class SpecRow {
  SpecRow(List<SpecField> fields, Map<String, dynamic> values, VoidCallback onChange)
      : controllers = {
          for (final f in fields)
            if (_usesController(f)) f.key: TextEditingController(text: (values[f.key] ?? '').toString())..addListener(onChange),
        },
        choices = {
          for (final f in fields)
            if (f.kind == SpecKind.choice) f.key: (values[f.key] ?? '').toString(),
        };
  final Map<String, TextEditingController> controllers;
  final Map<String, String> choices;

  bool has(String key) => (controllers[key]?.text.trim().isNotEmpty ?? false) || (choices[key]?.isNotEmpty ?? false);
  void dispose() {
    for (final c in controllers.values) {
      c.dispose();
    }
  }
}

bool _usesController(SpecField f) => f.kind != SpecKind.choice && f.kind != SpecKind.flags && f.kind != SpecKind.rows && !f.isComputed;

class SpecFormScreenState extends State<SpecFormScreen> with FormScreenState<SpecFormScreen> {
  FormSpec get spec => widget.spec;

  late final Map<String, String> choices = {
    for (final f in spec.allFields)
      if (f.kind == SpecKind.choice) f.key: entry.text(f.key),
  };
  late final Map<String, Set<String>> flags = {
    for (final f in spec.allFields)
      if (f.kind == SpecKind.flags) f.key: {for (final v in (entry.data[f.key] as List?) ?? const []) v.toString()},
  };
  late final Map<String, List<SpecRow>> rows = {
    for (final f in spec.allFields)
      if (f.kind == SpecKind.rows)
        f.key: [for (final r in (entry.data[f.key] as List?) ?? const []) SpecRow(f.fields, Map<String, dynamic>.from(r as Map), markDirty)],
  };

  @override
  FormEntry? get initialEntry => widget.entry;
  @override
  FormType get formType => spec.type;

  @override
  void onReady() {
    final s = settings.toJson();
    for (final f in spec.allFields) {
      if (f.prefill != null) prefill(f.key, (s[f.prefill] ?? '').toString());
    }
  }

  // ---- Filas ----

  SpecRow _addRow(SpecField f) {
    final row = SpecRow(f.fields, const {}, markDirty);
    setState(() {
      rows[f.key]!.add(row);
      dirty = true;
    });
    return row;
  }

  void _removeRow(SpecField f, int i) => setState(() {
        rows[f.key]!.removeAt(i).dispose();
        dirty = true;
      });

  /// Por voz, cada dato va a la última fila; si ese dato ya estaba lleno, empieza una fila nueva.
  SpecRow _rowFor(SpecField table, String key) {
    final list = rows[table.key]!;
    if (list.isEmpty || list.last.has(key)) return _addRow(table);
    return list.last;
  }

  // ---- Voz ----

  static VoiceField _cutting(VoiceField v) =>
      VoiceField(label: v.label, aliases: v.aliases, apply: v.apply, hint: v.hint, needsValue: v.needsValue, freeText: true);

  VoiceField _pressure(SpecField f, void Function(String) set) => VoiceField(
        label: f.label,
        aliases: f.spoken,
        hint: '120 sobre 80',
        apply: (v) {
          final p = spokenPressure(v);
          if (p == null) return null;
          set(p);
          return p;
        },
      );

  VoiceField _flags(SpecField f) => VoiceField(
        label: f.label,
        aliases: f.spoken,
        hint: f.options.keys.join(' / '),
        apply: (v) {
          final heard = ' ${normalizePhrase(v)} ';
          final found = [
            for (final o in f.options.entries)
              if ([o.key, ...o.value].any((w) => heard.contains(' ${normalizePhrase(w)} '))) o.key,
          ];
          if (found.isEmpty) return null;
          flags[f.key]!.addAll(found);
          return found.join(', ');
        },
      );

  List<VoiceField> _fieldVoice(SpecField f, {required void Function(String) set}) {
    final label = f.label;
    final VoiceField v = switch (f.kind) {
      SpecKind.text || SpecKind.longText => VoiceField.text(label, f.spoken, set, freeText: f.kind == SpecKind.longText),
      SpecKind.number || SpecKind.integer => VoiceField.number(label, f.spoken, set, integer: f.kind == SpecKind.integer),
      SpecKind.time => VoiceField.time(label, f.spoken, set),
      SpecKind.pressure => _pressure(f, set),
      SpecKind.choice => VoiceField.choice(label, f.spoken, f.options, set),
      SpecKind.flags => _flags(f),
      SpecKind.rows => throw StateError('rows'),
    };
    return [f.cutsText ? _cutting(v) : v];
  }

  @override
  List<VoiceField> voiceFields() => [
        for (final f in spec.allFields)
          if (f.isComputed)
            ...const []
          else if (f.kind == SpecKind.rows) ...[
            VoiceField.command('Nueva ${f.rowLabel.toLowerCase()}', ['nueva ${f.rowLabel.toLowerCase()}', 'otra ${f.rowLabel.toLowerCase()}', 'nuevo ${f.rowLabel.toLowerCase()}', 'otro ${f.rowLabel.toLowerCase()}'],
                () => _addRow(f)),
            for (final c in f.fields)
              if (!c.isComputed)
                ..._fieldVoice(c, set: (v) {
                  final row = _rowFor(f, c.key);
                  if (c.kind == SpecKind.choice) {
                    row.choices[c.key] = v;
                  } else {
                    row.controllers[c.key]!.text = v;
                  }
                }),
          ] else if (f.kind == SpecKind.text || f.kind == SpecKind.longText)
            ...vText(f.key, f.label, f.spoken, freeText: f.kind == SpecKind.longText)
          else
            ..._fieldVoice(f, set: (v) {
              if (f.kind == SpecKind.choice) {
                choices[f.key] = v;
              } else {
                ctl(f.key).text = v;
              }
            }),
      ];

  // ---- Guardado ----

  @override
  void collect() {
    collectControllers();
    for (final f in spec.allFields) {
      switch (f.kind) {
        case SpecKind.choice:
          entry.data[f.key] = choices[f.key];
        case SpecKind.flags:
          entry.data[f.key] = [for (final o in f.options.keys) if (flags[f.key]!.contains(o)) o];
        case SpecKind.rows:
          entry.data[f.key] = [
            for (final r in rows[f.key]!)
              () {
                final m = <String, dynamic>{
                  for (final c in r.controllers.entries) c.key: c.value.text.trim(),
                  ...r.choices,
                };
                for (final c in f.fields.where((c) => c.isComputed)) {
                  m[c.key] = computeSum(c, m);
                }
                return m;
              }(),
          ];
        default:
          if (f.isComputed) entry.data[f.key] = computeSum(f, entry.data);
      }
    }
  }

  @override
  String? validate() {
    final k = spec.titleKey;
    if (k.isEmpty) return null;
    final hasAnything = entry.data.entries.any((e) => e.value is String ? (e.value as String).isNotEmpty : e.value is List && (e.value as List).isNotEmpty);
    return hasAnything ? null : 'El registro está vacío.';
  }

  @override
  void dispose() {
    for (final list in rows.values) {
      for (final r in list) {
        r.dispose();
      }
    }
    super.dispose();
  }

  // ---- Interfaz ----

  TextInputType? _keyboard(SpecField f) => switch (f.kind) {
        SpecKind.number => const TextInputType.numberWithOptions(decimal: true),
        SpecKind.integer => TextInputType.number,
        SpecKind.pressure => TextInputType.datetime,
        _ => null,
      };

  Widget _input(SpecField f, TextEditingController c) {
    if (f.kind == SpecKind.time) return TimeField(controller: c, label: f.label);
    if (f.kind == SpecKind.longText) return VoiceTextField(controller: c, dictation: dictation, label: f.label, minLines: 2, maxLines: 6);
    return TextField(
      controller: c,
      keyboardType: _keyboard(f),
      textCapitalization: _keyboard(f) == null ? TextCapitalization.sentences : TextCapitalization.none,
      onChanged: (_) => setState(() {}),
      decoration: InputDecoration(labelText: f.label, suffixText: f.unit, border: const OutlineInputBorder(), isDense: true),
    );
  }

  Widget _computed(SpecField f, Map<String, dynamic> values) {
    final v = computeSum(f, values);
    return InputDecorator(
      decoration: InputDecoration(labelText: f.label, border: const OutlineInputBorder(), isDense: true, filled: true),
      child: Text(v.isEmpty ? '—' : v, style: const TextStyle(fontWeight: FontWeight.bold)),
    );
  }

  Widget _choice(SpecField f, String value, ValueChanged<String> onChanged) => Wrap(spacing: 6, runSpacing: 2, crossAxisAlignment: WrapCrossAlignment.center, children: [
        Text('${f.label}:'),
        for (final o in f.options.keys)
          ChoiceChip(
            label: Text(o),
            selected: value == o,
            onSelected: (_) => setState(() { onChanged(value == o ? '' : o); dirty = true; }),
          ),
      ]);

  Widget _flagChips(SpecField f) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(f.label, style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        Wrap(spacing: 6, runSpacing: 2, children: [
          for (final o in f.options.keys)
            FilterChip(
              label: Text(o),
              selected: flags[f.key]!.contains(o),
              onSelected: (on) => setState(() {
                on ? flags[f.key]!.add(o) : flags[f.key]!.remove(o);
                dirty = true;
              }),
            ),
        ]),
      ]);

  Widget _rowsBlock(SpecField f) {
    final list = rows[f.key]!;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      for (var i = 0; i < list.length; i++)
        Card(
          margin: const EdgeInsets.only(bottom: 10),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Row(children: [
                CircleAvatar(radius: 14, child: Text('${i + 1}', style: const TextStyle(fontSize: 13))),
                const SizedBox(width: 8),
                Text(f.rowLabel, style: const TextStyle(fontWeight: FontWeight.bold)),
                const Spacer(),
                IconButton(tooltip: 'Quitar', icon: const Icon(Icons.delete_outline), onPressed: () => _removeRow(f, i)),
              ]),
              ..._layout(f.fields, (c) {
                if (c.isComputed) {
                  return _computed(c, {for (final e in list[i].controllers.entries) e.key: e.value.text});
                }
                if (c.kind == SpecKind.choice) return _choice(c, list[i].choices[c.key] ?? '', (v) => list[i].choices[c.key] = v);
                return _input(c, list[i].controllers[c.key]!);
              }, compact: true),
            ]),
          ),
        ),
      Align(
        alignment: Alignment.centerLeft,
        child: FilledButton.tonalIcon(onPressed: () => _addRow(f), icon: const Icon(Icons.add), label: Text('Agregar ${f.rowLabel.toLowerCase()}')),
      ),
    ]);
  }

  /// Coloca los campos: los de media línea se emparejan; el resto ocupa la línea completa.
  /// En las filas ([compact]) todos los numéricos van de dos en dos.
  List<Widget> _layout(List<SpecField> fields, Widget Function(SpecField) build, {bool compact = false}) {
    bool isHalf(SpecField f) =>
        f.half || (compact && const [SpecKind.number, SpecKind.integer, SpecKind.time, SpecKind.pressure].contains(f.kind));
    final out = <Widget>[];
    for (var i = 0; i < fields.length; i++) {
      final f = fields[i];
      if (isHalf(f) && i + 1 < fields.length && isHalf(fields[i + 1])) {
        out.add(Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: build(f)),
            const SizedBox(width: 10),
            Expanded(child: build(fields[i + 1])),
          ]),
        ));
        i++;
      } else {
        out.add(Padding(padding: const EdgeInsets.only(bottom: 10), child: build(f)));
      }
    }
    return out;
  }

  Widget _field(SpecField f) {
    if (f.isComputed) {
      return _computed(f, {for (final k in f.sumOf) k: ctl(k).text});
    }
    return switch (f.kind) {
      SpecKind.choice => _choice(f, choices[f.key] ?? '', (v) => choices[f.key] = v),
      SpecKind.flags => _flagChips(f),
      SpecKind.rows => _rowsBlock(f),
      _ => _input(f, ctl(f.key)),
    };
  }

  @override
  Widget build(BuildContext context) => scaffold(children: [
        InfoBanner(text: spec.banner),
        SectionTitle(formType.shifts.isEmpty ? 'Fecha' : 'Fecha y turno'),
        dateShift(),
        for (final s in spec.sections) ...[
          SectionTitle(s.title),
          ..._layout(s.fields, _field),
        ],
        const SizedBox(height: 12),
        ...finalButtons(),
      ]);
}
