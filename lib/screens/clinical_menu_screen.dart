import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/catalogs.dart';
import '../models/driver_catalogs.dart';
import '../models/form_entry.dart';
import '../models/spec_forms.dart';
import '../services/clinical_pdf_service.dart';
import '../services/record_store.dart';
import '../widgets/form_widgets.dart';
import 'acta_screen.dart';
import 'almacen_screen.dart';
import 'atenciones_screen.dart';
import 'bitacora_screen.dart';
import 'horas_screen.dart';
import 'oxigeno_screen.dart';
import 'procedimientos_screen.dart';
import 'settings_screen.dart';
import 'spec_form_screen.dart';
import 'soapie_screen.dart';
import 'turno_screen.dart';

Widget editorFor(FormType type, [FormEntry? entry]) => switch (type) {
      FormType.bitacora => BitacoraScreen(entry: entry),
      FormType.actaMecanica => ActaScreen(entry: entry),
      FormType.horasEmergencia => HorasScreen(entry: entry),
      FormType.atenciones => AtencionesScreen(entry: entry),
      FormType.fichaAph || FormType.crue || FormType.reporteMedico => SpecFormScreen(spec: specFor(type)!, entry: entry),
      FormType.soapie => SoapieScreen(entry: entry),
      FormType.turno => TurnoScreen(entry: entry),
      FormType.procedimientos => ProcedimientosScreen(entry: entry),
      FormType.oxigeno => OxigenoScreen(entry: entry),
      FormType.almacen => AlmacenScreen(entry: entry),
    };

/// Menú de formatos disponibles para Médico o Enfermería.
class RoleFormsScreen extends StatelessWidget {
  const RoleFormsScreen({super.key, required this.role});
  final ClinicalRole role;

  @override
  Widget build(BuildContext context) {
    final forms = FormType.values.where((t) => t.roles.contains(role)).toList();
    return Scaffold(
      appBar: AppBar(
        title: Text(switch (role) { ClinicalRole.conductor => 'Conductor', ClinicalRole.medico => 'Médico', ClinicalRole.enfermeria => 'Enfermería' }),
        actions: [
          IconButton(
            tooltip: 'Ajustes de la base',
            icon: const Icon(Icons.settings),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen())),
          ),
        ],
      ),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        InfoBanner(
            text: switch (role) {
          ClinicalRole.conductor => 'Formatos del conductor: bitácora de servicio, acta de conformidad mecánica y registro de horas de la emergencia. Cada registro genera su PDF.',
          ClinicalRole.medico => 'Formatos del médico: la ficha prehospitalaria y el reporte diario generan su PDF; las atenciones diarias y el CRUE, una hoja por mes.',
          ClinicalRole.enfermeria => 'Plantillas de enfermería: SOAPIE por paciente; entrega de turno, procedimientos y oxígeno por quincena; almacén por mes.',
        }),
        const SizedBox(height: 12),
        for (final t in forms)
          Card(
            margin: const EdgeInsets.only(bottom: 10),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              leading: CircleAvatar(child: Icon(t.icon)),
              title: Text(t.title, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(t.description),
              trailing: IconButton.filledTonal(
                tooltip: 'Nuevo registro',
                icon: const Icon(Icons.add),
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => editorFor(t))),
              ),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => FormEntriesScreen(type: t))),
            ),
          ),
      ]),
    );
  }
}

/// Lista de registros de un formato, con edición, borrado y generación de reporte.
class FormEntriesScreen extends StatefulWidget {
  const FormEntriesScreen({super.key, required this.type});
  final FormType type;
  @override
  State<FormEntriesScreen> createState() => _FormEntriesScreenState();
}

class _FormEntriesScreenState extends State<FormEntriesScreen> {
  final store = RecordStore();
  List<FormEntry> entries = [];
  bool loading = true, generating = false;
  String query = '';

