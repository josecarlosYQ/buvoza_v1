import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:buvoza_v1/models/form_entry.dart';
import 'package:buvoza_v1/screens/acta_screen.dart';
import 'package:buvoza_v1/screens/almacen_screen.dart';
import 'package:buvoza_v1/screens/atenciones_screen.dart';
import 'package:buvoza_v1/screens/bitacora_screen.dart';
import 'package:buvoza_v1/screens/form_base.dart';
import 'package:buvoza_v1/screens/horas_screen.dart';
import 'package:buvoza_v1/screens/oxigeno_screen.dart';
import 'package:buvoza_v1/screens/procedimientos_screen.dart';
import 'package:buvoza_v1/screens/soapie_screen.dart';
import 'package:buvoza_v1/screens/spec_form_screen.dart';
import 'package:buvoza_v1/models/spec_forms.dart';
import 'package:buvoza_v1/screens/turno_screen.dart';

/// Llena cada formulario con frases como las que entrega el reconocedor de voz
/// y comprueba lo que queda guardado en el registro.
void main() {
  late Directory tmp;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('buvoza_voz');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (call) async => tmp.path,
    );
  });
  tearDown(() => tmp.deleteSync(recursive: true));

  /// Abre la pantalla, espera a que carguen los ajustes y dicta [phrases].
  Future<FormEntry> dictate(WidgetTester tester, Widget screen, List<String> phrases) async {
    tester.view.physicalSize = const Size(1080, 2400);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(home: screen));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
    await tester.pump();
    final state = tester.state(find.byType(screen.runtimeType)) as FormScreenState;
    for (final p in phrases) {
      state.applyVoicePhrase(p);
      await tester.pump();
    }
    expect(state.lastVoice!.failed, isEmpty, reason: 'campos no entendidos en «${state.lastPhrase}»');
    state.collect();
    return state.entry;
  }

  testWidgets('SOAPIE completo por voz', (tester) async {
    final e = await dictate(tester, const SoapieScreen(), [
      'turno tarde paciente María Quispe Mamani edad 67 DNI 45678912 sexo femenino seguro SIS diagnóstico síndrome coronario agudo',
      'saturación 89 frecuencia cardiaca 112 temperatura 36.8 presión arterial 150 sobre 90 frecuencia respiratoria 22 glucosa 180',
      'subjetivo paciente refiere dolor en el pecho desde hace dos horas objetivo paciente diaforética con presión 150 sobre 90',
      'análisis dolor agudo intervención se administra oxígeno por cánula evaluación paciente estable',
    ]);
    expect(e.shift, 'T');
    expect(e.text('paciente'), 'María Quispe Mamani');
    expect(e.text('edad'), '67');
    expect(e.text('dni'), '45678912');
    expect(e.data['sexo'], 'F');
    expect(e.data['seguro'], 'SIS');
    expect(e.text('dx'), 'Síndrome coronario agudo');
    expect(e.map('vitals'), {'spo2': '89', 'fc': '112', 'temp': '36.8', 'pa': '150/90', 'fr': '22', 'hgt': '180'});
    expect(e.text('S'), 'Paciente refiere dolor en el pecho desde hace dos horas');
    expect(e.text('O'), 'Paciente diaforética con presión 150 sobre 90');
    expect(e.text('A'), 'Dolor agudo');
    expect(e.text('I'), 'Se administra oxígeno por cánula');
    expect(e.text('E'), 'Paciente estable');
  });

  testWidgets('Bitácora con dos recorridos por voz', (tester) async {
    final e = await dictate(tester, const BitacoraScreen(), [
      'turno noche base Ilo placa eab 123 conductor Juan Quispe hora inicio 7 de la noche km inicio 120350',
      'nuevo recorrido salida 20:15 dirección Pampa Inalámbrica módulo 3 hospital Hospital de Ilo llegada 21:00 km llegada 120362',
      'nuevo recorrido salida diez y media de la noche dirección Puerto Ilo km llegada 120380 km final 120380 hora final 7 de la mañana',
    ]);
    expect(e.shift, 'N');
    expect(e.text('placa'), 'EAB 123');
    expect(e.text('conductor'), 'Juan Quispe');
    expect(e.text('horaInicio'), '19:00');
    expect(e.text('kmInicio'), '120350');
    expect(e.text('kmFinal'), '120380');
    expect(e.text('horaFinal'), '07:00');
    final trips = (e.data['recorridos'] as List).cast<Map>();
    expect(trips.length, 2);
    expect(trips[0]['horaSalida'], '20:15');
    expect(trips[0]['direccion'], 'Pampa Inalámbrica módulo 3');
    expect(trips[0]['nosocomio'], 'Hospital de Ilo');
    expect(trips[0]['kmRecorrido'], '12');
    expect(trips[1]['horaSalida'], '22:30');
    expect(trips[1]['kmRecorrido'], '18');
  });

  testWidgets('Acta mecánica por voz', (tester) async {
    final e = await dictate(tester, const ActaScreen(), [
      'placa EAB 123 km inicio 120350 combustible inicio tres cuartos tipo de combustible diésel',
      'sirena inoperativa faro neblinero izquierdo malogrado escoba falta agua de batería bajo nivel',
      'todo lo demás conforme observaciones sirena no suena y falta escoba',
    ]);
    final items = e.map('items');
    expect(items.length, 120);
    expect(items['SIRENA'], 'INOP');
    expect(items['FARO NEBLINERO IZQUIERDO'], 'INOP');
    expect(items['ESCOBA'], 'F');
    expect(items['AGUA DE BATERÍA'], 'NO');
    expect(items['LUZ ALTA'], 'OPE');
    expect(e.data['combustibleInicio'], 8);
    expect(e.data['tipoCombustible'], 'Diésel');
    expect(e.text('observaciones'), 'Sirena no suena y falta escoba');
  });

  testWidgets('Registro de horas con empalme por voz', (tester) async {
    final e = await dictate(tester, const HorasScreen(), [
      'piloto Juan Quispe km inicio 120000 combustible inicio lleno',
      'nueva emergencia salida 10:05 distrito Ilo dirección calle Moquegua 120 llegada al foco 10:15 km foco 120005 salida del foco 10:40',
      'hospital Hospital de Ilo llegada al hospital 10:55 km hospital 120012 salida del hospital 11:20 motivo accidente vehicular servicio retenido',
      'empalme llegada al foco 11:30 km foco 120015 servicio frustro llegada a base 12:00 km base 120020',
    ]);
    expect(e.text('piloto'), 'Juan Quispe');
    expect(e.data['combustibleInicio'], 10);
    final rows = (e.data['emergencias'] as List).cast<Map>();
    expect(rows.length, 2);
    expect(rows[0]['salida'], '10:05');
    expect(rows[0]['direccion'], 'Calle Moquegua 120');
    expect(rows[0]['focoKm'], '120005');
    expect(rows[0]['hospital'], 'Hospital de Ilo');
    expect(rows[0]['hospSalida'], '11:20');
    expect(rows[0]['motivo'], 'Accidente vehicular');
    expect(rows[0]['servicio'], 'R');
    expect(rows[1]['empalme'], isTrue);
    expect(rows[1]['salida'], '11:20', reason: 'el empalme toma la última salida');
    expect(rows[1]['servicio'], 'FR');
    expect(rows[1]['baseKm'], '120020');
  });

  testWidgets('Entrega de turno por voz', (tester) async {
    final e = await dictate(tester, const TurnoScreen(), [
      'turno mañana licenciada Rosa Pérez ambulancia AMB 01',
      'medicamentos falta adrenalina y atropina limpieza conforme balón de oxígeno sin novedad',
      'pendientes reponer guantes talla M',
    ]);
    expect(e.shift, 'M');
    expect(e.text('licenciada'), 'Rosa Pérez');
    final areas = e.map('areas');
    expect(areas['MEDICAMENTOS'], {'ok': false, 'falta': 'Adrenalina y atropina'});
    expect((areas['LIMPIEZA'] as Map)['ok'], isTrue);
    expect((areas['BALÓN DE OXÍGENO'] as Map)['ok'], isTrue);
    expect(e.text('pendientes'), 'Reponer guantes talla M');
  });

  testWidgets('Procedimientos por voz', (tester) async {
    final e = await dictate(tester, const ProcedimientosScreen(), [
      'nebulización 2 toma de glicemia medicamento endovenoso 3 collarín',
      'nebulización quitar toma de glicemia',
    ]);
    expect(e.map('counts'), {
      'Nebulización': 3,
      'Administración de medicamento vía EV': 3,
      'Colocación de collarín': 1,
    });
  });

  testWidgets('Oxígeno por voz', (tester) async {
    final e = await dictate(tester, const OxigenoScreen(), [
      'balón de 7 metros cúbicos consumo 200 trasegado 0 stock 1800 balón 1 consumo cincuenta',
    ]);
    expect(e.map('balones'), {
      'Balón 7 m³': {'consumo': 200.0, 'trasegado': 0.0, 'stock': 1800.0},
      'Balón 1 m³': {'consumo': 50.0},
    });
  });

  testWidgets('Almacén por voz', (tester) async {
    final e = await dictate(tester, const AlmacenScreen(), [
      'hora de ingreso 8 de la mañana temperatura de ingreso 22.5 confort de ingreso normal',
      'hora de salida 7 de la noche temperatura de salida 26 confort de salida húmedo responsable Rosa Pérez',
    ]);
    expect(e.text('horaIngreso'), '08:00');
    expect(e.text('tempIngreso'), '22.5');
    expect(e.data['confortIngreso'], 'Confort');
    expect(e.text('horaSalida'), '19:00');
    expect(e.data['confortSalida'], 'Húmedo');
    expect(e.text('responsable'), 'Rosa Pérez');
  });

  testWidgets('Atenciones diarias por voz', (tester) async {
    final e = await dictate(tester, const AtencionesScreen(), [
      'turno noche ficha 963 paciente Karina Merma Quispe edad 43 sexo femenino dirección Nuevo Ilo',
      'prioridad dos accidente de tránsito retención de camilla 1.5 diagnóstico crisis de ansiedad médico Mirian Núñez',
    ]);
    expect(e.shift, 'N');
    expect(e.text('ficha'), '963');
    expect(e.text('paciente'), 'Karina Merma Quispe');
    expect(e.text('edad'), '43');
    expect(e.data['sexo'], 'F');
    expect(e.text('direccion'), 'Nuevo Ilo');
    expect(e.data['prioridad'], 'II');
    expect(e.data['transito'], isTrue);
    expect(e.data['caida'], isFalse);
    expect(e.text('retencionHoras'), '1.5');
    expect(e.text('diagnostico'), 'Crisis de ansiedad');
    expect(e.text('medico'), 'Mirian Núñez');
  });

  testWidgets('Ficha de atención prehospitalaria por voz', (tester) async {
    final e = await dictate(tester, const SpecFormScreen(spec: fichaAphSpec), [
      'número de ficha 1024 hora de despacho 7 46 llegada a foco 7 57 prioridad dos atención traslado',
      'paciente Rosa Huaricapa Flores edad 52 sexo femenino dni 45678912 distrito Ilo seguro SIS',
      'presión arterial 150 sobre 90 frecuencia cardiaca 110 saturación 91 apertura ocular 4 respuesta verbal 5 respuesta motora 6',
      'presión arterial 130 sobre 80 frecuencia cardiaca 92',
      'tipo de vehículo mototaxi cinemática impacto frontal procedimientos oxigenoterapia y inmovilización completa',
      'medicamento metamizol dosis 1 gramo vía endovenosa hora del medicamento 8 10',
      'diagnóstico uno policontuso cie uno T07 establecimiento hospital de Ilo camilla retenida sí',
    ]);
    expect(e.text('numero'), '1024');
    expect(e.text('horaDespacho'), '07:46');
    expect(e.data['prioridad'], 'II');
    expect(e.data['atencion'], 'Traslado');
    expect(e.text('paciente'), 'Rosa Huaricapa Flores');
    expect(e.data['sexo'], 'F');
    expect(e.data['seguro'], 'SIS');
    final evals = e.data['evaluaciones'] as List;
    expect(evals.length, 2, reason: 'la segunda presión abre otra evaluación');
    expect(evals[0]['pa'], '150/90');
    expect(evals[0]['gt'], '15');
    expect(evals[1]['fc'], '92');
    expect(e.data['tipoVehiculo'], ['Mototaxi']);
    expect(e.data['cinematica'], ['Impacto frontal']);
    expect(e.data['procedimientos'], containsAll(['Oxigenoterapia', 'Inmovilización completa']));
    final meds = e.data['medicacion'] as List;
    expect(meds.single['medicamento'], 'Metamizol');
    expect(meds.single['via'], 'EV');
    expect(meds.single['hora'], '08:10');
    expect(e.text('dx1'), 'Policontuso');
    expect(e.data['camillaRetenida'], 'Sí');
  });

  testWidgets('CRUE por voz', (tester) async {
    final e = await dictate(tester, const SpecFormScreen(spec: crueSpec), [
      'número crue 0973 hora de la llamada 7 46 paciente Juan Pérez edad 40 tipo de atención traslado trasladado a minsa distrito el algarrobal',
      'sector Mercado de Abastos accidente de tránsito sí prioridad uno seguro soat sintomatología dolor abdominal',
      'deriva médico 7 46 indica ambulancia 7 49 salida ambulancia 7 50 llegada a foco 7 57 llegada a base 9 13',
    ]);
    expect(e.text('nroCrue'), '0973');
    expect(e.text('horaLlamada'), '07:46');
    expect(e.data['tipoAtencion'], 'Traslado');
    expect(e.data['trasladoA'], 'MINSA');
    expect(e.data['distrito'], 'El Algarrobal');
    expect(e.data['transito'], 'Sí');
    expect(e.data['prioridad'], 'I');
    expect(e.data['seguro'], 'Otros');
    expect(e.text('horaIndica'), '07:49');
    expect(e.text('horaLlegadaBase'), '09:13');
  });

  testWidgets('Reporte médico diario por voz', (tester) async {
    final e = await dictate(tester, const SpecFormScreen(spec: reporteMedicoSpec), [
      'turno día placa EUC 935 equipo 1 médico Mirian Núñez',
      'hora de ocurrencia 7 45 ocurrencia se acude a vía pública de El Algarrobal se traslada a hospital minsa',
      'hora de ocurrencia 9 30 ocurrencia se acude a Vista Alegre atención frustra',
      'efectivas 1 frustras 1 pendientes recoger férula y collarín adulto',
    ]);
    expect(e.shift, 'D');
    expect(e.text('medico'), 'Mirian Núñez');
    final occ = e.data['ocurrencias'] as List;
    expect(occ.length, 2);
    expect(occ[0]['hora'], '07:45');
    expect(occ[0]['detalle'], startsWith('Se acude a vía pública'));
    expect(occ[1]['hora'], '09:30');
    expect(e.text('total'), '2');
  });
}
