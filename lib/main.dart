import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'models/driver_report.dart';
import 'services/pdf_service.dart';
import 'services/speech_service.dart';

void main() => runApp(const BuVozaApp());

class BuVozaApp extends StatelessWidget {
  const BuVozaApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'BuVoza', debugShowCheckedModeBanner: false,
    theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1456C0)), useMaterial3: true),
    home: const RoleScreen(),
  );
}

class RoleScreen extends StatelessWidget {
  const RoleScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('BuVoza'), centerTitle: true),
    body: Padding(padding: const EdgeInsets.all(24), child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const SizedBox(height: 24), const Icon(Icons.record_voice_over, size: 76, color: Color(0xFF1456C0)),
        const SizedBox(height: 12), Text('Tu voz al servicio de la salud', textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 28), const Text('Selecciona tu rol', textAlign: TextAlign.center), const SizedBox(height: 14),
        _roleButton(context, 'Conductor', Icons.local_shipping, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StartServiceScreen()))),
        const SizedBox(height: 12), _roleButton(context, 'Médico (próximamente)', Icons.medical_services, null),
        const SizedBox(height: 12), _roleButton(context, 'Enfermería (próximamente)', Icons.health_and_safety, null),
        const Spacer(), OutlinedButton.icon(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HistoryScreen())), icon: const Icon(Icons.folder_open), label: const Text('Informes guardados')),
      ],
    )),
  );
  Widget _roleButton(BuildContext context, String label, IconData icon, VoidCallback? action) => SizedBox(height: 58, child: FilledButton.tonalIcon(onPressed: action, icon: Icon(icon), label: Text(label)));
}

class StartServiceScreen extends StatefulWidget {
  const StartServiceScreen({super.key});
  @override
  State<StartServiceScreen> createState() => _StartServiceScreenState();
}
class _StartServiceScreenState extends State<StartServiceScreen> {
  final driver = TextEditingController();
  final vehicle = TextEditingController();
  final service = TextEditingController();
  @override
  void dispose() { driver.dispose(); vehicle.dispose(); service.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Inicio del servicio')),
    body: ListView(padding: const EdgeInsets.all(20), children: [
      const InfoBanner(text: 'Registra los datos básicos. Podrás completar el kilometraje y el estado de los equipos por voz.'),
      const SizedBox(height: 18),
      TextField(controller: driver, decoration: const InputDecoration(labelText: 'Nombre del conductor', prefixIcon: Icon(Icons.person), border: OutlineInputBorder())),
      const SizedBox(height: 14), TextField(controller: vehicle, decoration: const InputDecoration(labelText: 'Código o placa de ambulancia', prefixIcon: Icon(Icons.local_shipping), border: OutlineInputBorder())),
      const SizedBox(height: 14), TextField(controller: service, decoration: const InputDecoration(labelText: 'Código del servicio (opcional)', prefixIcon: Icon(Icons.confirmation_number), border: OutlineInputBorder())),
      const SizedBox(height: 22), FilledButton.icon(onPressed: () {
        final report = DriverReport(driver: driver.text.trim(), vehicleCode: vehicle.text.trim(), serviceCode: service.text.trim());
        Navigator.push(context, MaterialPageRoute(builder: (_) => DictationScreen(report: report)));
      }, icon: const Icon(Icons.mic), label: const Text('Iniciar dictado')),
    ]),
  );
}

class DictationScreen extends StatefulWidget {
  const DictationScreen({super.key, required this.report});
  final DriverReport report;
  @override
  State<DictationScreen> createState() => _DictationScreenState();
}
class _DictationScreenState extends State<DictationScreen> {
  final speech = SpeechService();
  final controllers = <String, TextEditingController>{};
  final fields = <String, String>{
    'kilometraje inicial': 'kilometrajeInicial', 'kilometraje final': 'kilometrajeFinal',
    'estado de la unidad': 'estadoUnidad', 'combustible': 'combustible',
    'estado de equipos': 'equipos', 'observaciones': 'observaciones',
  };
  String selected = 'kilometraje inicial';
  String status = 'Preparando reconocimiento de voz…';
  bool ready = false, listening = false;
  String liveText = '';

  @override
  void initState() { super.initState(); for (final key in fields.keys) { controllers[key] = TextEditingController(); } _initSpeech(); }
  Future<void> _initSpeech() async { final ok = await speech.initialize(onStatus: (s) { if (mounted) setState(() { status = s; listening = speech.isListening; }); }); if (mounted) setState(() { ready = ok; status = ok ? 'Listo para dictar en español' : 'Reconocimiento no disponible. Revisa permisos o conexión.'; }); }
  @override
  void dispose() { for (final c in controllers.values) { c.dispose(); } speech.stop(); super.dispose(); }

