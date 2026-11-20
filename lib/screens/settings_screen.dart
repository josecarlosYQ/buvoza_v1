import 'package:flutter/material.dart';
import '../models/catalogs.dart';
import '../services/record_store.dart';
import '../widgets/form_widgets.dart';

/// Datos que se repiten en todos los formatos, para no escribirlos cada turno.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final store = RecordStore();
  final c = <String, TextEditingController>{
    for (final k in ['samu', 'base', 'district', 'ambulance', 'plate', 'nurse', 'doctor', 'pilot']) k: TextEditingController(),
  };
  List<OxygenCylinder> cylinders = [];
  bool loading = true;

  static const labels = {
    'samu': 'SAMU', 'base': 'Base', 'district': 'Distrito', 'ambulance': 'Ambulancia (código)', 'plate': 'Placa',
    'nurse': 'Licenciada(o) habitual', 'doctor': 'Médico habitual', 'pilot': 'Piloto (conductor) habitual',
  };

  @override
  void initState() {
    super.initState();
    store.loadSettings().then((s) {
      if (!mounted) return;
      final j = s.toJson();
      for (final e in c.entries) {
        e.value.text = (j[e.key] ?? '').toString();
      }
      setState(() { cylinders = [...s.cylinders]; loading = false; });
    });
  }

  @override
  void dispose() {
    for (final x in c.values) {
      x.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    await store.saveSettings(BaseSettings(
      samu: c['samu']!.text.trim(), base: c['base']!.text.trim(), district: c['district']!.text.trim(),
      ambulance: c['ambulance']!.text.trim(), nurse: c['nurse']!.text.trim(), doctor: c['doctor']!.text.trim(),
      pilot: c['pilot']!.text.trim(), plate: c['plate']!.text.trim().toUpperCase(), cylinders: cylinders,
    ));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ajustes guardados')));
    Navigator.pop(context);
  }

  Future<void> _editCylinder([int? index]) async {
    final current = index == null ? null : cylinders[index];
    final name = TextEditingController(text: current?.name ?? '');
    final liters = TextEditingController(text: current == null ? '' : current.liters.toStringAsFixed(0));
    final psi = TextEditingController(text: current == null ? '2000' : current.fullPsi.toStringAsFixed(0));
    final result = await showDialog<OxygenCylinder>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(index == null ? 'Nuevo balón' : 'Editar balón'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: name, decoration: const InputDecoration(labelText: 'Nombre (ej. Balón 7 m³)')),
          TextField(controller: liters, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Capacidad en litros (7 m³ = 7000 L)')),
          TextField(controller: psi, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Presión de balón lleno (PSI)')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () {
              final l = double.tryParse(liters.text.replaceAll(',', '.'));
              final p = double.tryParse(psi.text.replaceAll(',', '.'));
              if (name.text.trim().isEmpty || l == null || p == null || p <= 0) return;
              Navigator.pop(ctx, OxygenCylinder(name.text.trim(), l, p));
            },
            child: const Text('Aceptar'),
          ),
        ],
      ),
    );
    if (result == null) return;
    setState(() {
      if (index == null) {
        cylinders.add(result);
      } else {
        cylinders[index] = result;
      }
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Ajustes de la base')),
        body: loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(padding: const EdgeInsets.all(16), children: [
                const InfoBanner(text: 'Estos datos aparecen en la cabecera de los reportes y se rellenan automáticamente en cada registro nuevo.'),
                const SectionTitle('Cabecera de los formatos'),
                for (final e in c.entries)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: TextField(controller: e.value, textCapitalization: TextCapitalization.words, decoration: InputDecoration(labelText: labels[e.key], border: const OutlineInputBorder())),
                  ),
                const SectionTitle('Balones de oxígeno'),
                for (var i = 0; i < cylinders.length; i++)
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.propane_tank),
                      title: Text(cylinders[i].name),
                      subtitle: Text('${cylinders[i].liters.toStringAsFixed(0)} L a ${cylinders[i].fullPsi.toStringAsFixed(0)} PSI · '
                          '${(cylinders[i].liters / cylinders[i].fullPsi).toStringAsFixed(2)} L por PSI'),
                      onTap: () => _editCylinder(i),
                      trailing: IconButton(icon: const Icon(Icons.delete_outline), onPressed: () => setState(() => cylinders.removeAt(i))),
                    ),
                  ),
                TextButton.icon(onPressed: () => _editCylinder(), icon: const Icon(Icons.add), label: const Text('Añadir balón')),
                const SizedBox(height: 20),
                FilledButton.icon(onPressed: _save, icon: const Icon(Icons.save), label: const Text('Guardar ajustes')),
              ]),
      );
}
