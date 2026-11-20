// Contenido fijo tomado de las plantillas .xlsx.

/// FORMATO DE ENTREGA DE TURNO ENFERMERIA.xlsx — área a evaluar y su fundamento.
const turnoAreas = <String, String>{
  'MEDICAMENTOS': 'Abastecimiento de medicamentos e insumos médicos en maletín de medicamentos (rojo pequeño) y de plástico.',
  'FLUIDOS + EQUIPOS DE VÍA': 'Abastecimiento de ClNa 0.9%, Dx 5%, Soluc. Poli., Poligelina, Manitol, agua estéril, según check list.',
  'MALETÍN DE ATAQUE GRANDE': 'Maletín de ataque cuenta con todos los equipos en correcto funcionamiento, médicos e insumos descritos en el checklist.',
  'BALÓN DE OXÍGENO': 'Contar con balón de 7 m³ y 1 m³ recargados.',
  'EQUIPOS BIOMÉDICOS': 'Monitor desfibrilador, aspirador de secreciones y ventilador mecánico portátil operativos y desinfectados.',
  'LIMPIEZA': 'Cabina posterior de ambulancia limpia (asientos, gavetas).',
  'OTROS': 'Férulas, collarines, fell, inmovilizadores laterales, spider, camilla cuchara, chaleco KED.',
};

/// formato de procedimientos ENFERMERIA 2024.xlsx — una hoja por grupo.
const procedureGroups = <String, List<String>>{
  'Administración y cuidados': [
    'Administración de medicamento vía EV',
    'Administración de medicamento vía IM',
    'Administración de medicamento vía SC',
    'Administración de medicamento vía SL',
    'Administración de medicamento vía VO',
    'Administración por vía tópica',
    'Administración de medicamento con bomba infusora',
    'Administración de fluidoterapia',
    'Aspiración de secreciones',
    'Atención inmediata del recién nacido',
    'Cateterismo de vía periférica',
    'Cateterismo de vía periférica fallida',
    'Cuidados del paciente con ventilación asistida',
    'Cateterismo vesical con sonda Foley',
    'Colocación de sonda nasogástrica',
    'Toma de prueba antígena',
  ],
  'Procedimientos y monitoreo': [
    'Cateterismo vesical con sonda Nelaton',
    'Colocación de vendajes',
    'Control de funciones vitales',
    'Curación de herida',
    'Lavado gástrico',
    'Monitorización cardiaca',
    'Nebulización',
    'Inhalación y uso de aerocámara',
    'Oxigenoterapia con cánula binasal',
    'Oxigenoterapia con máscara reservorio',
    'Oxigenoterapia con máscara Venturi',
    'Realización de ECG',
    'Toma de glicemia',
    'Ventilación asistida con respirador manual',
    'Intubación endotraqueal',
  ],
  'Trauma y vía aérea': [
    'Colocación de férulas',
    'Inmovilización manual cervical',
    'Alineación del cuerpo en trauma',
    'Colocación de collarín',
    'Rotación del paciente y colocación de férula espinal larga',
    'Extricación con dispositivo tipo chaleco (KED)',
    'Retiro del casco',
    'Extricación rápida',
    'Maniobras de permeabilidad de vía aérea',
    'Uso del dispositivo BVM',
    'Colocación de cánula orofaríngea',
    'Colocación de cánula nasofaríngea',
    'Colocación de máscara laríngea',
  ],
};

/// FORMATO DE REGISTRO DE SOAPIE.xlsx
const soapieSections = <String, String>{
  'S': 'Subjetivo (lo que refiere el paciente o familiar)',
  'O': 'Objetivo (examen físico, hallazgos)',
  'A': 'Análisis / diagnóstico de enfermería',
  'P': 'Planificación (objetivos y plan de cuidados)',
  'I': 'Intervención (acciones realizadas)',
  'E': 'Evaluación (respuesta del paciente)',
};
const insuranceTypes = ['SIS', 'ESSALUD', 'SOAT', 'OTROS'];

/// Indicador de humedad del termohigrómetro (FORMATO DE ALMACEN DE MEDICAMENTOS.xlsx).
const comfortOptions = ['Confort', 'Seco', 'Húmedo'];

