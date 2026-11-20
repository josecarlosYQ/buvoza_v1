import 'package:flutter/material.dart';
import '../models/catalogs.dart';
import '../models/form_entry.dart';
import '../services/voice_form_parser.dart';
import '../widgets/form_widgets.dart';
import '../widgets/voice_text_field.dart';
import 'form_base.dart';

class AlmacenScreen extends StatefulWidget {
  const AlmacenScreen({super.key, this.entry});
  final FormEntry? entry;
  @override
  State<AlmacenScreen> createState() => _AlmacenScreenState();
}

class _AlmacenScreenState extends State<AlmacenScreen> with FormScreenState<AlmacenScreen> {
  late String confortIngreso = entry.text('confortIngreso');
  late String confortSalida = entry.text('confortSalida');

  @override
  FormEntry? get initialEntry => widget.entry;
  @override
  FormType get formType => FormType.almacen;

  @override
  void onReady() {
    prefill('responsable', settings.nurse);
    if (isNew) ctl('horaIngreso').text = _now();
  }

  String _now() => TimeOfDay.now().format24();

  @override
  void collect() {
    collectControllers();
    entry.data['confortIngreso'] = confortIngreso;
    entry.data['confortSalida'] = confortSalida;
  }

  static const _comfortWords = {
    'Confort': ['confort', 'normal', 'cómodo'],
    'Seco': ['seco'],
    'Húmedo': ['húmedo'],
  };

  @override
  List<VoiceField> voiceFields() => [
        vTime('horaIngreso', 'Hora de ingreso', ['hora de ingreso', 'hora ingreso', 'ingreso hora']),
        vNumber('tempIngreso', 'Temperatura de ingreso', ['temperatura de ingreso', 'temperatura ingreso', 'temperatura al ingreso', 'ingreso temperatura']),
        VoiceField.choice('Confort de ingreso', ['confort de ingreso', 'confort ingreso', 'humedad de ingreso', 'humedad ingreso'], _comfortWords, (v) => confortIngreso = v),
        vTime('horaSalida', 'Hora de salida', ['hora de salida', 'hora salida', 'salida hora']),
        vNumber('tempSalida', 'Temperatura de salida', ['temperatura de salida', 'temperatura salida', 'temperatura a la salida', 'salida temperatura']),
        VoiceField.choice('Confort de salida', ['confort de salida', 'confort salida', 'humedad de salida', 'humedad salida'], _comfortWords, (v) => confortSalida = v),
        ...vText('responsable', 'Responsable', ['responsable']),
        ...vText('observaciones', 'Observaciones', ['observaciones', 'observación', 'acciones correctivas'], freeText: true),
      ];

  @override
  String? validate() => entry.text('tempIngreso').isEmpty && entry.text('tempSalida').isEmpty ? 'Registra al menos una temperatura.' : null;

  Widget _block(String title, String hourKey, String tempKey, String confort, ValueChanged<String> onConfort) {
    final warning = storageTempWarning(ctl(tempKey).text);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
              child: TextField(
                controller: ctl(hourKey),
                readOnly: true,
                decoration: InputDecoration(
                  labelText: 'Hora',
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(icon: const Icon(Icons.access_time), onPressed: () => ctl(hourKey).text = _now()),
                ),
                onTap: () async {
                  final t = await showTimePicker(context: context, initialTime: TimeOfDay.now());
                  if (t != null) ctl(hourKey).text = t.format24();
                },
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: ctl(tempKey),
                keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(labelText: 'Temperatura', suffixText: '°C', border: const OutlineInputBorder(), errorText: warning, errorMaxLines: 2),
              ),
            ),
          ]),
          const SizedBox(height: 10),
          Wrap(spacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
            const Text('Confort:'),
            for (final o in comfortOptions)
              ChoiceChip(label: Text(o), selected: confort == o, onSelected: (on) => setState(() { onConfort(on ? o : ''); dirty = true; })),
          ]),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => scaffold(children: [
        InfoBanner(text: 'Registra la lectura del termohigrómetro al ingresar y al salir del almacén. Rango recomendado: ${storageTempMin.toInt()}–${storageTempMax.toInt()} °C.'),
        const SectionTitle('Fecha'),
        dateShift(),
        const SizedBox(height: 12),
        _block('Ingreso', 'horaIngreso', 'tempIngreso', confortIngreso, (v) => confortIngreso = v),
        _block('Salida', 'horaSalida', 'tempSalida', confortSalida, (v) => confortSalida = v),
        TextField(controller: ctl('responsable'), textCapitalization: TextCapitalization.words, decoration: const InputDecoration(labelText: 'Responsable', prefixIcon: Icon(Icons.person), border: OutlineInputBorder())),
        const SizedBox(height: 12),
        VoiceTextField(controller: ctl('observaciones'), dictation: dictation, label: 'Observaciones / acciones correctivas', minLines: 2, maxLines: 5),
        const SizedBox(height: 20),
        saveButton(),
      ]);
}

extension on TimeOfDay {
  String format24() => '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
}
