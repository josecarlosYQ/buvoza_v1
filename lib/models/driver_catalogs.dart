// Contenido de los formatos impresos del conductor (SAMU Moquegua / Red de Salud Ilo).

/// ACTA DE CONFORMIDAD MECÁNICA: los primeros ítems de fluidos se marcan SI/NO/F,
/// el resto OPE/INOP/F. Las tres listas son las tres columnas del formato.
const fluidItems = {
  'AGUA RADIADOR (REFRIGERANTE)',
  'AGUA DE BATERÍA',
  'AGUA LIMPIA PARABRISAS',
  'LÍQUIDO DE FRENO',
  'NIVEL DE HIDROLINA (DIRECCIÓN)',
  'NIVEL DE ACEITE DE MOTOR',
};

const actaGroups = <String, List<String>>{
  'Motor, luces delanteras y LEDs': [
    'AGUA RADIADOR (REFRIGERANTE)',
    'AGUA DE BATERÍA',
    'AGUA LIMPIA PARABRISAS',
    'LÍQUIDO DE FRENO',
    'NIVEL DE HIDROLINA (DIRECCIÓN)',
    'NIVEL DE ACEITE DE MOTOR',
    'PRESIÓN DE AIRE EN LLANTAS (04)',
    'PUENTE (CIRCULINAS)',
    'SIRENA',
    'BATERÍA DE 12V',
    'FRENO DE MANO',
    'TAPA DE DEPÓSITO DE HIDROLINA DIR.',
    'TAPA DE RADIADOR',
    'TAPA DE ACEITE DE MOTOR',
    'TAPA DE LÍQUIDO DE FRENO',
    'TAPA DE COMBUSTIBLE',
    'VARILLA MEDIDA DE ACEITE (MOTOR)',
    'FARO DELANTERO DERECHO',
    'FARO DELANTERO IZQUIERDO',
    'LUZ ALTA',
    'LUZ BAJA',
    'LUZ CHICA DELANTERO DERECHO',
    'LUZ CHICA DELANTERO IZQUIERDO',
    'DIRECCIONALES DELANTERO DER.',
    'DIRECCIONALES DELANTERO IZQ.',
    'MÁSCARA DELANTERA',
    'FARO NEBLINERO DERECHO',
    'FARO NEBLINERO IZQUIERDO',
    'LÁMPARA MÓVIL CON EXTENSIÓN',
    'LEDS NARANJA ANTERIOR LAT. DER.',
    'LEDS BLANCO SUPERIOR LAT. DER.',
    'LEDS BLANCO DESTELLANTE LAT. DER.',
    'LEDS NARANJA POSTERIOR LAT. DER.',
    'LEDS NARANJA ANTERIOR LAT. IZQ.',
    'LEDS BLANCO SUPERIOR LAT. IZQ.',
    'LEDS BLANCO DESTELLANTE LAT. IZQ.',
    'LEDS NARANJA POSTERIOR LAT. IZQ.',
    'LEDS DESTELLANTE POSTERIOR DER.',
    'LEDS DESTELLANTE POSTERIOR IZQ.',
    'LED BLANCO POSTERIOR MEDIO',
  ],
  'Luces posteriores, carrocería y herramientas': [
    'FARO POSTERIOR DERECHO',
    'FARO POSTERIOR IZQUIERDO',
    'LUZ CHICA POSTERIOR DERECHO',
    'LUZ CHICA POSTERIOR IZQUIERDO',
    'LUZ DE FRENO DERECHO',
    'LUZ DE FRENO IZQUIERDO',
    'DIRECCIONAL POSTERIOR DER.',
    'DIRECCIONAL POSTERIOR IZQ.',
    'LUZ DE RETROCESO DERECHO',
    'LUZ DE RETROCESO IZQUIERDO',
    'LUCES DE PLACA',
    'MANIJA PUERTA CENT. CORREDIZA',
    'MANIJAS DELANTERA DERECHA',
    'MANIJAS DELANTERA IZQUIERDA',
    'MANIJA POSTERIOR DERECHA',
    'MANIJA POSTERIOR IZQUIERDA',
    'ESPEJO RETR. DELANTERO DERECHO',
    'ESPEJO RETR. DELANTERO IZQUIERDO',
    'PLACA DELANTERA',
    'PLACA POSTERIOR',
    'LLANTAS DELANTERAS',
    'LLANTAS POSTERIORES',
    'LLANTA DE REPUESTO',
    'VASOS DE LLANTAS (4)',
    'EXTINTOR DE 4 KG',
    'EXTINTOR DE 2 KG',
    'TRIÁNGULOS DE SEGURIDAD (2)',
    'CONOS DE SEGURIDAD',
    'CORREAS DE SEGURIDAD',
    'CABLE DE REMOLQUE O ARRASTRE',
    'PERNO DE REMOLQUE',
    'GATA HIDRÁULICA Y 03 PALANCAS EXT.',
    'LLAVE DE RUEDAS EN CRUZ',
    'LLAVE DE RUEDAS EN "L" WALTHER',
    'MEDIDOR DE PRESIÓN DE AIRE (LLANTAS)',
    'LLAVE FRANCESA N° 12',
    'ALICATE DE CORTE',
    'DESARMADOR DUAL (PLANO ESTRELLA)',
    'LLAVE STARD',
    'JGO. DE LLAVES MIXTAS (8 PZAS)',
  ],
  'Documentos, comunicaciones y tablero': [
    'CABLE AUXILIAR ARRAN. (COCODRILO)',
    'CARRETE DE CABLE DE 220V',
    'CABLE DE ACERO REMOLQUE',
    'MANUAL DE LA AMBULANCIA NEGRO',
    'MANUAL DE PLAN MANTENIMIENTO',
    '2 MANUALES ANILL. OPER. EQ. MED',
    '1 MANUAL ANILL DE REPUESTOS',
    'TARJETA DE PROPIEDAD',
    'TRANSFERENCIA DE PROPIEDAD',
    'SOAT',
    'TARJETA DE COMBUSTIBLE REPSOL',
    'TARJETA COMBUST. OPER. AMARILLA',
    'REVISIÓN TÉCNICA',
    'ENCENDEDOR',
    'CUADERNO DE RELEVO',
    'BITÁCORA',
    'AUTORADIO',
    'CONTROL DE AUTORADIO',
    'MÁSCARA DE AUTORADIO',
    'RADIO DE COMUNICACIÓN EMPOTRA.',
    'RADIO DE COMUNICACIÓN MÓVIL (TETRA)',
    'MICAS DE LUZ DE SALÓN',
    'LUZ DE SALÓN',
    'PISOS DE JEBE DELANTEROS',
    'MEGÁFONO DE ALTAVOZ',
    'PLUMILLAS',
    'TAPASOLES',
    'ANTENA',
    'SENSOR DE NIVEL DE COMBUSTIBLE',
    'SENSOR DE TEMPERATURA',
    'SENSOR DE PRESIÓN DE ACEITE',
    'VELOCÍMETRO (KM/HORA)',
    'ODÓMETRO (CUENTA KILÓMETROS)',
    'TACÓMETRO (RPMs)',
    'ESPEJO INTERIOR',
    'FRANELAS',
    'LOGO VW DELANTERO',
    'LOGO VW POSTERIOR',
    'ESCOBA',
    'KIT DE LIMPIEZA',
  ],
};