/// Funciones vitales del SOAPIE con rangos de alerta orientativos para adulto.
class VitalSign {
  const VitalSign(this.key, this.label, this.unit, this.low, this.high);
  final String key, label, unit;
  final double low, high;

  /// Devuelve un aviso si el valor está fuera de rango, o null.
  String? warning(String raw) {
    final value = key == 'pa' ? _systolic(raw) : double.tryParse(raw.replaceAll(',', '.'));
    if (value == null) return null;
    if (value < low) return 'Bajo (< ${_fmt(low)})';
    if (value > high) return 'Alto (> ${_fmt(high)})';
    return null;
  }

  static double? _systolic(String raw) => double.tryParse(raw.split(RegExp(r'[/\s-]')).first);
  static String _fmt(double v) => v == v.roundToDouble() ? v.toInt().toString() : v.toString();
}

const vitalSigns = [
  VitalSign('spo2', 'SpO2', '%', 92, 100),
  VitalSign('fc', 'FC', 'lpm', 60, 100),
  VitalSign('temp', 'T°', '°C', 36, 37.8),
  VitalSign('pa', 'PA', 'mmHg', 90, 140),
  VitalSign('fr', 'FR', 'rpm', 12, 20),
  VitalSign('hgt', 'HGT', 'mg/dL', 70, 180),
];

/// Rango recomendado para almacenamiento de medicamentos a temperatura ambiente controlada.
const storageTempMin = 15.0, storageTempMax = 25.0, storageTempCritical = 30.0;

String? storageTempWarning(String raw) {
  final t = double.tryParse(raw.replaceAll(',', '.'));
  if (t == null) return null;
  if (t > storageTempCritical) return 'Crítico: supera ${storageTempCritical.toInt()} °C';
  if (t > storageTempMax) return 'Fuera de rango (> ${storageTempMax.toInt()} °C)';
  if (t < storageTempMin) return 'Fuera de rango (< ${storageTempMin.toInt()} °C)';
  return null;
}

class OxygenCylinder {
  const OxygenCylinder(this.name, this.liters, this.fullPsi);
  final String name;
  final double liters; // capacidad de gas a presión llena
  final double fullPsi;

  double litersFor(double psi) => fullPsi <= 0 ? 0 : psi * liters / fullPsi;

  Map<String, dynamic> toJson() => {'name': name, 'liters': liters, 'fullPsi': fullPsi};
  factory OxygenCylinder.fromJson(Map<String, dynamic> j) =>
      OxygenCylinder(j['name'] as String, (j['liters'] as num).toDouble(), (j['fullPsi'] as num).toDouble());
}

/// Datos de cabecera que se repiten en todos los formatos (SAMU, base, distrito…).
class BaseSettings {
  BaseSettings({
    this.samu = 'SAMU ILO',
    this.base = '',
    this.district = '',
    this.ambulance = '',
    this.nurse = '',
    this.doctor = '',
    this.pilot = '',
    this.plate = '',
    List<OxygenCylinder>? cylinders,
  }) : cylinders = cylinders ?? const [OxygenCylinder('Balón 7 m³', 7000, 2000), OxygenCylinder('Balón 1 m³', 1000, 2000)];

  String samu, base, district, ambulance, nurse, doctor, pilot, plate;
  List<OxygenCylinder> cylinders;

  Map<String, dynamic> toJson() => {
        'samu': samu, 'base': base, 'district': district, 'ambulance': ambulance,
        'nurse': nurse, 'doctor': doctor, 'pilot': pilot, 'plate': plate,
        'cylinders': cylinders.map((c) => c.toJson()).toList(),
      };

  factory BaseSettings.fromJson(Map<String, dynamic> j) => BaseSettings(
        samu: (j['samu'] ?? 'SAMU ILO') as String,
        base: (j['base'] ?? '') as String,
        district: (j['district'] ?? '') as String,
        ambulance: (j['ambulance'] ?? '') as String,
        nurse: (j['nurse'] ?? '') as String,
        doctor: (j['doctor'] ?? '') as String,
        pilot: (j['pilot'] ?? '') as String,
        plate: (j['plate'] ?? '') as String,
        cylinders: (j['cylinders'] as List?)?.map((c) => OxygenCylinder.fromJson(Map<String, dynamic>.from(c as Map))).toList(),
      );
}
