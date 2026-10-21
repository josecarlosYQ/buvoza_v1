import 'package:intl/intl.dart';

class DriverReport {
  DriverReport({
    String? id,
    DateTime? createdAt,
    this.driver = '',
    this.vehicleCode = '',
    this.serviceCode = '',
    this.kilometrajeInicial = '',
    this.kilometrajeFinal = '',
    this.estadoUnidad = '',
    this.combustible = '',
    this.equipos = '',
    this.observaciones = '',
  })  : id = id ?? 'BV-${DateFormat('yyyyMMdd-HHmmss').format(createdAt ?? DateTime.now())}',
        createdAt = createdAt ?? DateTime.now();

  final String id;
  final DateTime createdAt;
  String driver;
  String vehicleCode;
  String serviceCode;
  String kilometrajeInicial;
  String kilometrajeFinal;
  String estadoUnidad;
  String combustible;
  String equipos;
  String observaciones;

  String get recorrido {
    final inicio = int.tryParse(kilometrajeInicial.replaceAll(RegExp(r'[^0-9]'), ''));
    final fin = int.tryParse(kilometrajeFinal.replaceAll(RegExp(r'[^0-9]'), ''));
    if (inicio == null || fin == null || fin < inicio) return '';
    return '${fin - inicio} km';
  }
}