  FormType get type => widget.type;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final found = await store.list(type);
    if (mounted) setState(() { entries = found; loading = false; });
  }

  Future<void> _open([FormEntry? e]) async {
    final saved = await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => editorFor(type, e)));
    if (saved == true) _load();
  }

  Future<void> _delete(FormEntry e) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Eliminar registro?'),
        content: Text('${_title(e)}\n${_dateLabel(e)}'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Eliminar')),
        ],
      ),
    );
    if (ok != true) return;
    await store.delete(e);
    _load();
  }

  Future<void> _pdf(Future<File> Function(BaseSettings s) build) async {
    setState(() => generating = true);
    try {
      final file = await build(await store.loadSettings());
      if (mounted) await showPdfActions(context, file);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('No se pudo generar el PDF: $e')));
    } finally {
      if (mounted) setState(() => generating = false);
    }
  }

  Future<void> _report() async {
    final period = await showDialog<Period>(context: context, builder: (_) => PeriodDialog(fortnightly: type.isFortnightly));
    if (period == null) return;
    final list = await store.list(type, period: period);
    if (!mounted) return;
    if (list.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('No hay registros en ${period.label}.')));
      return;
    }
    final pdf = ClinicalPdfService();
    await _pdf((s) => switch (type) {
          FormType.turno => pdf.turno(list, period, s),
          FormType.procedimientos => pdf.procedimientos(list, period, s),
          FormType.oxigeno => pdf.oxigeno(list, period, s),
          FormType.almacen => pdf.almacen(list, period, s),
          FormType.atenciones => pdf.atenciones(list, period, s),
          FormType.crue => pdf.specReport(list, period, s),
          _ => throw UnsupportedError('${type.title} se imprime por registro'),
        });
  }

  String _dateLabel(FormEntry e) =>
      '${DateFormat('dd/MM/yyyy').format(e.date)}${e.shift.isEmpty ? '' : ' · Turno ${shiftNames[e.shift] ?? e.shift}'}';

  String _title(FormEntry e) {
    switch (type) {
      case FormType.bitacora:
        final trips = ((e.data['recorridos'] as List?) ?? const []).length;
        final a = parseKm(e.text('kmInicio')), b = parseKm(e.text('kmFinal'));
        return '$trips recorrido(s)${a != null && b != null ? ' · ${b - a} km' : ''}';
      case FormType.actaMecanica:
        final items = e.map('items');
        final bad = items.entries.where((i) => actaIsProblem(i.key, i.value.toString())).length;
        return bad == 0 ? 'Unidad conforme' : '$bad ítem(s) con observación';
      case FormType.horasEmergencia:
        final rows = ((e.data['emergencias'] as List?) ?? const []).length;
        return '$rows emergencia(s)';
      case FormType.atenciones:
        if (e.data['cancelado'] == true) return 'Cancelado${e.text('paciente').isEmpty ? '' : ' · ${e.text('paciente')}'}';
        return e.text('paciente').isEmpty ? 'Paciente sin nombre' : e.text('paciente');
      case FormType.fichaAph || FormType.crue || FormType.reporteMedico:
        final t = e.text(specFor(type)!.titleKey);
        return t.isEmpty ? type.title : t;
      case FormType.soapie:
        return e.text('paciente').isEmpty ? 'Paciente sin nombre' : e.text('paciente');
      case FormType.turno:
        final faltas = e.map('areas').values.where((a) => (a as Map)['ok'] == false).length;
        return faltas == 0 ? 'Todo conforme' : '$faltas área(s) con faltas';
      case FormType.procedimientos:
        final n = e.map('counts').values.fold<int>(0, (a, b) => a + (b as num).toInt());
        return '$n procedimiento(s)';
      case FormType.oxigeno:
        return e.map('balones').entries.map((b) => '${b.key}: ${(b.value as Map)['consumo'] ?? '-'} psi').join(' · ');
      case FormType.almacen:
        return 'Ingreso ${e.text('tempIngreso').isEmpty ? '-' : '${e.text('tempIngreso')} °C'} · Salida ${e.text('tempSalida').isEmpty ? '-' : '${e.text('tempSalida')} °C'}';
    }
  }

  String _subtitle(FormEntry e) {
    final who = switch (type) {
      FormType.soapie => [e.text('dx'), e.text('ficha').isEmpty ? '' : 'Ficha ${e.text('ficha')}'].where((x) => x.isNotEmpty).join(' · '),
      FormType.turno => [e.text('ambulancia'), e.text('licenciada')].where((x) => x.isNotEmpty).join(' · '),
      FormType.bitacora || FormType.actaMecanica => [e.text('placa'), e.text('conductor')].where((x) => x.isNotEmpty).join(' · '),
      FormType.horasEmergencia => [e.text('piloto'), e.text('medico')].where((x) => x.isNotEmpty).join(' · '),
      FormType.oxigeno => e.text('licenciado'),
      FormType.fichaAph || FormType.crue || FormType.reporteMedico => [for (final k in specFor(type)!.subtitleKeys) e.text(k)].where((x) => x.isNotEmpty).join(' · '),
      FormType.atenciones => [e.text('diagnostico'), e.text('prioridad').isEmpty ? '' : 'Prioridad ${e.text('prioridad')}'].where((x) => x.isNotEmpty).join(' · '),
      _ => e.text('licenciada').isNotEmpty ? e.text('licenciada') : e.text('responsable'),
    };
    return [_dateLabel(e), if (who.isNotEmpty) who].join('\n');
  }

  bool _alert(FormEntry e) => switch (type) {
        FormType.turno => e.map('areas').values.any((a) => (a as Map)['ok'] == false),
        FormType.almacen => storageTempWarning(e.text('tempIngreso')) != null || storageTempWarning(e.text('tempSalida')) != null,
        FormType.soapie => vitalSigns.any((v) => v.warning((e.map('vitals')[v.key] ?? '').toString()) != null),
        FormType.actaMecanica => e.map('items').entries.any((i) => actaIsProblem(i.key, i.value.toString())),
        _ => false,
      };

  @override
  Widget build(BuildContext context) {
    final q = query.toLowerCase();
    final visible = q.isEmpty ? entries : entries.where((e) => '${_title(e)} ${_subtitle(e)}'.toLowerCase().contains(q)).toList();
    return Scaffold(
      appBar: AppBar(
        title: Text(type.title),
        actions: [
          if (!type.perEntryPdf)
            TextButton.icon(
              onPressed: generating ? null : _report,
              icon: generating ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.picture_as_pdf),
              label: const Text('Reporte'),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(onPressed: () => _open(), icon: const Icon(Icons.add), label: const Text('Nuevo')),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(padding: const EdgeInsets.fromLTRB(12, 12, 12, 90), children: [
                if (entries.length > 5)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: TextField(
                      decoration: const InputDecoration(hintText: 'Buscar…', prefixIcon: Icon(Icons.search), border: OutlineInputBorder(), isDense: true),
                      onChanged: (v) => setState(() => query = v),
                    ),
                  ),
                if (entries.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 80),
                    child: Column(children: [
                      Icon(type.icon, size: 64, color: Colors.black26),
                      const SizedBox(height: 12),
                      const Text('Todavía no hay registros.'),
                      const SizedBox(height: 4),
                      const Text('Pulsa «Nuevo» para crear el primero.', style: TextStyle(color: Colors.black54)),
                    ]),
                  ),
                for (final e in visible)
                  Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: Icon(_alert(e) ? Icons.warning_amber : type.icon, color: _alert(e) ? Colors.orange.shade800 : const Color(0xFF1456C0)),
                      title: Text(_title(e), maxLines: 2, overflow: TextOverflow.ellipsis),
                      subtitle: Text(_subtitle(e)),
                      isThreeLine: _subtitle(e).contains('\n'),
                      onTap: () => _open(e),
                      trailing: PopupMenuButton<String>(
                        onSelected: (v) {
                          if (v == 'edit') _open(e);
                          if (v == 'pdf') _pdf((s) => ClinicalPdfService().forEntry(e, s));
                          if (v == 'delete') _delete(e);
                        },
                        itemBuilder: (_) => [
                          const PopupMenuItem(value: 'edit', child: Text('Editar')),
                          if (type.perEntryPdf) const PopupMenuItem(value: 'pdf', child: Text('Generar PDF')),
                          const PopupMenuItem(value: 'delete', child: Text('Eliminar')),
                        ],
                      ),
                    ),
                  ),
              ]),
            ),
    );
  }
}

