import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:open_filex/open_filex.dart';
import 'package:share_plus/share_plus.dart';
import '../models/form_entry.dart';

class InfoBanner extends StatelessWidget {
  const InfoBanner({super.key, required this.text});
  final String text;
  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Theme.of(context).colorScheme.primaryContainer, borderRadius: BorderRadius.circular(12)),
      child: Text(text));
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.only(top: 18, bottom: 10),
      child: Text(text, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: const Color(0xFF1456C0))));
}

/// Fecha + selector de turno, comunes a todos los formatos.
class DateShiftPicker extends StatelessWidget {
  const DateShiftPicker({super.key, required this.type, required this.date, required this.shift, required this.onDate, required this.onShift});
  final FormType type;
  final DateTime date;
  final String shift;
  final ValueChanged<DateTime> onDate;
  final ValueChanged<String> onShift;

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        OutlinedButton.icon(
          icon: const Icon(Icons.calendar_today),
          label: Text('Fecha: ${DateFormat('dd/MM/yyyy').format(date)}'),
          onPressed: () async {
            final picked = await showDatePicker(context: context, initialDate: date, firstDate: DateTime(2020), lastDate: DateTime.now().add(const Duration(days: 1)));
            if (picked != null) onDate(picked);
          },
        ),
        if (type.shifts.isNotEmpty) ...[
          const SizedBox(height: 10),
          SegmentedButton<String>(
            segments: [for (final s in type.shifts) ButtonSegment(value: s, label: Text(s), tooltip: shiftNames[s])],
            selected: {shift},
            onSelectionChanged: (v) => onShift(v.first),
          ),
        ],
      ]);
}

/// Turno sugerido según la hora actual.
String defaultShift(FormType type) {
  final h = DateTime.now().hour;
  final shifts = type.shifts;
  if (shifts.isEmpty) return '';
  if (shifts.contains('D')) return h >= 7 && h < 19 ? 'D' : 'N';
  if (h >= 7 && h < 13) return 'M';
  if (h >= 13 && h < 19) return 'T';
  return 'N';
}

Future<void> showPdfActions(BuildContext context, File file) => showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const Icon(Icons.check_circle, size: 56, color: Colors.green),
            const SizedBox(height: 8),
            Text('PDF generado', textAlign: TextAlign.center, style: Theme.of(ctx).textTheme.titleLarge),
            Text(file.uri.pathSegments.last, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton.icon(onPressed: () => OpenFilex.open(file.path), icon: const Icon(Icons.picture_as_pdf), label: const Text('Abrir PDF')),
            const SizedBox(height: 8),
            OutlinedButton.icon(onPressed: () => Share.shareXFiles([XFile(file.path)]), icon: const Icon(Icons.share), label: const Text('Compartir PDF')),
          ]),
        ),
      ),
    );

/// Pide confirmación antes de salir si hay cambios sin guardar.
class UnsavedGuard extends StatelessWidget {
  const UnsavedGuard({super.key, required this.dirty, required this.child});
  final bool dirty;
  final Widget child;

  @override
  Widget build(BuildContext context) => PopScope(
        canPop: !dirty,
        onPopInvokedWithResult: (didPop, _) async {
          if (didPop) return;
          final leave = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('¿Salir sin guardar?'),
              content: const Text('Los datos ingresados se perderán.'),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Seguir editando')),
                TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Salir')),
              ],
            ),
          );
          if (leave == true && context.mounted) Navigator.of(context).pop();
        },
        child: child,
      );
}

String hhmm(TimeOfDay t) => '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

/// Campo de hora (24 h): se toca para elegir y el reloj pone la hora actual.
class TimeField extends StatelessWidget {
  const TimeField({super.key, required this.controller, required this.label});
  final TextEditingController controller;
  final String label;

  @override
  Widget build(BuildContext context) => TextField(
        controller: controller,
        readOnly: true,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          isDense: true,
          suffixIcon: IconButton(tooltip: 'Hora actual', icon: const Icon(Icons.access_time), onPressed: () => controller.text = hhmm(TimeOfDay.now())),
        ),
        onTap: () async {
          final parts = controller.text.split(':');
          final initial = parts.length == 2
              ? TimeOfDay(hour: int.tryParse(parts[0]) ?? 0, minute: int.tryParse(parts[1]) ?? 0)
              : TimeOfDay.now();
          final t = await showTimePicker(
            context: context,
            initialTime: initial,
            builder: (ctx, child) => MediaQuery(data: MediaQuery.of(ctx).copyWith(alwaysUse24HourFormat: true), child: child!),
          );
          if (t != null) controller.text = hhmm(t);
        },
      );
}

/// Campo numérico de kilometraje.
class KmField extends StatelessWidget {
  const KmField({super.key, required this.controller, required this.label, this.error, this.onChanged});
  final TextEditingController controller;
  final String label;
  final String? error;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) => TextField(
        controller: controller,
        keyboardType: TextInputType.number,
        onChanged: onChanged,
        decoration: InputDecoration(labelText: label, suffixText: 'km', border: const OutlineInputBorder(), isDense: true, errorText: error, errorMaxLines: 2),
      );
}

/// Nivel de combustible en décimos (1–10), como la escala del formato impreso.
class FuelLevelPicker extends StatelessWidget {
  const FuelLevelPicker({super.key, required this.label, required this.value, required this.onChanged});
  final String label;
  final int? value;
  final ValueChanged<int?> onChanged;

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.local_gas_station, color: value != null && value! <= 2 ? Colors.red : const Color(0xFF1456C0)),
          const SizedBox(width: 6),
          Expanded(child: Text('$label: ${value == null ? 'sin registrar' : '$value/10'}')),
          if (value != null) TextButton(onPressed: () => onChanged(null), child: const Text('Borrar')),
        ]),
        Slider(value: (value ?? 0).toDouble(), min: 0, max: 10, divisions: 10, label: '${value ?? 0}/10', onChanged: (v) => onChanged(v.round())),
      ]);
}
