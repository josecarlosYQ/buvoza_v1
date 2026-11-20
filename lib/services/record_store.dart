import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../models/catalogs.dart';
import '../models/form_entry.dart';

/// Guarda los registros clínicos como JSON en el almacenamiento privado de la app.
class RecordStore {
  Future<Directory> _dir(String name) async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory('${base.path}/BuVoza/$name');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  Future<void> save(FormEntry entry) async {
    final dir = await _dir('registros/${entry.type.name}');
    await File('${dir.path}/${entry.id}.json').writeAsString(jsonEncode(entry.toJson()), flush: true);
  }

  Future<void> delete(FormEntry entry) async {
    final dir = await _dir('registros/${entry.type.name}');
    final file = File('${dir.path}/${entry.id}.json');
    if (await file.exists()) await file.delete();
  }

  /// Registros de un formato, del más reciente al más antiguo.
  Future<List<FormEntry>> list(FormType type, {Period? period}) async {
    final dir = await _dir('registros/${type.name}');
    final entries = <FormEntry>[];
    await for (final f in dir.list()) {
      if (f is! File || !f.path.endsWith('.json')) continue;
      try {
        final entry = FormEntry.fromJson(jsonDecode(await f.readAsString()) as Map<String, dynamic>);
        if (period == null || period.contains(entry.date)) entries.add(entry);
      } catch (_) {
        // Un archivo dañado no debe impedir ver el resto de registros.
      }
    }
    entries.sort((a, b) {
      final byDate = b.date.compareTo(a.date);
      return byDate != 0 ? byDate : b.createdAt.compareTo(a.createdAt);
    });
    return entries;
  }

  Future<BaseSettings> loadSettings() async {
    final file = File('${(await _dir('')).path}/ajustes.json');
    if (!await file.exists()) return BaseSettings();
    try {
      return BaseSettings.fromJson(jsonDecode(await file.readAsString()) as Map<String, dynamic>);
    } catch (_) {
      return BaseSettings();
    }
  }

  Future<void> saveSettings(BaseSettings settings) async {
    final file = File('${(await _dir('')).path}/ajustes.json');
    await file.writeAsString(jsonEncode(settings.toJson()), flush: true);
  }
}