/// Selector de mes/año y quincena para los reportes.
class PeriodDialog extends StatefulWidget {
  const PeriodDialog({super.key, required this.fortnightly});
  final bool fortnightly;
  @override
  State<PeriodDialog> createState() => _PeriodDialogState();
}

class _PeriodDialogState extends State<PeriodDialog> {
  late Period p = Period.current(fortnightly: widget.fortnightly);

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    return AlertDialog(
      title: const Text('Periodo del reporte'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        Row(children: [
          Expanded(
            flex: 3,
            child: DropdownButtonFormField<int>(
              initialValue: p.month,
              decoration: const InputDecoration(labelText: 'Mes'),
              items: [for (var m = 1; m <= 12; m++) DropdownMenuItem(value: m, child: Text(monthNames[m - 1]))],
              onChanged: (m) => setState(() => p = Period(p.year, m!, p.half)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: DropdownButtonFormField<int>(
              initialValue: p.year,
              decoration: const InputDecoration(labelText: 'Año'),
              items: [for (var y = now.year - 3; y <= now.year; y++) DropdownMenuItem(value: y, child: Text('$y'))],
              onChanged: (y) => setState(() => p = Period(y!, p.month, p.half)),
            ),
          ),
        ]),
        if (widget.fortnightly) ...[
          const SizedBox(height: 16),
          SegmentedButton<int>(
            segments: const [ButtonSegment(value: 1, label: Text('1 al 15')), ButtonSegment(value: 2, label: Text('16 a fin'))],
            selected: {p.half},
            onSelectionChanged: (v) => setState(() => p = Period(p.year, p.month, v.first)),
          ),
        ],
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        FilledButton(onPressed: () => Navigator.pop(context, p), child: const Text('Generar PDF')),
      ],
    );
  }
}
