import 'package:flutter/material.dart';
import '../models/catalogs.dart';
import '../models/form_entry.dart';
import '../services/voice_form_parser.dart';
import '../widgets/form_widgets.dart';
import 'form_base.dart';

class ProcedimientosScreen extends StatefulWidget {
  const ProcedimientosScreen({super.key, this.entry});
  final FormEntry? entry;
  @override
  State<ProcedimientosScreen> createState() => _ProcedimientosScreenState();
}

class _ProcedimientosScreenState extends State<ProcedimientosScreen> with FormScreenState<ProcedimientosScreen> {
  late final Map<String, int> counts = {for (final e in entry.map('counts').entries) e.key: (e.value as num).toInt()};
  String filter = '';

  @override
  FormEntry? get initialEntry => widget.entry;
  @override
  FormType get formType => FormType.procedimientos;

  @override
  void onReady() => prefill('licenciada', settings.nurse);

  @override
  void collect() {
    collectControllers();
    entry.data['counts'] = {for (final e in counts.entries) if (e.value > 0) e.key: e.value};
  }

  @override
  String? validate() => counts.values.every((v) => v == 0) ? 'Registra al menos un procedimiento.' : null;

  static const _routeWords = {
    'EV': ['endovenoso', 'endovenosa', 'intravenoso', 'intravenosa', 'vía EV'],
    'IM': ['intramuscular', 'vía IM'],
    'SC': ['subcutáneo', 'subcutánea', 'vía SC'],
    'SL': ['sublingual', 'vía SL'],
    'VO': ['vía oral', 'oral'],
  };

  /// Nombre completo, y para «Administración de medicamento vía X» también «medicamento endovenoso», etc.
  static List<String> _aliases(String proc) {
    final route = RegExp(r'vía (EV|IM|SC|SL|VO)$').firstMatch(proc)?.group(1);
    final short = RegExp(r'^(Colocación de|Toma de|Uso del|Realización de|Administración de) (.+)$').firstMatch(proc)?.group(2);
    return [
      proc,
      if (short != null && route == null) short,
      if (route != null)
        for (final w in _routeWords[route]!) ...['medicamento $w', 'administración $w'],
    ];
  }

  @override
  List<VoiceField> voiceFields() => [
        ...vText('licenciada', 'Licenciada(o)', ['licenciada', 'licenciado', 'enfermera', 'enfermero']),
        for (final proc in procedureGroups.values.expand((g) => g)) ...[
          VoiceField(
            label: proc,
            aliases: _aliases(proc),
            needsValue: false,
            optionalValue: true,
            hint: 'cantidad (si no la dices, suma 1)',
            apply: (v) {
              final n = (spokenNumber(v) ?? 1).round().clamp(1, 99);
              _add(proc, n);
              return '+$n (total ${counts[proc]})';
            },
          ),
          VoiceField(
            label: 'Quitar $proc',
            aliases: [for (final a in _aliases(proc)) 'quitar $a'],
            needsValue: false,
            optionalValue: true,
            hint: 'resta 1',
            apply: (v) {
              final n = (spokenNumber(v) ?? 1).round().clamp(1, 99);
              _add(proc, -n);
              return '-$n (total ${counts[proc] ?? 0})';
            },
          ),
        ],
      ];

  void _add(String proc, int delta) => setState(() {
        counts[proc] = ((counts[proc] ?? 0) + delta).clamp(0, 999).toInt();
        dirty = true;
      });

  @override
  Widget build(BuildContext context) {
    final total = counts.values.fold(0, (a, b) => a + b);
    final q = filter.toLowerCase();
    return scaffold(children: [
      const InfoBanner(text: 'Registra los procedimientos realizados en el turno. Puedes guardar varios registros por turno: el reporte quincenal los suma.'),
      const SectionTitle('Turno'),
      dateShift(),
      const SizedBox(height: 12),
      TextField(controller: ctl('licenciada'), textCapitalization: TextCapitalization.words, decoration: const InputDecoration(labelText: 'Licenciada(o)', prefixIcon: Icon(Icons.person), border: OutlineInputBorder())),
      const SizedBox(height: 12),
      TextField(
        decoration: const InputDecoration(labelText: 'Buscar procedimiento', prefixIcon: Icon(Icons.search), border: OutlineInputBorder()),
        onChanged: (v) => setState(() => filter = v),
      ),
      SectionTitle('Procedimientos · total $total'),
      for (final group in procedureGroups.entries)
        Card(
          margin: const EdgeInsets.only(bottom: 10),
          child: ExpansionTile(
            key: ValueKey('${group.key}-${q.isNotEmpty}'),
            initiallyExpanded: q.isNotEmpty || group.key == procedureGroups.keys.first,
            title: Text(group.key, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text('${group.value.fold(0, (a, p) => a + (counts[p] ?? 0))} registrados'),
            children: [
              for (final proc in group.value.where((p) => p.toLowerCase().contains(q)))
                ListTile(
                  dense: true,
                  title: Text(proc),
                  trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                    IconButton(onPressed: (counts[proc] ?? 0) == 0 ? null : () => _add(proc, -1), icon: const Icon(Icons.remove_circle_outline)),
                    SizedBox(width: 28, child: Text('${counts[proc] ?? 0}', textAlign: TextAlign.center, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
                    IconButton(onPressed: () => _add(proc, 1), icon: const Icon(Icons.add_circle, color: Color(0xFF1456C0))),
                  ]),
                ),
            ],
          ),
        ),
      const SizedBox(height: 12),
      saveButton(),
    ]);
  }
}
