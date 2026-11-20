import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Roles que usan los formatos clínicos.
enum ClinicalRole { conductor, medico, enfermeria }

/// Cada tipo corresponde a una de las plantillas SAMU (.xlsx o formato impreso).
enum FormType { bitacora, actaMecanica, horasEmergencia, soapie, turno, procedimientos, oxigeno, almacen }

extension FormTypeInfo on FormType {
  String get title => switch (this) {
        FormType.bitacora => 'Bitácora de servicio',
        FormType.actaMecanica => 'Acta de conformidad mecánica',
        FormType.horasEmergencia => 'Registro de horas de la emergencia',
        FormType.soapie => 'Registro SOAPIE',
        FormType.turno => 'Entrega de turno',
        FormType.procedimientos => 'Procedimientos',
        FormType.oxigeno => 'Consumo de oxígeno',
        FormType.almacen => 'Temperatura de almacén',
      };

  String get description => switch (this) {
        FormType.bitacora => 'Inicio y fin de turno, kilometraje y recorridos de la ambulancia.',
        FormType.actaMecanica => 'Checklist de 120 ítems (SI/NO/F · OPE/INOP/F) al recibir la unidad.',
        FormType.horasEmergencia => 'Horas y km de salida, foco, hospital y retorno de cada emergencia.',
        FormType.soapie => 'Registro por paciente con funciones vitales y dictado por voz.',
        FormType.turno => 'Checklist de recepción del turno (M/T/N) de la ambulancia.',
        FormType.procedimientos => 'Conteo de procedimientos por turno. Genera el reporte quincenal.',
        FormType.oxigeno => 'Consumo, trasegado y stock en PSI, con conversión a litros.',
        FormType.almacen => 'Control de temperatura y confort al ingreso y salida.',
      };

  IconData get icon => switch (this) {
        FormType.bitacora => Icons.route,
        FormType.actaMecanica => Icons.build_circle,
        FormType.horasEmergencia => Icons.timer,
        FormType.soapie => Icons.assignment_ind,
        FormType.turno => Icons.swap_horiz,
        FormType.procedimientos => Icons.vaccines,
        FormType.oxigeno => Icons.air,
        FormType.almacen => Icons.thermostat,
      };

  String get prefix => switch (this) {
        FormType.bitacora => 'BIT',
        FormType.actaMecanica => 'ACT',
        FormType.horasEmergencia => 'HOR',
        FormType.soapie => 'SOA',
        FormType.turno => 'TUR',
        FormType.procedimientos => 'PRO',
        FormType.oxigeno => 'OXI',
        FormType.almacen => 'ALM',
      };

  /// Turnos que usa la plantilla original.
  List<String> get shifts => switch (this) {
        FormType.soapie => const ['M', 'T', 'MT', 'N'],
        FormType.turno => const ['M', 'T', 'N'],
        FormType.procedimientos || FormType.oxigeno || FormType.bitacora || FormType.actaMecanica || FormType.horasEmergencia => const ['D', 'N'],
        FormType.almacen => const [],
      };

  /// Los reportes agregados se generan por quincena; almacén y SOAPIE no.
  bool get isFortnightly => this == FormType.turno || this == FormType.procedimientos || this == FormType.oxigeno;

  /// Formatos que se imprimen uno por registro (el resto genera un reporte del periodo).
  bool get perEntryPdf => const [FormType.soapie, FormType.bitacora, FormType.actaMecanica, FormType.horasEmergencia].contains(this);

  List<ClinicalRole> get roles => switch (this) {
        FormType.bitacora || FormType.horasEmergencia => const [ClinicalRole.conductor],
        FormType.actaMecanica => const [ClinicalRole.conductor, ClinicalRole.medico],
        FormType.soapie || FormType.almacen || FormType.oxigeno => const [ClinicalRole.medico, ClinicalRole.enfermeria],
        _ => const [ClinicalRole.enfermeria],
      };
}

const shiftNames = {'M': 'Mañana', 'T': 'Tarde', 'MT': 'Mañana-Tarde', 'N': 'Noche', 'D': 'Día'};

class FormEntry {
  FormEntry({String? id, DateTime? createdAt, required this.type, DateTime? date, this.shift = '', Map<String, dynamic>? data})
      : createdAt = createdAt ?? DateTime.now(),
        id = id ?? '${type.prefix}-${DateFormat('yyyyMMdd-HHmmss').format(createdAt ?? DateTime.now())}',
        date = DateUtils.dateOnly(date ?? DateTime.now()),
        data = data ?? {};

  final String id;
  final DateTime createdAt;
  final FormType type;
  DateTime date;
  String shift;
  Map<String, dynamic> data;

  String text(String key) => (data[key] ?? '').toString();
  Map<String, dynamic> map(String key) => Map<String, dynamic>.from(data[key] as Map? ?? {});

  Map<String, dynamic> toJson() => {
        'id': id,
        'createdAt': createdAt.toIso8601String(),
        'type': type.name,
        'date': date.toIso8601String(),
        'shift': shift,
        'data': data,
      };

  factory FormEntry.fromJson(Map<String, dynamic> j) => FormEntry(
        id: j['id'] as String,
        createdAt: DateTime.parse(j['createdAt'] as String),
        type: FormType.values.byName(j['type'] as String),
        date: DateTime.parse(j['date'] as String),
        shift: (j['shift'] ?? '') as String,
        data: Map<String, dynamic>.from(j['data'] as Map? ?? {}),
      );
}

/// Primera (1-15) o segunda (16-fin de mes) quincena, o el mes completo.
class Period {
  const Period(this.year, this.month, this.half);
  final int year, month;
  final int half; // 1, 2 o 0 = mes completo

  int get firstDay => half == 2 ? 16 : 1;
  int get lastDay => half == 1 ? 15 : DateUtils.getDaysInMonth(year, month);
  List<int> get days => [for (var d = firstDay; d <= lastDay; d++) d];
  DateTime get from => DateTime(year, month, firstDay);
  DateTime get to => DateTime(year, month, lastDay);
  bool contains(DateTime d) => d.year == year && d.month == month && d.day >= firstDay && d.day <= lastDay;

  String get label => '${half == 0 ? '' : '${half == 1 ? '1ª' : '2ª'} quincena · '}${monthNames[month - 1]} $year';
  String get fileTag => '$year${month.toString().padLeft(2, '0')}${half == 0 ? '' : '-Q$half'}';

  factory Period.current({bool fortnightly = true}) {
    final now = DateTime.now();
    return Period(now.year, now.month, fortnightly ? (now.day <= 15 ? 1 : 2) : 0);
  }
}

const monthNames = ['Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio', 'Julio', 'Agosto', 'Setiembre', 'Octubre', 'Noviembre', 'Diciembre'];