/// Opciones de cada ítem: la primera es el estado "conforme".
List<String> actaOptions(String item) => fluidItems.contains(item) ? const ['SI', 'NO', 'F'] : const ['OPE', 'INOP', 'F'];
bool actaIsProblem(String item, String? value) => value != null && value != actaOptions(item).first;

/// Formas de decir cada estado al llenar el acta por voz.
const actaSpokenOptions = <String, List<String>>{
  'SI': ['sí', 'conforme', 'bien', 'ok', 'completo', 'lleno', 'normal', 'nivel correcto'],
  'NO': ['no', 'bajo', 'bajo nivel', 'nivel bajo', 'incompleto'],
  'OPE': ['operativo', 'operativa', 'operativos', 'opera', 'conforme', 'bien', 'ok', 'funciona', 'normal', 'bueno', 'buena', 'sí'],
  'INOP': ['inoperativo', 'inoperativa', 'inoperativos', 'no funciona', 'malogrado', 'malograda', 'dañado', 'dañada', 'roto', 'rota', 'mal', 'malo', 'mala', 'no opera'],
  'F': ['falta', 'no hay', 'no tiene', 'faltante', 'no está'],
};

/// Nombres cortos con que se suelen decir algunos ítems del acta.
const _actaExtraAliases = <String, List<String>>{
  'AGUA RADIADOR (REFRIGERANTE)': ['refrigerante', 'agua del radiador', 'radiador'],
  'NIVEL DE HIDROLINA (DIRECCIÓN)': ['hidrolina', 'nivel de hidrolina'],
  'NIVEL DE ACEITE DE MOTOR': ['aceite de motor', 'nivel de aceite'],
  'PRESIÓN DE AIRE EN LLANTAS (04)': ['presión de aire', 'presión de llantas', 'aire de llantas'],
  'PUENTE (CIRCULINAS)': ['circulinas', 'puente'],
  'VARILLA MEDIDA DE ACEITE (MOTOR)': ['varilla de aceite', 'varilla'],
  'GATA HIDRÁULICA Y 03 PALANCAS EXT.': ['gata', 'gata hidráulica'],
  'LLAVE DE RUEDAS EN "L" WALTHER': ['llave en L', 'llave de ruedas en L'],
  'MEDIDOR DE PRESIÓN DE AIRE (LLANTAS)': ['medidor de presión'],
  'DESARMADOR DUAL (PLANO ESTRELLA)': ['desarmador'],
  'JGO. DE LLAVES MIXTAS (8 PZAS)': ['juego de llaves mixtas', 'llaves mixtas'],
  'CABLE AUXILIAR ARRAN. (COCODRILO)': ['cable cocodrilo', 'cables de arranque', 'cable auxiliar'],
  'RADIO DE COMUNICACIÓN EMPOTRA.': ['radio empotrada', 'radio de comunicación empotrada'],
  'RADIO DE COMUNICACIÓN MÓVIL (TETRA)': ['radio tetra', 'tetra', 'radio móvil'],
  'VELOCÍMETRO (KM/HORA)': ['velocímetro'],
  'ODÓMETRO (CUENTA KILÓMETROS)': ['odómetro', 'cuenta kilómetros'],
  'TACÓMETRO (RPMs)': ['tacómetro'],
  'TARJETA COMBUST. OPER. AMARILLA': ['tarjeta amarilla', 'tarjeta de combustible amarilla'],
  'TARJETA DE COMBUSTIBLE REPSOL': ['tarjeta repsol'],
  '2 MANUALES ANILL. OPER. EQ. MED': ['manuales de equipos médicos', 'manuales anillados'],
  '1 MANUAL ANILL DE REPUESTOS': ['manual de repuestos'],
  'MANIJA PUERTA CENT. CORREDIZA': ['manija de puerta corrediza', 'puerta corrediza'],
};

