import 'package:flutter/material.dart';
import '../models/form_entry.dart';
import '../services/voice_form_parser.dart';
import '../widgets/form_widgets.dart';
import 'form_base.dart';

class OxigenoScreen extends StatefulWidget {
  const OxigenoScreen({super.key, this.entry});
  final FormEntry? entry;
  @override
  State<OxigenoScreen> createState() => _OxigenoScreenState();
}

class _OxigenoScreenState extends State<OxigenoScreen> with FormScreenState<OxigenoScreen> {
  static const _fields = {'consumo': 'Consumo', 'trasegado': 'Trasegado', 'stock': 'Stock'};
  final _values = <String, Map<String, TextEditingController>>{};

  @override
  FormEntry? get initialEntry => widget.entry;
  @override
  FormType get formType => FormType.oxigeno;

  @override
  void onReady() => prefill('licenciado', settings.nurse);

  /// Balones configurados más los que ya existan en el registro.
  List<String> get _names => {...settings.cylinders.map((c) => c.name), ...entry.map('balones').keys}.toList();

  TextEditingController _c(String name, String field) => _values.putIfAbsent(name, () => {}).putIfAbsent(field, () {
        final saved = (entry.map('balones')[name] as Map?)?[field];
        return TextEditingController(text: saved?.toString() ?? '')..addListener(markDirty);
      });

  double? _num(String s) => double.tryParse(s.replaceAll(',', '.'));

  /// Balón al que van «consumo», «trasegado» y «stock» dichos por voz.
  String? _voiceCylinder;

  /// «Balón 7 m³» se puede decir «balón 7» o «balón de 7 metros cúbicos».
  static List<String> _cylinderAliases(String name) {
    final short = RegExp(r'^\D*\d+').firstMatch(name)?.group(0);
    return {name, if (short != null) short}.toList();
  }

  @override
  List<VoiceField> voiceFields() => [
        ...vText('licenciado', 'Licenciado encargado', ['licenciado', 'licenciada', 'encargado', 'enfermera']),
        for (final name in _names)
          VoiceField.command(name, _cylinderAliases(name), () => _voiceCylinder = name),
        for (final f in _fields.entries)
          VoiceField(
            label: f.value,
            aliases: [f.key, if (f.key == 'stock') 'stock final', if (f.key == 'consumo') 'consumido', if (f.key == 'trasegado') 'trasvasado'],
            hint: 'PSI (di antes el balón)',
            apply: (v) {
              final n = spokenNumber(v);
              final name = _voiceCylinder ?? (_names.isEmpty ? null : _names.first);
              if (n == null || name == null) return null;
              _c(name, f.key).text = formatNumber(n);
              return '$name ${formatNumber(n)} psi';
            },
          ),
      ];

  @override
  void collect() {
    collectControllers();
    entry.data['balones'] = {
      for (final name in _names)
        if (_fields.keys.any((f) => _num(_c(name, f).text) != null))
          name: {for (final f in _fields.keys) if (_num(_c(name, f).text) != null) f: _num(_c(name, f).text)},
    };
  }

  @override
  String? validate() => entry.map('balones').isEmpty ? 'Ingresa al menos un valor en PSI.' : null;

  @override
  void dispose() {
    for (final m in _values.values) {
      for (final c in m.values) {
        c.dispose();
      }
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cylinders = {for (final c in settings.cylinders) c.name: c};
    return scaffold(children: [
      const InfoBanner(text: 'Registra en PSI el consumo, lo trasegado y el stock final de cada balón. Los balones y su capacidad se configuran en Ajustes.'),
      const SectionTitle('Turno'),
      dateShift(),
      const SizedBox(height: 12),
      TextField(controller: ctl('licenciado'), textCapitalization: TextCapitalization.words, decoration: const InputDecoration(labelText: 'Licenciado encargado', prefixIcon: Icon(Icons.person), border: OutlineInputBorder())),
      const SectionTitle('Balones (PSI)'),
      for (final name in _names)
        Card(
          margin: const EdgeInsets.only(bottom: 10),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 10),
              Row(children: [
                for (final f in _fields.entries) ...[
                  Expanded(
                    child: TextField(
                      controller: _c(name, f.key),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(labelText: f.value, suffixText: 'psi', border: const OutlineInputBorder()),
                    ),
                  ),
                  if (f.key != 'stock') const SizedBox(width: 8),
                ],
              ]),
              if (cylinders[name] != null && _num(_c(name, 'consumo').text) != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text('≈ ${cylinders[name]!.litersFor(_num(_c(name, 'consumo').text)!).toStringAsFixed(0)} litros consumidos',
                      style: const TextStyle(color: Color(0xFF1456C0), fontWeight: FontWeight.w600)),
                ),
            ]),
          ),
        ),
      const SizedBox(height: 12),
      saveButton(),
    ]);
  }
}
