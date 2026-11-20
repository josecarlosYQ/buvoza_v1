import 'package:flutter_test/flutter_test.dart';

import 'package:buvoza_v1/main.dart';
import 'package:buvoza_v1/models/catalogs.dart';
import 'package:buvoza_v1/models/driver_catalogs.dart';
import 'package:buvoza_v1/models/form_entry.dart';

void main() {
  testWidgets('La pantalla inicial muestra los tres roles habilitados', (tester) async {
    await tester.pumpWidget(const BuVozaApp());
    expect(find.text('Conductor'), findsOneWidget);
    expect(find.text('Médico'), findsOneWidget);
    expect(find.text('Enfermería'), findsOneWidget);
  });

  test('Las quincenas cubren el mes completo', () {
    expect(const Period(2026, 2, 1).days.length, 15);
    expect(const Period(2026, 2, 2).days, [for (var d = 16; d <= 28; d++) d]);
    expect(const Period(2026, 10, 0).days.length, 31);
  });

  test('FormEntry se serializa y recupera sin pérdidas', () {
    final e = FormEntry(type: FormType.procedimientos, shift: 'N', data: {'counts': {'Nebulización': 2}});
    final back = FormEntry.fromJson(e.toJson());
    expect(back.id, e.id);
    expect(back.type, FormType.procedimientos);
    expect(back.map('counts')['Nebulización'], 2);
  });

  test('Alertas de funciones vitales y temperatura de almacén', () {
    final spo2 = vitalSigns.firstWhere((v) => v.key == 'spo2');
    final pa = vitalSigns.firstWhere((v) => v.key == 'pa');
    expect(spo2.warning('85'), isNotNull);
    expect(spo2.warning('98'), isNull);
    expect(pa.warning('190/100'), isNotNull);
    expect(storageTempWarning('22'), isNull);
    expect(storageTempWarning('31'), contains('Crítico'));
  });

  test('Conversión de PSI a litros', () {
    const balon = OxygenCylinder('Balón 7 m³', 7000, 2000);
    expect(balon.litersFor(200), 700);
  });

  test('Formatos del conductor: acta mecánica y kilometraje', () {
    final all = [for (final g in actaGroups.values) ...g];
    expect(all.length, 120);
    expect(all.toSet().length, 120, reason: 'sin ítems duplicados');
    expect(actaOptions('SIRENA'), ['OPE', 'INOP', 'F']);
    expect(actaOptions('AGUA DE BATERÍA'), ['SI', 'NO', 'F']);
    expect(actaIsProblem('SIRENA', 'OPE'), isFalse);
    expect(actaIsProblem('SIRENA', 'INOP'), isTrue);
    expect(parseKm('120 350 km'), 120350);
    expect(FormType.values.where((t) => t.roles.contains(ClinicalRole.conductor)),
        [FormType.bitacora, FormType.actaMecanica, FormType.horasEmergencia]);
  });
}
