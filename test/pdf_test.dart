import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

import 'package:buvoza_v1/models/catalogs.dart';
import 'package:buvoza_v1/models/driver_catalogs.dart';
import 'package:buvoza_v1/models/form_entry.dart';
import 'package:buvoza_v1/services/clinical_pdf_service.dart';

/// Genera cada PDF con datos de ejemplo para detectar errores de maquetación.
void main() {
  late Directory tmp;
  late ClinicalPdfService pdf;
  final s = BaseSettings(base: 'Base Ilo', district: 'Ilo', ambulance: 'AMB-01', plate: 'EAB-123', nurse: 'Lic. Pérez', doctor: 'Dr. Díaz', pilot: 'Juan Quispe');
  final day = DateTime(2026, 10, 5);
  const period = Period(2026, 10, 1);
  final longText = List.filled(40, 'Paciente refiere dolor torácico opresivo de inicio súbito.').join(' ');

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('buvoza_pdf');
    pdf = ClinicalPdfService(baseDir: () async => tmp);
  });
  tearDown(() => tmp.deleteSync(recursive: true));

  Future<void> expectPdf(Future<File> Function() build) async {
    final f = await build();
    expect(f.existsSync(), isTrue);
    expect(f.lengthSync(), greaterThan(1000));
    expect(String.fromCharCodes(f.readAsBytesSync().take(5)), '%PDF-');
  }

  test('SOAPIE con texto largo y vitales fuera de rango', () => expectPdf(() => pdf.soapie(
        FormEntry(type: FormType.soapie, date: day, shift: 'M', data: {
          'paciente': 'María Ñahui', 'edad': '67', 'dni': '12345678', 'sexo': 'F', 'seguro': 'SIS', 'dx': 'SCA',
          'vitals': {'spo2': '85', 'fc': '120', 'temp': '36.5', 'pa': '190/100', 'fr': '24', 'hgt': '110'},
          for (final k in soapieSections.keys) k: longText,
        }),
        s,
      )));

  test('Entrega de turno quincenal', () => expectPdf(() => pdf.turno([
        for (var d = 1; d <= 15; d++)
          for (final sh in FormType.turno.shifts)
            FormEntry(type: FormType.turno, date: DateTime(2026, 10, d), shift: sh, data: {
              'licenciada': 'Lic. $d$sh',
              'areas': {for (final a in turnoAreas.keys) a: {'ok': a != 'LIMPIEZA' || d != 3, 'falta': 'Falta escoba'}},
              'pendientes': d == 4 ? 'Reponer guantes' : '',
            }),
      ], period, s)));

  test('Procedimientos quincenal', () => expectPdf(() => pdf.procedimientos([
        for (var d = 1; d <= 15; d++)
          FormEntry(type: FormType.procedimientos, date: DateTime(2026, 10, d), shift: d.isEven ? 'D' : 'N', data: {
            'counts': {for (final g in procedureGroups.values) for (final p in g) p: d % 3},
          }),
      ], period, s)));

  test('Oxígeno quincenal', () => expectPdf(() => pdf.oxigeno([
        FormEntry(type: FormType.oxigeno, date: day, shift: 'D', data: {
          'licenciado': 'Lic. Pérez',
          'balones': {'Balón 7 m³': {'consumo': 200, 'trasegado': 0, 'stock': 1800}, 'Balón extra': {'consumo': 50}},
        }),
      ], period, s)));

  test('Almacén mensual', () => expectPdf(() => pdf.almacen([
        for (var d = 1; d <= 31; d++)
          FormEntry(type: FormType.almacen, date: DateTime(2026, 10, d), data: {
            'horaIngreso': '08:00', 'tempIngreso': '${18 + d % 15}', 'confortIngreso': 'Confort',
            'horaSalida': '19:00', 'tempSalida': '24', 'confortSalida': 'Seco',
          }),
      ], const Period(2026, 10, 0), s)));

  test('Bitácora de servicio', () => expectPdf(() => pdf.bitacora(
        FormEntry(type: FormType.bitacora, date: day, shift: 'D', data: {
          'base': 'Ilo', 'conductor': 'Juan Quispe', 'placa': 'EAB-123', 'horaInicio': '07:00', 'kmInicio': '120000', 'kmFinal': '120180',
          'recorridos': [
            for (var i = 0; i < 12; i++)
              {'horaSalida': '08:0$i', 'direccion': 'Av. Venecia $i, Pampa Inalámbrica', 'nosocomio': 'Hospital Ilo', 'horaLlegada': '09:00', 'kmLlegada': '${120010 + i * 10}', 'kmRecorrido': '10'},
          ],
          'piloto': 'Juan Quispe', 'enfermera': 'Lic. Pérez', 'medico': 'Dr. Díaz',
        }),
        s,
      )));

  test('Acta mecánica completa con observaciones', () => expectPdf(() => pdf.acta(
        FormEntry(type: FormType.actaMecanica, date: day, shift: 'N', data: {
          'items': {
            for (final g in actaGroups.values)
              for (final i in g) i: i == 'SIRENA' ? 'INOP' : (i == 'ESCOBA' ? 'F' : actaOptions(i).first),
          },
          'combustibleInicio': 8, 'combustibleFinal': 5, 'observaciones': 'Sirena inoperativa, falta escoba.',
          'pilotoEntrante': 'Juan Quispe', 'medicoEntrante': 'Dr. Díaz',
        }),
        s,
      )));

  test('Registro de horas de la emergencia', () => expectPdf(() => pdf.horas(
        FormEntry(type: FormType.horasEmergencia, date: day, shift: 'D', data: {
          'piloto': 'Juan Quispe', 'kmInicio': '120000', 'kmFinal': '120090', 'combustibleInicio': 9,
          'emergencias': [
            for (var i = 0; i < 10; i++)
              {
                'salida': '10:0$i', 'distrito': 'Ilo', 'direccion': 'Calle $i', 'focoLlegada': '10:15', 'focoKm': '${120005 + i}',
                'focoSalida': '10:40', 'hospital': 'Hospital Ilo', 'hospLlegada': '10:55', 'hospKm': '${120012 + i}', 'hospSalida': '11:20',
                'baseLlegada': '11:35', 'baseKm': '${120020 + i}', 'motivo': 'Accidente vehicular', 'servicio': serviceOutcomes.keys.elementAt(i % 4), 'empalme': i == 2,
              },
          ],
        }),
        s,
      )));
}
