import 'dart:io';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../models/driver_report.dart';

class PdfService {
  Future<File> generate(DriverReport report) async {
    final pdf = pw.Document();
    final date = DateFormat('dd/MM/yyyy HH:mm').format(report.createdAt);
    pdf.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(36),
      build: (context) => [
        pw.Center(child: pw.Text('BUVOZA | INFORME DEL CONDUCTOR', style: pw.TextStyle(fontSize: 17, fontWeight: pw.FontWeight.bold))),
        pw.SizedBox(height: 8),
        pw.Text('Informe: ${report.id}'),
        pw.Text('Fecha y hora de creación: $date'),
        pw.SizedBox(height: 18),
        _section('1. DATOS DEL SERVICIO', [
          ['Código del servicio', report.serviceCode],
          ['Conductor responsable', report.driver],
          ['Código/placa de ambulancia', report.vehicleCode],
        ]),
        _section('2. KILOMETRAJE', [
          ['Kilometraje inicial', report.kilometrajeInicial],
          ['Kilometraje final', report.kilometrajeFinal],
          ['Recorrido calculado', report.recorrido],
        ]),
        _section('3. ESTADO DE LA UNIDAD Y EQUIPOS', [
          ['Estado general de la unidad', report.estadoUnidad],
          ['Nivel de combustible', report.combustible],
          ['Estado de equipos', report.equipos],
          ['Observaciones', report.observaciones],
        ]),
        pw.SizedBox(height: 28),
        pw.Text('Firma/validación del conductor: ______________________________'),
        pw.SizedBox(height: 8),
        pw.Text('Documento generado localmente por BuVoza.', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
      ],
    ));

    final dir = await getApplicationDocumentsDirectory();
    final reportsDir = Directory('${dir.path}/BuVoza/informes');
    if (!await reportsDir.exists()) await reportsDir.create(recursive: true);
    final file = File('${reportsDir.path}/${report.id}.pdf');
    await file.writeAsBytes(await pdf.save(), flush: true);
    return file;
  }

  pw.Widget _section(String title, List<List<String>> rows) => pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Container(width: double.infinity, padding: const pw.EdgeInsets.all(7), color: PdfColors.blue100,
        child: pw.Text(title, style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
      pw.Table(
        border: pw.TableBorder.all(color: PdfColors.grey400, width: .5),
        columnWidths: {0: const pw.FlexColumnWidth(1.1), 1: const pw.FlexColumnWidth(1.7)},
        children: rows.map((r) => pw.TableRow(children: [
          pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(r[0], style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9))),
          pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(r[1].isEmpty ? 'No registrado' : r[1], style: const pw.TextStyle(fontSize: 9))),
        ])).toList(),
      ),
      pw.SizedBox(height: 14),
    ],
  );
}