  Future<void> _listen() async {
    if (!ready) { await _initSpeech(); if (!ready) return; }
    setState(() { listening = true; liveText = ''; status = 'Escuchando…'; });
    await speech.listen(onResult: (text, finalResult) {
      if (!mounted) return;
      setState(() { liveText = text; });
      if (finalResult) _processPhrase(text);
    });
  }
  Future<void> _stop() async { await speech.stop(); if (mounted) setState(() { listening = false; status = 'Dictado detenido'; }); }
  void _processPhrase(String raw) {
    final text = raw.trim(); final lower = text.toLowerCase();
    if (lower.contains('siguiente campo')) {
      final keys = fields.keys.toList(); setState(() { selected = keys[(keys.indexOf(selected) + 1) % keys.length]; status = 'Campo seleccionado: $selected'; }); return;
    }
    if (lower.contains('cancelar último') || lower.contains('cancelar ultimo')) {
      controllers[selected]!.clear(); setState(() { liveText = ''; status = 'Se limpió el campo $selected'; }); return;
    }
    String? target;
    for (final key in fields.keys) { if (lower.startsWith(key)) { target = key; break; } }
    String value = text;
    if (target != null) { value = text.substring(target.length).replaceFirst(RegExp(r'^\s*[,.:;-]?\s*'), ''); selected = target; }
    if (value.isNotEmpty) {
      final c = controllers[selected]!;
      c.text = c.text.isEmpty ? value : '${c.text} $value';
      c.selection = TextSelection.collapsed(offset: c.text.length);
      setState(() { status = 'Dato asignado a: $selected'; });
    }
  }
  void _copyToReport() {
    final r = widget.report;
    r.kilometrajeInicial = controllers['kilometraje inicial']!.text.trim();
    r.kilometrajeFinal = controllers['kilometraje final']!.text.trim();
    r.estadoUnidad = controllers['estado de la unidad']!.text.trim();
    r.combustible = controllers['combustible']!.text.trim();
    r.equipos = controllers['estado de equipos']!.text.trim();
    r.observaciones = controllers['observaciones']!.text.trim();
  }
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Dictado por voz')),
    body: ListView(padding: const EdgeInsets.all(16), children: [
      const InfoBanner(text: 'Di el nombre del campo y luego su valor. Ejemplo: “kilometraje inicial, ciento veinte mil”. También puedes seleccionar el campo y dictar solo el valor.'),
      const SizedBox(height: 12), Card(child: Padding(padding: const EdgeInsets.all(14), child: Column(children: [
        Icon(listening ? Icons.graphic_eq : Icons.mic_none, size: 52, color: listening ? Colors.red : const Color(0xFF1456C0)),
        Text(status, textAlign: TextAlign.center), const SizedBox(height: 8),
        Text(liveText.isEmpty ? 'La transcripción aparecerá aquí' : liveText, textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12), SizedBox(width: double.infinity, height: 54, child: FilledButton.icon(onPressed: listening ? _stop : _listen, icon: Icon(listening ? Icons.stop : Icons.mic), label: Text(listening ? 'Detener dictado' : 'Comenzar a dictar'))),
      ]))),
      const SizedBox(height: 8),
      Text('Campos del conductor', style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 8),
      for (final key in fields.keys) Padding(padding: const EdgeInsets.only(bottom: 12), child: TextField(
        controller: controllers[key], minLines: key == 'observaciones' || key == 'estado de equipos' ? 2 : 1,
        maxLines: key == 'observaciones' || key == 'estado de equipos' ? 3 : 1,
        onTap: () => setState(() => selected = key),
        decoration: InputDecoration(labelText: key, border: const OutlineInputBorder(), filled: selected == key, fillColor: selected == key ? Colors.blue.withOpacity(.06) : null, suffixIcon: selected == key ? const Icon(Icons.mic, color: Color(0xFF1456C0)) : null),
      )),
      const Text('Comandos: “kilometraje inicial…”, “estado de equipos…”, “siguiente campo”, “cancelar último”.', style: TextStyle(color: Colors.black54)),
      const SizedBox(height: 16), FilledButton.icon(onPressed: () { _copyToReport(); Navigator.push(context, MaterialPageRoute(builder: (_) => ReviewScreen(report: widget.report))); }, icon: const Icon(Icons.fact_check), label: const Text('Revisar informe')),
    ]),
  );
}

class ReviewScreen extends StatefulWidget {
  const ReviewScreen({super.key, required this.report});
  final DriverReport report;
  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}
