import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'models/form_entry.dart';
import 'screens/clinical_menu_screen.dart';

void main() => runApp(const BuVozaApp());

class BuVozaApp extends StatelessWidget {
  const BuVozaApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'BuVoza', debugShowCheckedModeBanner: false,
    theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1456C0)), useMaterial3: true),
    locale: const Locale('es', 'PE'),
    supportedLocales: const [Locale('es', 'PE'), Locale('es')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
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
        _roleButton(context, 'Conductor', Icons.local_shipping, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RoleFormsScreen(role: ClinicalRole.conductor)))),
        const SizedBox(height: 12), _roleButton(context, 'Médico', Icons.medical_services, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RoleFormsScreen(role: ClinicalRole.medico)))),
        const SizedBox(height: 12), _roleButton(context, 'Enfermería', Icons.health_and_safety, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RoleFormsScreen(role: ClinicalRole.enfermeria)))),
        const Spacer(), OutlinedButton.icon(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HistoryScreen())), icon: const Icon(Icons.folder_open), label: const Text('Informes guardados')),
      ],
    )),
  );
  Widget _roleButton(BuildContext context, String label, IconData icon, VoidCallback? action) => SizedBox(height: 58, child: FilledButton.tonalIcon(onPressed: action, icon: Icon(icon), label: Text(label)));
}

class HistoryScreen extends StatefulWidget { const HistoryScreen({super.key}); @override State<HistoryScreen> createState() => _HistoryScreenState(); }
class _HistoryScreenState extends State<HistoryScreen> {
  List<File> files = []; bool loading = true;
  @override void initState() { super.initState(); _load(); }
  Future<void> _load() async { final base = await getApplicationDocumentsDirectory(); final dir = Directory('${base.path}/BuVoza/informes'); final found = dir.existsSync() ? dir.listSync().whereType<File>().where((f) => f.path.toLowerCase().endsWith('.pdf')).toList() : <File>[]; found.sort((a,b) => b.lastModifiedSync().compareTo(a.lastModifiedSync())); if (mounted) setState(() { files = found; loading = false; }); }
  @override Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('Informes guardados')), body: loading ? const Center(child: CircularProgressIndicator()) : files.isEmpty ? const Center(child: Text('Todavía no hay informes PDF guardados.')) : ListView.builder(itemCount: files.length, itemBuilder: (_, i) { final f = files[i]; return ListTile(leading: const Icon(Icons.picture_as_pdf, color: Colors.red), title: Text(f.uri.pathSegments.last), subtitle: Text(DateFormat('dd/MM/yyyy HH:mm').format(f.lastModifiedSync())), onTap: () => OpenFilex.open(f.path), trailing: IconButton(icon: const Icon(Icons.share), onPressed: () => Share.shareXFiles([XFile(f.path)]))); }));
}
