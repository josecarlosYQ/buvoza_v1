import 'package:flutter_test/flutter_test.dart';

import 'package:buvoza_v1/models/catalogs.dart';
import 'package:buvoza_v1/models/driver_catalogs.dart';
import 'package:buvoza_v1/services/voice_form_parser.dart';

void main() {
  group('Números hablados', () {
    test('cifras y palabras', () {
      expect(spokenNumber('120350'), 120350);
      expect(spokenNumber('120.350 km'), 120350);
      expect(spokenNumber('120 350'), 120350);
      expect(spokenNumber('ciento veinte mil trescientos cincuenta'), 120350);
      expect(spokenNumber('120 mil 350'), 120350);
      expect(spokenNumber('treinta y seis punto cinco'), 36.5);
      expect(spokenNumber('36,5 grados'), 36.5);
      expect(spokenNumber('mil ochocientos psi'), 1800);
      expect(spokenNumber('noventa y cinco por ciento'), 95);
      expect(spokenNumber('menos dos'), -2);
      expect(spokenNumber('nada'), isNull);
    });

    test('presión arterial', () {
      expect(spokenPressure('120 sobre 80'), '120/80');
      expect(spokenPressure('ciento veinte sobre ochenta'), '120/80');
      expect(spokenPressure('120/80'), '120/80');
      expect(spokenPressure('90 60'), '90/60');
    });

    test('combustible', () {
      expect(spokenFuelLevel('tanque lleno'), 10);
      expect(spokenFuelLevel('medio tanque'), 5);
      expect(spokenFuelLevel('tres cuartos'), 8);
      expect(spokenFuelLevel('ocho'), 8);
      expect(spokenFuelLevel('80 por ciento'), 8);
    });
  });

  group('Horas habladas', () {
    DateTime now() => DateTime(2026, 10, 22, 14, 7);
    test('formatos comunes', () {
      expect(spokenTime('10:15'), '10:15');
      expect(spokenTime('10 y 15'), '10:15');
      expect(spokenTime('diez y cuarto'), '10:15');
      expect(spokenTime('las ocho y media de la noche'), '20:30');
      expect(spokenTime('ocho menos cuarto'), '07:45');
      expect(spokenTime('20 horas'), '20:00');
      expect(spokenTime('tres de la tarde'), '15:00');
      expect(spokenTime('doce de la noche'), '00:00');
      expect(spokenTime('2:30 p. m.'), '14:30');
      expect(spokenTime('ahora', now: now), '14:07');
      expect(spokenTime('las 7'), '07:00');
      expect(spokenTime('sin hora'), isNull);
    });
  });

  test('Fechas habladas', () {
    final today = DateTime(2026, 10, 22);
    expect(spokenDate('hoy', today: today), DateTime(2026, 10, 22));
    expect(spokenDate('ayer', today: today), DateTime(2026, 10, 21));
    expect(spokenDate('5 de octubre', today: today), DateTime(2026, 10, 5));
    expect(spokenDate('cinco de octubre', today: today), DateTime(2026, 10, 5));
    expect(spokenDate('05/10', today: today), DateTime(2026, 10, 5));
    expect(spokenDate('31 de febrero', today: today), isNull);
  });

  group('Reparto de una frase entre campos', () {
    late Map<String, String> data;
    late List<VoiceField> fields;

    setUp(() {
      data = {};
      fields = [
        VoiceField.number('Km inicio', ['km inicio', 'km inicial'], (v) => data['kmInicio'] = v, integer: true),
        VoiceField.number('Km final', ['km final'], (v) => data['kmFinal'] = v, integer: true),
        VoiceField.time('Hora de salida', ['salida', 'hora de salida'], (v) => data['salida'] = v),
        VoiceField.time('Salida del foco', ['salida del foco'], (v) => data['focoSalida'] = v),
        VoiceField.text('Conductor', ['conductor'], (v) => data['conductor'] = v),
        VoiceField.text('Hospital', ['hospital'], (v) => data['hospital'] = v),
        VoiceField.text('Observaciones', ['observaciones'], (v) => data['obs'] = v, freeText: true),
        VoiceField.choice('Servicio', ['servicio'], {'R': ['retenido'], 'FR': ['frustro', 'frustrado'], 'F': ['fallecido']}, (v) => data['servicio'] = v),
        VoiceField.command('Guardar', ['guardar'], () => data['guardado'] = 'sí'),
      ];
    });

    test('varios campos en una frase', () {
      final r = applyUtterance('kilometraje inicial 120350 hora de salida diez y cuarto conductor Juan Quispe servicio retenido', fields);
      expect(data, {'kmInicio': '120350', 'salida': '10:15', 'conductor': 'Juan Quispe', 'servicio': 'R'});
      expect(r.failed, isEmpty);
      expect(r.unmatched, isEmpty);
    });

    test('el nombre más largo gana («salida del foco» frente a «salida»)', () {
      applyUtterance('salida del foco 10:40 salida 10:05', fields);
      expect(data['focoSalida'], '10:40');
      expect(data['salida'], '10:05');
    });

    test('en texto libre no se cortan los valores por palabras de otros campos', () {
      applyUtterance('observaciones se trasladó al hospital por pedido del conductor guardar', fields);
      expect(data['obs'], 'Se trasladó al hospital por pedido del conductor');
      expect(data['hospital'], isNull);
      expect(data['guardado'], 'sí');
    });

    test('avisa de valores no entendidos y texto sin campo', () {
      final r = applyUtterance('buenos días km final sin dato servicio cualquiera', fields);
      expect(r.unmatched, ['buenos días']);
      expect(r.failed.map((f) => f.$1), ['Km final', 'Servicio']);
    });

    test('opciones con negación: la frase más larga gana', () {
      final item = <String, String>{};
      final f = [
        VoiceField.choice('Sirena', actaItemAliases('SIRENA'), {for (final o in actaOptions('SIRENA')) o: actaSpokenOptions[o]!}, (v) => item['SIRENA'] = v),
        VoiceField.choice('Luz alta', actaItemAliases('LUZ ALTA'), {for (final o in actaOptions('LUZ ALTA')) o: actaSpokenOptions[o]!}, (v) => item['LUZ ALTA'] = v),
      ];
      applyUtterance('sirena no funciona luz alta operativa', f);
      expect(item, {'SIRENA': 'INOP', 'LUZ ALTA': 'OPE'});
    });
  });

  group('Acta por voz', () {
    final values = <String, String>{};
    final fields = [
      for (final item in [for (final g in actaGroups.values) ...g])
        VoiceField.choice(item, actaItemAliases(item), {for (final o in actaOptions(item)) o: actaSpokenOptions[o]!}, (v) => values[item] = v),
    ];

    test('ítems dichos de forma natural', () {
      values.clear();
      final r = applyUtterance(
          'faro delantero derecho inoperativo luces de freno izquierda operativo agua del radiador bajo nivel '
          'extintor de cuatro kilos falta escoba no hay circulinas operativas SOAT conforme',
          fields);
      expect(r.failed, isEmpty);
      expect(values, {
        'FARO DELANTERO DERECHO': 'INOP',
        'LUZ DE FRENO IZQUIERDO': 'OPE',
        'AGUA RADIADOR (REFRIGERANTE)': 'NO',
        'EXTINTOR DE 4 KG': 'F',
        'ESCOBA': 'F',
        'PUENTE (CIRCULINAS)': 'OPE',
        'SOAT': 'OPE',
      });
    });

    test('no hay dos ítems con el mismo nombre hablado', () {
      final seen = <String, String>{};
      for (final f in fields) {
        for (final a in f.aliases) {
          final key = normalizePhrase(a);
          expect(seen[key] == null || seen[key] == f.label, isTrue, reason: '«$a» es de ${seen[key]} y de ${f.label}');
          seen[key] = f.label;
        }
      }
    });
  });

  test('Los procedimientos y áreas del catálogo tienen nombres hablables', () {
    for (final p in procedureGroups.values.expand((g) => g)) {
      expect(normalizePhrase(p), isNotEmpty);
    }
    for (final a in turnoAreas.keys) {
      expect(normalizePhrase(a), isNotEmpty);
    }
  });
}