class _ReviewScreenState extends State<ReviewScreen> {
  late final Map<String, TextEditingController> c;
  bool saving = false;
  @override
  void initState() { super.initState(); final r = widget.report; c = {
    'Conductor': TextEditingController(text: r.driver), 'Ambulancia': TextEditingController(text: r.vehicleCode), 'Código del servicio': TextEditingController(text: r.serviceCode),
    'Kilometraje inicial': TextEditingController(text: r.kilometrajeInicial), 'Kilometraje final': TextEditingController(text: r.kilometrajeFinal),
    'Estado de la unidad': TextEditingController(text: r.estadoUnidad), 'Combustible': TextEditingController(text: r.combustible), 'Estado de equipos': TextEditingController(text: r.equipos), 'Observaciones': TextEditingController(text: r.observaciones),
  }; }
  @override
  void dispose() { for (final x in c.values) { x.dispose(); } super.dispose(); }
  void _sync() { final r = widget.report; r.driver=c['Conductor']!.text; r.vehicleCode=c['Ambulancia']!.text; r.serviceCode=c['Código del servicio']!.text; r.kilometrajeInicial=c['Kilometraje inicial']!.text; r.kilometrajeFinal=c['Kilometraje final']!.text; r.estadoUnidad=c['Estado de la unidad']!.text; r.combustible=c['Combustible']!.text; r.equipos=c['Estado de equipos']!.text; r.observaciones=c['Observaciones']!.text; }
  Future<void> _save() async {
    _sync();
    if (widget.report.kilometrajeInicial.isEmpty || widget.report.kilometrajeFinal.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Completa el kilometraje inicial y final antes de generar el PDF.'))); return;
    }
    setState(() => saving = true);
    try { final file = await PdfService().generate(widget.report); if (!mounted) return; Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => ConfirmationScreen(report: widget.report, file: file))); }
    catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('No se pudo guardar el PDF: $e'))); }
    finally { if (mounted) setState(() => saving = false); }
  }
  @override
  Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('Revisión y edición')), body: ListView(padding: const EdgeInsets.all(16), children: [
    InfoBanner(text: 'Informe ${widget.report.id} · ${DateFormat('dd/MM/yyyy HH:mm').format(widget.report.createdAt)}. Revisa cuidadosamente todos los datos antes de generar el PDF.'),
    const SizedBox(height: 16), for (final e in c.entries) Padding(padding: const EdgeInsets.only(bottom: 12), child: TextField(controller: e.value, maxLines: e.key == 'Observaciones' || e.key == 'Estado de equipos' ? 3 : 1, decoration: InputDecoration(labelText: e.key, border: const OutlineInputBorder()))),
    if (widget.report.recorrido.isNotEmpty) Text('Recorrido calculado: ${widget.report.recorrido}', style: Theme.of(context).textTheme.titleMedium),
    const SizedBox(height: 16), FilledButton.icon(onPressed: saving ? null : _save, icon: saving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.picture_as_pdf), label: Text(saving ? 'Generando PDF…' : 'Confirmar y guardar PDF')),
  ]));
}

class ConfirmationScreen extends StatelessWidget {
  const ConfirmationScreen({super.key, required this.report, required this.file});
  final DriverReport report; final File file;
  @override
  Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('Informe guardado')), body: Padding(padding: const EdgeInsets.all(24), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
    const SizedBox(height: 30), const Icon(Icons.check_circle, size: 82, color: Colors.green), const SizedBox(height: 14), Text('PDF generado correctamente', textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleLarge), const SizedBox(height: 8), Text(report.id, textAlign: TextAlign.center), const SizedBox(height: 20), const InfoBanner(text: 'El archivo se guardó en el almacenamiento privado de la aplicación. Esta versión no envía el informe a SAMU ni al hospital.'), const SizedBox(height: 14),
    OutlinedButton.icon(onPressed: () => OpenFilex.open(file.path), icon: const Icon(Icons.picture_as_pdf), label: const Text('Abrir PDF')),
    OutlinedButton.icon(onPressed: () => Share.shareXFiles([XFile(file.path)], text: 'Informe BuVoza ${report.id}'), icon: const Icon(Icons.share), label: const Text('Compartir PDF')),
    FilledButton.icon(onPressed: () => Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const RoleScreen()), (_) => false), icon: const Icon(Icons.home), label: const Text('Volver al inicio')),
  ])));
}

class HistoryScreen extends StatefulWidget { const HistoryScreen({super.key}); @override State<HistoryScreen> createState() => _HistoryScreenState(); }
class _HistoryScreenState extends State<HistoryScreen> {
  List<File> files = []; bool loading = true;
  @override void initState() { super.initState(); _load(); }
  Future<void> _load() async { final base = await getApplicationDocumentsDirectory(); final dir = Directory('${base.path}/BuVoza/informes'); final found = dir.existsSync() ? dir.listSync().whereType<File>().where((f) => f.path.toLowerCase().endsWith('.pdf')).toList() : <File>[]; found.sort((a,b) => b.lastModifiedSync().compareTo(a.lastModifiedSync())); if (mounted) setState(() { files = found; loading = false; }); }
  @override Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('Informes guardados')), body: loading ? const Center(child: CircularProgressIndicator()) : files.isEmpty ? const Center(child: Text('Todavía no hay informes PDF guardados.')) : ListView.builder(itemCount: files.length, itemBuilder: (_, i) { final f = files[i]; return ListTile(leading: const Icon(Icons.picture_as_pdf, color: Colors.red), title: Text(f.uri.pathSegments.last), subtitle: Text(DateFormat('dd/MM/yyyy HH:mm').format(f.lastModifiedSync())), onTap: () => OpenFilex.open(f.path), trailing: IconButton(icon: const Icon(Icons.share), onPressed: () => Share.shareXFiles([XFile(f.path)]))); }));
}

class InfoBanner extends StatelessWidget { const InfoBanner({super.key, required this.text}); final String text; @override Widget build(BuildContext context) => Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: Theme.of(context).colorScheme.primaryContainer, borderRadius: BorderRadius.circular(12)), child: Text(text)); }