/// Formas de nombrar un ítem del acta al hablar: el nombre sin paréntesis, con ellos y los cortos.
List<String> actaItemAliases(String item) {
  final noParens = item.replaceAll(RegExp(r'\([^)]*\)'), ' ').replaceAll('"', '').trim();
  final withParens = item.replaceAll(RegExp(r'[()"]'), ' ').trim();
  return {noParens, withParens, ...?_actaExtraAliases[item]}.toList();
}

const fuelSpokenNames = <String, List<String>>{
  'Diésel': ['diésel', 'petróleo'],
  'Gasolina': ['gasolina'],
  'GLP': ['glp', 'gas licuado'],
  'GNV': ['gnv', 'gas natural'],
};

const actaOptionHelp ='SI/OPE = conforme u operativo · NO/INOP = bajo nivel o inoperativo · F = falta';

/// REGISTRO DE HORAS DE LA EMERGENCIA: columna «Servicio».
/// En el formato impreso Fallecido y Frustro comparten la letra F; aquí Frustro se abrevia FR.
const serviceOutcomes = {'R': 'Retenido', 'F': 'Fallecido', 'C': 'Cancelado', 'FR': 'Frustro'};

const fuelTypes = ['Diésel', 'Gasolina', 'GLP', 'GNV'];

/// Parte numérica de un kilometraje («120 350 km» → 120350).
int? parseKm(Object? raw) => int.tryParse((raw ?? '').toString().replaceAll(RegExp(r'[^0-9]'), ''));
