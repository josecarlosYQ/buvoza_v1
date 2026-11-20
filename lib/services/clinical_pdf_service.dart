import 'dart:io';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../models/catalogs.dart';
import '../models/driver_catalogs.dart';
import '../models/form_entry.dart';
import '../models/spec_forms.dart';

/// Genera los PDF con la misma estructura que las plantillas .xlsx de SAMU.
class ClinicalPdfService {
  ClinicalPdfService({Future<Directory> Function()? baseDir}) : _baseDir = baseDir ?? getApplicationDocumentsDirectory;

  /// Carpeta base donde se guardan los PDF (inyectable para pruebas).
  final Future<Directory> Function() _baseDir;
  static final _blue = PdfColor.fromHex('#DCE6F4');
  static final _red = PdfColor.fromHex('#C62828');
  static final _dmy = DateFormat('dd/MM/yyyy');

  /// PDF de un registro individual (SOAPIE y formatos del conductor).
  Future<File> forEntry(FormEntry e, BaseSettings s) => switch (e.type) {
        FormType.soapie => soapie(e, s),
        FormType.bitacora => bitacora(e, s),
        FormType.actaMecanica => acta(e, s),
        FormType.horasEmergencia => horas(e, s),
        FormType.fichaAph || FormType.reporteMedico => specEntry(e, s),
        _ => throw UnsupportedError('${e.type.title} se imprime como reporte del periodo'),
      };

  // ---------- SOAPIE (una hoja por paciente) ----------

  Future<File> soapie(FormEntry e, BaseSettings s) async {
    final pdf = pw.Document();
    final vitals = e.map('vitals');
    final border = pw.TableBorder.all(color: PdfColors.grey600, width: .5);
    // Cada línea es una tabla de una fila para que las celdas compartan altura.
    pw.Widget line(List<(String, String, int)> cells) => pw.Table(
          border: border,
          columnWidths: {for (var i = 0; i < cells.length; i++) i: pw.FlexColumnWidth(cells[i].$3.toDouble())},
          children: [
            pw.TableRow(children: [
              for (final (label, value, _) in cells)
                pw.Padding(
                  padding: const pw.EdgeInsets.all(5),
                  child: pw.RichText(text: pw.TextSpan(children: [
                    pw.TextSpan(text: '$label ', style: const pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
                    pw.TextSpan(text: value, style: const pw.TextStyle(fontSize: 9)),
                  ])),
                ),
            ]),
          ],
        );
    String mark(bool on) => on ? '(X)' : '(   )';

    pdf.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(32),
      build: (_) => [
        pw.Center(child: pw.Text('REGISTRO DE ENFERMERÍA - SOAPIE', style: const pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold))),
        pw.Center(child: pw.Text(s.samu, style: const pw.TextStyle(fontSize: 10))),
        pw.SizedBox(height: 10),
        _band('DATOS DEL EQUIPO'),
        line([
          ('TURNO:', e.type.shifts.map((t) => '$t ${mark(e.shift == t)}').join('   '), 3),
          ('FECHA:', _dmy.format(e.date), 1),
          ('N° FICHA APH:', e.text('ficha'), 1),
        ]),
        line([('MÉDICO:', e.text('medico'), 1)]),
        line([('ENFERMERA:', e.text('enfermera'), 1)]),
        line([('PILOTO:', e.text('piloto'), 1)]),
        line([('OBSERVACIONES:', e.text('observaciones'), 1)]),
        _band('DATOS DEL PACIENTE'),
        line([('NOMBRES Y APELLIDOS:', e.text('paciente'), 1)]),
        line([('EDAD:', e.text('edad'), 1), ('DNI:', e.text('dni'), 1), ('SEXO:', e.text('sexo'), 1)]),
        line([('TIPO DE SEGURO:', insuranceTypes.map((t) => '$t ${mark(e.text('seguro') == t)}').join('   '), 1)]),
        line([('DX MÉDICO:', e.text('dx'), 1)]),
        _band('SOAPIE'),
        for (final k in soapieSections.keys)
          pw.Table(border: border, columnWidths: const {0: pw.FixedColumnWidth(28), 1: pw.FlexColumnWidth()}, children: [
            pw.TableRow(verticalAlignment: pw.TableCellVerticalAlignment.full, children: [
              pw.Container(
                alignment: pw.Alignment.center,
                color: _blue,
                child: pw.Text(k, style: const pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
              ),
              pw.Container(
                constraints: const pw.BoxConstraints(minHeight: 48),
                padding: const pw.EdgeInsets.all(6),
                child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                  if (k == 'O')
                    pw.Padding(
                      padding: const pw.EdgeInsets.only(bottom: 4),
                      child: pw.Wrap(spacing: 14, children: [
                        for (final v in vitalSigns)
                          pw.Text('${v.label}: ${(vitals[v.key] ?? '').toString()}${v.warning((vitals[v.key] ?? '').toString()) != null ? ' (!)' : ''}',
                              style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold,
                                  color: v.warning((vitals[v.key] ?? '').toString()) != null ? _red : PdfColors.black)),
                      ]),
                    ),
                  pw.Text(e.text(k), style: const pw.TextStyle(fontSize: 9.5)),
                ]),
              ),
            ]),
          ]),
        pw.SizedBox(height: 46),
        pw.Row(mainAxisAlignment: pw.MainAxisAlignment.end, children: [
          pw.Column(children: [
            pw.Container(width: 200, height: .7, color: PdfColors.black),
            pw.SizedBox(height: 3),
            pw.Text('FIRMA Y SELLO', style: const pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
            pw.Text(e.text('enfermera'), style: const pw.TextStyle(fontSize: 8)),
          ]),
        ]),
        _footer(e.id),
      ],
    ));
    return _save(pdf, e.id);
  }

  // ---------- Entrega de turno (quincenal, M/T/N) ----------

  Future<File> turno(List<FormEntry> entries, Period p, BaseSettings s) async {
    final pdf = pw.Document();
    final shifts = FormType.turno.shifts;
    final byCell = {for (final e in entries.reversed) '${e.date.day}|${e.shift}': e};
    final rows = [
      for (final area in turnoAreas.keys)
        _GridRow(area, {
          for (final c in byCell.entries)
            c.key: (c.value.map('areas')[area] as Map?)?['ok'] == false ? 'F' : 'OK',
        }),
    ];
    final notes = [
      for (final e in entries.reversed)
        if (_turnoNote(e).isNotEmpty) '${_dmy.format(e.date)} · Turno ${e.shift} · ${e.text('licenciada')}: ${_turnoNote(e)}',
    ];
    pdf.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4.landscape,
      margin: const pw.EdgeInsets.all(22),
      build: (_) => [
        _title('FORMATO PARA ENTREGA DE TURNO DE ENFERMERÍA'),
        _headerRow([['MES:', p.label], ['AMBULANCIA:', entries.isNotEmpty ? entries.first.text('ambulancia') : s.ambulance], ['BASE:', s.base]]),
        pw.Text('OK = todo correcto en la recepción del turno · F = falta (ver detalle). Celda vacía = turno no registrado.',
            style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey700)),
        pw.SizedBox(height: 4),
        ..._grid(firstHeader: 'ÁREA A EVALUAR', days: p.days, shifts: shifts, rows: rows, labelWidth: 120, showTotal: false),
        pw.SizedBox(height: 10),
        _band('PENDIENTES, FALTAS Y OBSERVACIONES'),
        if (notes.isEmpty) pw.Text('Sin observaciones en el periodo.', style: const pw.TextStyle(fontSize: 8)),
        for (final n in notes) pw.Bullet(text: n, style: const pw.TextStyle(fontSize: 8)),
        pw.SizedBox(height: 8),
        _band('LICENCIADA(O) A CARGO POR TURNO'),
        pw.Wrap(spacing: 14, runSpacing: 2, children: [
          for (final e in entries.reversed)
            pw.Text('${e.date.day}${e.shift}: ${e.text('licenciada')}', style: const pw.TextStyle(fontSize: 7.5)),
        ]),
        _footer('TUR-${p.fileTag}'),
      ],
    ));
    return _save(pdf, 'TURNO-${p.fileTag}');
  }

  String _turnoNote(FormEntry e) {
    final faltas = [
      for (final a in e.map('areas').entries)
        if ((a.value as Map)['ok'] == false) '${a.key}: ${(a.value as Map)['falta'] ?? 'falta'}',
    ];
    return [
      if (faltas.isNotEmpty) 'Faltas - ${faltas.join('; ')}',
      if (e.text('pendientes').isNotEmpty) 'Pendientes - ${e.text('pendientes')}',
      if (e.text('observaciones').isNotEmpty) 'Obs. - ${e.text('observaciones')}',
    ].join(' | ');
  }

  // ---------- Procedimientos (quincenal, D/N) ----------

  Future<File> procedimientos(List<FormEntry> entries, Period p, BaseSettings s) async {
    final pdf = pw.Document();
    final shifts = FormType.procedimientos.shifts;
    final counts = <String, Map<String, int>>{}; // procedimiento -> 'día|turno' -> n
    for (final e in entries) {
      e.map('counts').forEach((proc, n) {
        final cell = counts.putIfAbsent(proc, () => {});
        cell['${e.date.day}|${e.shift}'] = (cell['${e.date.day}|${e.shift}'] ?? 0) + (n as num).toInt();
      });
    }
    var grandTotal = 0;
    for (final group in procedureGroups.entries) {
      final colTotals = <String, int>{};
      final rows = [
        for (final proc in group.value)
          () {
            final cells = counts[proc] ?? {};
            cells.forEach((k, v) => colTotals[k] = (colTotals[k] ?? 0) + v);
            final total = cells.values.fold(0, (a, b) => a + b);
            grandTotal += total;
            return _GridRow(proc, {for (final c in cells.entries) c.key: '${c.value}'}, total: total == 0 ? '' : '$total');
          }(),
      ];
      rows.add(_GridRow('TOTAL', {for (final c in colTotals.entries) c.key: '${c.value}'},
          total: '${colTotals.values.fold(0, (a, b) => a + b)}', bold: true));
      pdf.addPage(pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(22),
        build: (_) => [
          _title('REPORTE DE PROCEDIMIENTOS DE ENFERMERÍA'),
          _headerRow([['SAMU:', s.samu], ['BASE:', s.base], ['DISTRITO:', s.district], ['MES/AÑO:', p.label]]),
          pw.Text(group.key.toUpperCase(), style: const pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 3),
          ..._grid(firstHeader: 'PROCEDIMIENTO', days: p.days, shifts: shifts, rows: rows),
          if (group.key == procedureGroups.keys.last) ...[
            pw.SizedBox(height: 8),
            pw.Text('TOTAL GENERAL DE PROCEDIMIENTOS EN EL PERIODO: $grandTotal', style: const pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
          ],
          _footer('PRO-${p.fileTag}'),
        ],
      ));
    }
    return _save(pdf, 'PROCEDIMIENTOS-${p.fileTag}');
  }

  // ---------- Oxígeno (quincenal, D/N, PSI) ----------

  Future<File> oxigeno(List<FormEntry> entries, Period p, BaseSettings s) async {
    final pdf = pw.Document();
    final shifts = FormType.oxigeno.shifts;
    final names = {...s.cylinders.map((c) => c.name), for (final e in entries) ...e.map('balones').keys};
    final rows = <_GridRow>[];
    final consumoPsi = <String, double>{};
    final ordered = entries.reversed.toList(); // cronológico, para tomar el último stock
    for (final name in names) {
      for (final field in const ['consumo', 'trasegado', 'stock']) {
        final cells = <String, double>{};
        String? lastStock;
        for (final e in ordered) {
          final v = _num((e.map('balones')[name] as Map?)?[field]);
          if (v == null) continue;
          final k = '${e.date.day}|${e.shift}';
          cells[k] = field == 'stock' ? v : (cells[k] ?? 0) + v;
          if (field == 'stock') lastStock = _fmt(v);
        }
        final sum = cells.values.fold(0.0, (a, b) => a + b);
        if (field == 'consumo') consumoPsi[name] = sum;
        rows.add(_GridRow('$name · ${field.toUpperCase()}', {for (final c in cells.entries) c.key: _fmt(c.value)},
            total: field == 'stock' ? (lastStock ?? '') : (sum == 0 ? '' : _fmt(sum)), bold: field == 'consumo'));
      }
    }
    final cylinders = {for (final c in s.cylinders) c.name: c};
    final licenciados = {for (final e in entries) e.text('licenciado')}..remove('');
    pdf.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4.landscape,
      margin: const pw.EdgeInsets.all(22),
      build: (_) => [
        _title('REPORTE DE CONSUMO DE OXÍGENO MEDICINAL EN PSI - LITROS'),
        _headerRow([['SAMU:', s.samu], ['BASE:', s.base], ['DISTRITO:', s.district], ['MES/AÑO:', p.label]]),
        ..._grid(firstHeader: 'DESCRIPCIÓN (PSI)', days: p.days, shifts: shifts, rows: rows, labelWidth: 150, totalHeader: 'TOTAL QUINC.'),
        pw.SizedBox(height: 10),
        _band('CONSUMO DE OXÍGENO EN LITROS'),
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey600, width: .5),
          children: [
            _tableRow(['Balón', 'Capacidad (L)', 'Presión llena (PSI)', 'Consumo (PSI)', 'Consumo (L)'], header: true),
            for (final name in names)
              () {
                final c = cylinders[name];
                final psi = consumoPsi[name] ?? 0;
                return _tableRow([name, c == null ? '-' : _fmt(c.liters), c == null ? '-' : _fmt(c.fullPsi), _fmt(psi), c == null ? 'Configure el balón' : _fmt(c.litersFor(psi))]);
              }(),
          ],
        ),
        pw.SizedBox(height: 4),
        pw.Text('Litros = PSI consumidos × capacidad del balón (L) / presión de balón lleno (PSI).', style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey700)),
        pw.SizedBox(height: 10),
        pw.Text('LICENCIADO ENCARGADO: ${licenciados.isEmpty ? s.nurse : licenciados.join(', ')}', style: const pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
        _footer('OXI-${p.fileTag}'),
      ],
    ));
    return _save(pdf, 'OXIGENO-${p.fileTag}');
  }

  // ---------- Almacén de medicamentos (mensual) ----------

  Future<File> almacen(List<FormEntry> entries, Period p, BaseSettings s) async {
    final pdf = pw.Document();
    final ordered = entries.reversed.toList();
    pw.Widget tempCell(String t) {
      final w = storageTempWarning(t);
      return pw.Padding(
        padding: const pw.EdgeInsets.all(4),
        child: pw.Text(t.isEmpty ? '' : '$t °C${w != null ? ' (!)' : ''}',
            style: pw.TextStyle(fontSize: 8, color: w != null ? _red : PdfColors.black, fontWeight: w != null ? pw.FontWeight.bold : null)),
      );
    }

    pw.Widget txt(String t) => pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(t, style: const pw.TextStyle(fontSize: 8)));
    final outOfRange = ordered.where((e) => storageTempWarning(e.text('tempIngreso')) != null || storageTempWarning(e.text('tempSalida')) != null).length;
    pdf.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(28),
      build: (_) => [
        _title('CONTROL DE TEMPERATURA EN ALMACÉN DE MEDICAMENTOS ${s.samu.toUpperCase()}'),
        _headerRow([['MES:', monthNames[p.month - 1].toUpperCase()], ['AÑO:', '${p.year}'], ['BASE:', s.base]]),
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey600, width: .5),
          columnWidths: const {7: pw.FlexColumnWidth(2.2)},
          children: [
            _tableRow(['Fecha', 'Hora ingreso', 'Temperatura', 'Confort', 'Hora salida', 'Temperatura', 'Confort', 'Observaciones / responsable'], header: true),
            for (final e in ordered)
              pw.TableRow(children: [
                txt(_dmy.format(e.date)),
                txt(e.text('horaIngreso')),
                tempCell(e.text('tempIngreso')),
                txt(e.text('confortIngreso')),
                txt(e.text('horaSalida')),
                tempCell(e.text('tempSalida')),
                txt(e.text('confortSalida')),
                txt([e.text('observaciones'), e.text('responsable')].where((x) => x.isNotEmpty).join(' - ')),
              ]),
          ],
        ),
        pw.SizedBox(height: 8),
        pw.Text('Rango recomendado: ${storageTempMin.toInt()}-${storageTempMax.toInt()} °C (temperatura ambiente controlada). (!) = fuera de rango. '
            'Días con lecturas fuera de rango: $outOfRange de ${ordered.length}.', style: const pw.TextStyle(fontSize: 8)),
        _footer('ALM-${p.fileTag}'),
      ],
    ));
    return _save(pdf, 'ALMACEN-${p.fileTag}');
  }

  // ---------- Registro de atenciones diarias (conductor, hoja mensual) ----------

  Future<File> atenciones(List<FormEntry> entries, Period p, BaseSettings s) async {
    final pdf = pw.Document();
    final ordered = [...entries]..sort((a, b) {
        final byDate = a.date.compareTo(b.date);
        return byDate != 0 ? byDate : a.createdAt.compareTo(b.createdAt);
      });
    final border = pw.TableBorder.all(color: PdfColors.grey700, width: .5);
    String first(String key, String fallback) =>
        ordered.map((e) => e.text(key)).firstWhere((v) => v.isNotEmpty, orElse: () => fallback);
    String x(bool on) => on ? 'X' : '';

    pw.Widget cell(String t, {bool bold = false, PdfColor? color, double size = 7, pw.TextAlign align = pw.TextAlign.left}) => pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 2, vertical: 3),
          child: pw.Text(t, textAlign: align, style: pw.TextStyle(fontSize: size, color: color, fontWeight: bold ? pw.FontWeight.bold : null)),
        );
    pw.Widget head(String t) => pw.Container(
          color: _blue,
          alignment: pw.Alignment.center,
          padding: const pw.EdgeInsets.symmetric(horizontal: 1, vertical: 3),
          child: pw.Text(t, textAlign: pw.TextAlign.center, style: const pw.TextStyle(fontSize: 5.8, fontWeight: pw.FontWeight.bold)),
        );
    pw.Widget mark(String t) => cell(t, bold: true, align: pw.TextAlign.center);

    const headers = [
      'N°', 'N° DE\nFICHA', 'FECHA', 'TURNO', 'APELLIDOS Y NOMBRES', 'EDAD', 'SEXO', 'DIRECCIÓN (DISTRITO)',
      'PRIOR.\nI', 'PRIOR.\nII', 'PRIOR.\nIII', 'PRIOR.\nIV', 'FALLEC.\nEN FOCO', 'FALLEC.\nTRASLADO',
      'EMERG.\nMASIVA', 'SERV. PREV./\nESPECIAL (h)', 'RETENC.\nCAMILLA (h)', 'HERIDOS\nPOR CAÍDA', 'ACCID.\nTRÁNSITO',
      'DIAGNÓSTICO', 'MÉDICO DE LA ATENCIÓN',
    ];
    const widths = [1.0, 1.5, 1.7, 1.1, 4.2, 1.0, 1.0, 3.2, .9, .9, .9, .9, 1.2, 1.3, 1.2, 1.6, 1.4, 1.3, 1.3, 4.0, 3.2];
    final dmy = DateFormat('dd/MM/yy');

    pdf.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4.landscape,
      margin: const pw.EdgeInsets.all(20),
      build: (_) => [
        _title('REGISTRO DE ATENCIONES DIARIAS'),
        pw.Center(child: pw.Text('${s.samu} · Dirección Regional de Salud Moquegua · Red Integrada de Salud Ilo', style: const pw.TextStyle(fontSize: 8))),
        pw.SizedBox(height: 6),
        _headerRow([
          ['UNIDAD MÓVIL:', first('unidad', s.ambulance)],
          ['N° PLACA:', first('placa', s.plate)],
          ['MES Y AÑO:', '${monthNames[p.month - 1].toUpperCase()} ${p.year}'],
        ]),
        pw.Table(
          border: border,
          columnWidths: {for (var i = 0; i < widths.length; i++) i: pw.FlexColumnWidth(widths[i])},
          defaultVerticalAlignment: pw.TableCellVerticalAlignment.middle,
          children: [
            pw.TableRow(repeat: true, children: [for (final h in headers) head(h)]),
            for (var i = 0; i < ordered.length; i++)
              () {
                final e = ordered[i];
                final cancel = e.data['cancelado'] == true;
                final prio = e.text('prioridad');
                final death = e.text('fallecido');
                return pw.TableRow(children: [
                  mark('${i + 1}'),
                  cell(e.text('ficha')),
                  cell(dmy.format(e.date)),
                  mark(e.shift),
                  cell(e.text('paciente')),
                  mark(e.text('edad')),
                  mark(e.text('sexo')),
                  cell(e.text('direccion')),
                  for (final o in const ['I', 'II', 'III', 'IV']) mark(x(prio == o)),
                  mark(x(death == 'foco')),
                  mark(x(death == 'traslado')),
                  mark(x(e.data['emergenciaMasiva'] == true)),
                  mark(e.text('preventivoHoras')),
                  mark(e.text('retencionHoras')),
                  mark(x(e.data['caida'] == true)),
                  mark(x(e.data['transito'] == true)),
                  cancel
                      ? cell(['CANCELADO', e.text('diagnostico')].where((t) => t.isNotEmpty).join(' - '), bold: true, color: _red)
                      : cell(e.text('diagnostico')),
                  cell(e.text('medico')),
                ]);
              }(),
          ],
        ),
        pw.SizedBox(height: 8),
        pw.Text(
          'Atenciones del mes: ${ordered.length} · Canceladas: ${ordered.where((e) => e.data['cancelado'] == true).length} · '
          'Fallecidos: ${ordered.where((e) => e.text('fallecido').isNotEmpty).length} · '
          'Accidentes de tránsito: ${ordered.where((e) => e.data['transito'] == true).length}',
          style: const pw.TextStyle(fontSize: 8),
        ),
        _footer('ATE-${p.fileTag}'),
      ],
    ));
    return _save(pdf, 'ATENCIONES-${p.fileTag}');
  }

  // ---------- Formatos del médico descritos en spec_forms.dart ----------

  /// Texto de un campo tal como se imprime.
  static String specValue(SpecField f, Map<String, dynamic> data) {
    if (f.isComputed) return computeSum(f, data);
    final v = data[f.key];
    if (v is List) return v.join(', ');
    final t = (v ?? '').toString();
    return t.isEmpty || f.unit == null ? t : '$t ${f.unit}';
  }

  /// Opciones con marca, como en el formato impreso: «(X) Foco   ( ) Traslado».
  static String _marks(SpecField f, Map<String, dynamic> data) {
    final v = data[f.key];
    final chosen = v is List ? v.map((x) => x.toString()).toSet() : {(v ?? '').toString()};
    return f.options.keys.map((o) => '${chosen.contains(o) ? '(X)' : '(  )'} $o').join('   ');
  }

  List<pw.Widget> _specSection(SpecSection sec, Map<String, dynamic> data, {double size = 8}) {
    final border = pw.TableBorder.all(color: PdfColors.grey600, width: .5);
    pw.Widget labelled(SpecField f) {
      final marked = f.kind == SpecKind.choice || f.kind == SpecKind.flags;
      return pw.Padding(
        padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3),
        child: pw.RichText(text: pw.TextSpan(children: [
          pw.TextSpan(text: '${f.label.toUpperCase()}: ', style: pw.TextStyle(fontSize: size - .5, fontWeight: pw.FontWeight.bold)),
          pw.TextSpan(text: marked ? _marks(f, data) : specValue(f, data), style: pw.TextStyle(fontSize: size)),
        ])),
      );
    }

    final out = <pw.Widget>[_band(sec.title.toUpperCase())];
    final fields = sec.fields;
    for (var i = 0; i < fields.length; i++) {
      final f = fields[i];
      if (f.kind == SpecKind.rows) {
        final list = [for (final r in (data[f.key] as List?) ?? const []) Map<String, dynamic>.from(r as Map)];
        out.add(pw.Table(
          border: border,
          defaultVerticalAlignment: pw.TableCellVerticalAlignment.middle,
          columnWidths: {
            0: const pw.FixedColumnWidth(18),
            for (var c = 0; c < f.fields.length; c++)
              c + 1: pw.FlexColumnWidth(f.fields[c].kind == SpecKind.longText || f.fields[c].kind == SpecKind.text ? 3 : 1),
          },
          children: [
            _tableRow(['N°', for (final c in f.fields) c.label + (c.unit == null ? '' : ' (${c.unit})')], header: true, fontSize: size - 1),
            for (var r = 0; r < list.length; r++)
              _tableRow(['${r + 1}', for (final c in f.fields) (list[r][c.key] ?? '').toString()], fontSize: size - .5),
            if (list.isEmpty) _tableRow(['', for (final _ in f.fields) ''], fontSize: size),
          ],
        ));
        continue;
      }
      if (f.half && i + 1 < fields.length && fields[i + 1].half) {
        out.add(pw.Table(border: border, children: [pw.TableRow(children: [labelled(f), labelled(fields[i + 1])])]));
        i++;
      } else {
        out.add(pw.Table(border: border, children: [pw.TableRow(children: [labelled(f)])]));
      }
    }
    return out;
  }

  /// PDF de un registro (ficha APH, reporte médico diario).
  Future<File> specEntry(FormEntry e, BaseSettings s) async {
    final spec = specFor(e.type)!;
    final pdf = pw.Document();
    pdf.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(28),
      build: (_) => [
        _title(spec.pdfTitle),
        pw.Center(child: pw.Text('${s.samu} · Dirección Regional de Salud Moquegua · Red Integrada de Salud Ilo', style: const pw.TextStyle(fontSize: 8))),
        pw.SizedBox(height: 6),
        _headerRow([
          ['FECHA:', _dmy.format(e.date)],
          if (e.type.shifts.isNotEmpty) ['TURNO:', shiftNames[e.shift] ?? e.shift],
          ['REGISTRO:', e.id],
        ]),
        for (final sec in spec.sections) ..._specSection(sec, e.data),
        if (spec.signatures.isNotEmpty) ...[
          pw.SizedBox(height: 12),
          _signatures([for (final (role, key) in spec.signatures) (role, e.text(key))]),
        ],
        _footer(e.id),
      ],
    ));
    return _save(pdf, e.id);
  }

  /// Reporte del periodo con un bloque por registro (cuaderno del CRUE).
  Future<File> specReport(List<FormEntry> entries, Period p, BaseSettings s) async {
    final spec = specFor(entries.first.type)!;
    final ordered = [...entries]..sort((a, b) {
        final byDate = a.date.compareTo(b.date);
        return byDate != 0 ? byDate : a.createdAt.compareTo(b.createdAt);
      });
    final pdf = pw.Document();
    pdf.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(24),
      build: (_) => [
        _title(spec.pdfTitle),
        _headerRow([['SAMU:', s.samu], ['BASE:', s.base], ['MES/AÑO:', p.label], ['REGISTROS:', '${ordered.length}']]),
        for (var i = 0; i < ordered.length; i++) ...[
          pw.Container(
            width: double.infinity,
            margin: const pw.EdgeInsets.only(top: 10),
            padding: const pw.EdgeInsets.all(4),
            color: PdfColors.grey300,
            child: pw.Text('${i + 1}. ${_dmy.format(ordered[i].date)}  ·  ${ordered[i].text(spec.titleKey).isEmpty ? 'Sin nombre' : ordered[i].text(spec.titleKey)}',
                style: const pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
          ),
          for (final sec in spec.sections) ..._specSection(sec, ordered[i].data, size: 7.5),
        ],
        _footer('${spec.type.prefix}-${p.fileTag}'),
      ],
    ));
    return _save(pdf, '${spec.type.name.toUpperCase()}-${p.fileTag}');
  }

  // ---------- Bitácora de servicio (conductor) ----------

  Future<File> bitacora(FormEntry e, BaseSettings s) async {
    final pdf = pw.Document();
    final trips = [for (final t in (e.data['recorridos'] as List?) ?? const []) Map<String, dynamic>.from(t as Map)];
    final kmA = parseKm(e.text('kmInicio')), kmB = parseKm(e.text('kmFinal'));
    final border = pw.TableBorder.all(color: PdfColors.grey700, width: .5);
    pdf.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(28),
      build: (_) => [
        _title('BITÁCORA DE SERVICIO'),
        pw.Center(child: pw.Text('${s.samu} · Dirección Regional de Salud Moquegua · Red de Salud Ilo', style: const pw.TextStyle(fontSize: 8))),
        pw.SizedBox(height: 8),
        pw.Table(
          border: border,
          columnWidths: const {0: pw.FlexColumnWidth(1.2), 1: pw.FlexColumnWidth(.6), 2: pw.FlexColumnWidth(.6), 3: pw.FlexColumnWidth(.7), 4: pw.FlexColumnWidth(3)},
          children: [
            _tableRow(['BASE', 'DÍA', 'MES', 'AÑO', 'CONDUCTOR DE AMBULANCIA'], header: true),
            _tableRow([e.text('base'), '${e.date.day}', '${e.date.month}', '${e.date.year}', e.text('conductor')]),
          ],
        ),
        pw.Table(border: border, children: [
          _tableRow(['INICIO DE TURNO - HORA', 'KILOMETRAJE', 'FINAL DE TURNO - HORA', 'KILOMETRAJE', 'PLACA', 'TURNO'], header: true),
          _tableRow([e.text('horaInicio'), e.text('kmInicio'), e.text('horaFinal'), e.text('kmFinal'), e.text('placa'), shiftNames[e.shift] ?? e.shift]),
        ]),
        _band('RECORRIDO DE LA AMBULANCIA${kmA != null && kmB != null ? ' · TOTAL DEL TURNO: ${kmB - kmA} km' : ''}'),
        pw.Table(
          border: border,
          columnWidths: const {
            0: pw.FixedColumnWidth(22), 1: pw.FixedColumnWidth(44), 2: pw.FlexColumnWidth(3), 3: pw.FlexColumnWidth(2),
            4: pw.FixedColumnWidth(50), 5: pw.FixedColumnWidth(62), 6: pw.FixedColumnWidth(56),
          },
          children: [
            _tableRow(['N°', 'HORA DE SALIDA', 'DIRECCIÓN Y DISTRITO', 'I. NOSOCOMIO', 'HORA LLEGADA A BASE', 'KM LLEGADA A BASE', 'KM FINAL DE RECORRIDO'], header: true),
            for (var i = 0; i < trips.length; i++)
              _tableRow([
                '${i + 1}', '${trips[i]['horaSalida'] ?? ''}', '${trips[i]['direccion'] ?? ''}', '${trips[i]['nosocomio'] ?? ''}',
                '${trips[i]['horaLlegada'] ?? ''}', '${trips[i]['kmLlegada'] ?? ''}', '${trips[i]['kmRecorrido'] ?? ''}',
              ]),
            if (trips.isEmpty) _tableRow(['', '', 'Sin recorridos registrados', '', '', '', '']),
          ],
        ),
        if (e.text('observaciones').isNotEmpty) ...[
          _band('OBSERVACIONES'),
          pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(e.text('observaciones'), style: const pw.TextStyle(fontSize: 9))),
        ],
        pw.SizedBox(height: 14),
        _signatures([
          ('PILOTO RESPONSABLE DE TURNO', e.text('piloto')),
          ('ENFERMERA RESPONSABLE DE TURNO', e.text('enfermera')),
          ('MÉDICO RESPONSABLE DE TURNO', e.text('medico')),
        ]),
        _footer(e.id),
      ],
    ));
    return _save(pdf, e.id);
  }

  // ---------- Acta de conformidad mecánica ----------

  Future<File> acta(FormEntry e, BaseSettings s) async {
    final pdf = pw.Document();
    final items = e.map('items');
    final border = pw.TableBorder.all(color: PdfColors.grey700, width: .4);
    String fuel(String k) => e.data[k] == null ? '' : '${e.data[k]}/10';
    String? mark(String item) => items[item]?.toString();
    pw.Widget cell(String t, {bool bold = false, PdfColor? fill, bool center = false}) => pw.Container(
          color: fill,
          padding: const pw.EdgeInsets.symmetric(horizontal: 2, vertical: 1.5),
          alignment: center ? pw.Alignment.center : pw.Alignment.centerLeft,
          child: pw.Text(t, style: pw.TextStyle(fontSize: center ? 5.2 : 5.6, fontWeight: bold ? pw.FontWeight.bold : null)),
        );
    final columns = actaGroups.values.toList();
    final rowCount = columns.map((c) => c.length).reduce((a, b) => a > b ? a : b);
    final okFill = PdfColors.grey400, badFill = PdfColor.fromHex('#F4B6B6');
    pw.TableRow checkRow(int r) => pw.TableRow(children: [
          for (final col in columns)
            if (r < col.length) ...[
              cell(col[r], bold: actaIsProblem(col[r], mark(col[r]))),
              for (final o in actaOptions(col[r]))
                cell(o, center: true, bold: mark(col[r]) == o, fill: mark(col[r]) == o ? (o == actaOptions(col[r]).first ? okFill : badFill) : null),
            ] else
              for (var k = 0; k < 4; k++) pw.SizedBox(),
        ]);
    final problems = [for (final c in columns) ...c.where((i) => actaIsProblem(i, mark(i))).map((i) => '$i: ${mark(i)}')];
    pdf.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(20),
      build: (_) => [
        _title('ACTA DE CONFORMIDAD MECÁNICA DE LA UNIDAD VEHICULAR'),
        pw.Center(child: pw.Text('Para ser llenado y firmado por el personal al inicio de hacer el relevo de la unidad vehicular', style: const pw.TextStyle(fontSize: 7))),
        pw.SizedBox(height: 6),
        pw.Table(border: border, children: [
          _tableRow(['SAMU N°', e.text('samu'), 'ESTABLECIMIENTO', e.text('establecimiento'), 'PLACA N°', e.text('placa')]),
          _tableRow(['CÍA. BOMBEROS', e.text('ciaBomberos'), 'FECHA', _dmy.format(e.date), 'TURNO', shiftNames[e.shift] ?? e.shift]),
          _tableRow(['CONDUCTOR', e.text('conductor'), 'PROX. MANTENIMIENTO', e.text('proxMantenimiento'), 'TIPO COMBUSTIBLE', e.text('tipoCombustible')]),
        ]),
        pw.Table(border: border, children: [
          _tableRow(['', 'HORA', 'KILOMETRAJE', 'NIVEL COMBUSTIBLE'], header: true),
          _tableRow(['INICIO', e.text('horaInicio'), e.text('kmInicio'), fuel('combustibleInicio')]),
          _tableRow(['FINAL', e.text('horaFinal'), e.text('kmFinal'), fuel('combustibleFinal')]),
        ]),
        pw.SizedBox(height: 5),
        pw.Table(
          border: border,
          columnWidths: {
            for (var c = 0; c < 3; c++) ...{
              c * 4: const pw.FlexColumnWidth(4),
              c * 4 + 1: const pw.FixedColumnWidth(15),
              c * 4 + 2: const pw.FixedColumnWidth(15),
              c * 4 + 3: const pw.FixedColumnWidth(10),
            },
          },
          children: [for (var r = 0; r < rowCount; r++) checkRow(r)],
        ),
        pw.Text('$actaOptionHelp. Sombreado = opción marcada.', style: const pw.TextStyle(fontSize: 6, color: PdfColors.grey700)),
        _band('OBSERVACIONES (PROBLEMAS MECÁNICOS U OTRAS OCURRENCIAS)'),
        if (problems.isNotEmpty) pw.Text('Ítems observados: ${problems.join('; ')}', style: pw.TextStyle(fontSize: 7.5, color: _red)),
        pw.Padding(padding: const pw.EdgeInsets.symmetric(vertical: 4), child: pw.Text(e.text('observaciones'), style: const pw.TextStyle(fontSize: 8.5))),
        pw.SizedBox(height: 10),
        _signatures([
          ('PILOTO ENTRANTE', e.text('pilotoEntrante')),
          ('PILOTO SALIENTE', e.text('pilotoSaliente')),
          ('MÉDICO ENTRANTE', e.text('medicoEntrante')),
        ], label: 'FIRMA'),
        _footer(e.id),
      ],
    ));
    return _save(pdf, e.id);
  }

  // ---------- Registro de horas de la emergencia ----------

  Future<File> horas(FormEntry e, BaseSettings s) async {
    final pdf = pw.Document();
    final rows = [for (final r in (e.data['emergencias'] as List?) ?? const []) Map<String, dynamic>.from(r as Map)];
    final border = pw.TableBorder.all(color: PdfColors.grey700, width: .4);
    String fuel(String k) => e.data[k] == null ? '-' : '${e.data[k]}/10';
    String v(Map<String, dynamic> r, String k) => (r[k] ?? '').toString();
    final kmA = parseKm(e.text('kmInicio')), kmB = parseKm(e.text('kmFinal'));
    pdf.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4.landscape,
      margin: const pw.EdgeInsets.all(22),
      build: (_) => [
        _title('REGISTRO DE HORAS DE LA EMERGENCIA'),
        pw.Table(border: border, children: [
          _tableRow(['PILOTO', e.text('piloto'), 'FECHA', _dmy.format(e.date), 'KM INICIO', e.text('kmInicio'), 'COMBUSTIBLE INICIO', fuel('combustibleInicio')]),
          _tableRow(['MÉDICO', e.text('medico'), 'BASE', e.text('base'), 'KM FINAL', e.text('kmFinal'), 'COMBUSTIBLE FINAL', fuel('combustibleFinal')]),
          _tableRow(['LICENC.', e.text('licenciado'), 'SAMU', e.text('samu'), 'TURNO', shiftNames[e.shift] ?? e.shift, 'RECORRIDO',
              kmA == null || kmB == null ? '' : '${kmB - kmA} km']),
        ]),
        pw.SizedBox(height: 6),
        pw.Table(
          border: border,
          columnWidths: const {0: pw.FixedColumnWidth(16), 3: pw.FlexColumnWidth(1.4), 7: pw.FlexColumnWidth(1.6), 13: pw.FlexColumnWidth(2.2)},
          defaultColumnWidth: const pw.FlexColumnWidth(),
          children: [
            _tableRow(['N°', 'Salida', 'Distrito', 'Foco: dirección', 'Foco llegada', 'Foco km', 'Foco salida', 'Hospital / clínica', 'Hosp. llegada',
                'Hosp. km', 'Hosp. salida', 'Base llegada', 'Base km', 'Motivo de llamada', 'Servicio'], header: true, fontSize: 7),
            for (var i = 0; i < rows.length; i++)
              _tableRow([
                '${i + 1}', '${v(rows[i], 'salida')}${rows[i]['empalme'] == true ? ' (E)' : ''}', v(rows[i], 'distrito'), v(rows[i], 'direccion'),
                v(rows[i], 'focoLlegada'), v(rows[i], 'focoKm'), v(rows[i], 'focoSalida'), v(rows[i], 'hospital'), v(rows[i], 'hospLlegada'),
                v(rows[i], 'hospKm'), v(rows[i], 'hospSalida'), v(rows[i], 'baseLlegada'), v(rows[i], 'baseKm'), v(rows[i], 'motivo'), v(rows[i], 'servicio'),
              ], fontSize: 7),
            if (rows.isEmpty) _tableRow(['', '', '', 'Sin emergencias registradas', '', '', '', '', '', '', '', '', '', '', ''], fontSize: 7),
          ],
        ),
        pw.SizedBox(height: 6),
        pw.Text(
            'Servicio: ${serviceOutcomes.entries.map((o) => '${o.key} = ${o.value}').join(' · ')}.  '
            '(E) = empalme: la hora de llegada del empalme se considera nueva hora de salida.',
            style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey700)),
        _footer(e.id),
      ],
    ));
    return _save(pdf, e.id);
  }

  pw.Widget _signatures(List<(String, String)> people, {String label = 'FIRMA Y SELLO'}) => pw.Table(
        border: pw.TableBorder.all(color: PdfColors.grey700, width: .5),
        children: [
          _tableRow([for (final p in people) p.$1], header: true),
          pw.TableRow(children: [
            for (final _ in people)
              pw.Container(
                height: 48,
                alignment: pw.Alignment.bottomCenter,
                padding: const pw.EdgeInsets.all(3),
                child: pw.Text(label, style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey700)),
              ),
          ]),
          _tableRow([for (final p in people) p.$2.isEmpty ? 'Nombres y apellidos:' : p.$2]),
        ],
      );

  // ---------- Utilidades ----------

  /// Cuadrícula día × turno como en las hojas quincenales. Devuelve filas sueltas para que MultiPage pueda paginar.
  List<pw.Widget> _grid({
    required String firstHeader,
    required List<int> days,
    required List<String> shifts,
    required List<_GridRow> rows,
    double labelWidth = 165,
    bool showTotal = true,
    String totalHeader = 'TOTAL',
  }) {
    const pageWidth = 842 - 44.0;
    final totalWidth = showTotal ? 44.0 : 0.0;
    final cellW = (pageWidth - labelWidth - totalWidth) / (days.length * shifts.length);
    pw.Widget cell(String t, double w, {double h = 15, bool bold = false, PdfColor? fill, bool left = false, PdfColor? color}) => pw.Container(
          width: w,
          height: h,
          alignment: left ? pw.Alignment.centerLeft : pw.Alignment.center,
          padding: pw.EdgeInsets.symmetric(horizontal: left ? 3 : 0),
          decoration: pw.BoxDecoration(color: fill, border: pw.Border.all(color: PdfColors.grey600, width: .3)),
          child: pw.Text(t, maxLines: 2, style: pw.TextStyle(fontSize: left ? 6.3 : 6.5, fontWeight: bold ? pw.FontWeight.bold : null, color: color)),
        );
    return [
      pw.Row(children: [
        cell(firstHeader, labelWidth, h: 14, bold: true, fill: _blue),
        for (final d in days) cell('$d', cellW * shifts.length, h: 14, bold: true, fill: _blue),
        if (showTotal) cell(totalHeader, totalWidth, h: 14, bold: true, fill: _blue),
      ]),
      pw.Row(children: [
        cell('', labelWidth, h: 11, fill: _blue),
        for (final _ in days) for (final s in shifts) cell(s, cellW, h: 11, bold: true, fill: _blue),
        if (showTotal) cell('', totalWidth, h: 11, fill: _blue),
      ]),
      for (final r in rows)
        pw.Row(children: [
          cell(r.label, labelWidth, h: 17, bold: r.bold, left: true, fill: r.bold ? PdfColors.grey200 : null),
          for (final d in days)
            for (final s in shifts)
              cell(r.cells['$d|$s'] ?? '', cellW, h: 17, bold: r.bold, color: r.cells['$d|$s'] == 'F' ? _red : null),
          if (showTotal) cell(r.total, totalWidth, h: 17, bold: true, fill: PdfColors.grey100),
        ]),
    ];
  }

  pw.Widget _title(String t) => pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 6),
        child: pw.Center(child: pw.Text(t, textAlign: pw.TextAlign.center, style: const pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold))),
      );

  pw.Widget _headerRow(List<List<String>> pairs) => pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 6),
        child: pw.Row(children: [
          for (final p in pairs)
            pw.Expanded(
              child: pw.RichText(text: pw.TextSpan(children: [
                pw.TextSpan(text: '${p[0]} ', style: const pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                pw.TextSpan(text: p[1].isEmpty ? '________________' : p[1], style: const pw.TextStyle(fontSize: 9)),
              ])),
            ),
        ]),
      );

  pw.Widget _band(String t) => pw.Container(
        width: double.infinity,
        margin: const pw.EdgeInsets.only(top: 6),
        padding: const pw.EdgeInsets.all(5),
        color: _blue,
        child: pw.Text(t, style: const pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold)),
      );

  pw.TableRow _tableRow(List<String> cells, {bool header = false, double fontSize = 8}) => pw.TableRow(
        decoration: header ? pw.BoxDecoration(color: _blue) : null,
        children: [
          for (final c in cells)
            pw.Padding(
              padding: const pw.EdgeInsets.all(3),
              child: pw.Text(c, style: pw.TextStyle(fontSize: header ? fontSize - .5 : fontSize, fontWeight: header ? pw.FontWeight.bold : null)),
            ),
        ],
      );

  pw.Widget _footer(String id) => pw.Padding(
        padding: const pw.EdgeInsets.only(top: 14),
        child: pw.Text('Documento $id generado por BuVoza el ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}.',
            style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey700)),
      );

  static double? _num(Object? v) => v == null ? null : double.tryParse(v.toString().replaceAll(',', '.'));
  static String _fmt(double v) => v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);

  Future<File> _save(pw.Document pdf, String name) async {
    final dir = await _baseDir();
    final reportsDir = Directory('${dir.path}/BuVoza/informes');
    if (!await reportsDir.exists()) await reportsDir.create(recursive: true);
    final file = File('${reportsDir.path}/$name.pdf');
    await file.writeAsBytes(await pdf.save(), flush: true);
    return file;
  }
}

class _GridRow {
  _GridRow(this.label, this.cells, {this.total = '', this.bold = false});
  final String label;
  final Map<String, String> cells; // 'día|turno' -> valor
  final String total;
  final bool bold;
}
