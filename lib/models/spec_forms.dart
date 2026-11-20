import 'form_entry.dart';

/// Formatos del médico descritos como datos (secciones y campos).
/// La pantalla, el llenado por voz y el PDF se generan a partir de esta descripción.

enum SpecKind { text, longText, number, integer, time, pressure, choice, flags, rows }

class SpecField {
  const SpecField(
    this.key,
    this.label, {
    this.kind = SpecKind.text,
    this.aliases = const [],
    this.options = const {},
    this.fields = const [],
    this.half = false,
    this.prefill,
    this.unit,
    this.sumOf = const [],
    this.rowLabel = '',
    this.cutsText = false,
  });

  final String key;
  final String label;
  final SpecKind kind;

  /// Formas habladas del campo; si está vacío se usa la etiqueta.
  final List<String> aliases;

  /// choice / flags: valor guardado → otras formas de decirlo.
  final Map<String, List<String>> options;

  /// rows: columnas de cada fila.
  final List<SpecField> fields;

  /// Ocupa media línea (se empareja con el siguiente campo de media línea).
  final bool half;

  /// Clave de los ajustes de la base con la que se rellena un registro nuevo
  /// (samu, base, district, ambulance, nurse, doctor, pilot, plate).
  final String? prefill;
  final String? unit;

  /// Campo calculado: suma de otros campos numéricos.
  final List<String> sumOf;

  /// rows: nombre de una fila («Evaluación», «Ocurrencia»).
  final String rowLabel;

  /// Al dictarlo corta un texto libre en curso (la hora de una nueva ocurrencia).
  final bool cutsText;

  List<String> get spoken => aliases.isEmpty ? [label.toLowerCase()] : aliases;
  bool get isComputed => sumOf.isNotEmpty;
}

class SpecSection {
  const SpecSection(this.title, this.fields);
  final String title;
  final List<SpecField> fields;
}

class FormSpec {
  const FormSpec({required this.type, required this.pdfTitle, required this.banner, required this.sections, this.titleKey = '', this.subtitleKeys = const [], this.signatures = const []});
  final FormType type;
  final String pdfTitle;
  final String banner;
  final List<SpecSection> sections;

  /// Campo que identifica el registro en la lista (paciente, N° CRUE…).
  final String titleKey;
  final List<String> subtitleKeys;

  /// Firmas al pie del PDF: (cargo, clave del nombre).
  final List<(String, String)> signatures;

  Iterable<SpecField> get allFields => sections.expand((s) => s.fields);
}

/// Suma de los campos de [f.sumOf] en [values], o '' si no hay ninguno.
String computeSum(SpecField f, Map<String, dynamic> values) {
  var total = 0.0;
  var any = false;
  for (final k in f.sumOf) {
    final v = double.tryParse((values[k] ?? '').toString().replaceAll(',', '.'));
    if (v != null) {
      total += v;
      any = true;
    }
  }
  if (!any) return '';
  return total == total.roundToDouble() ? total.toInt().toString() : total.toStringAsFixed(1);
}

const _yesNo = {'Sí': ['si', 'sí'], 'No': ['no']};
const _priority = {'I': ['uno', '1'], 'II': ['dos', '2'], 'III': ['tres', '3'], 'IV': ['cuatro', '4']};
const _sex = {'M': ['masculino', 'hombre', 'varón'], 'F': ['femenino', 'mujer']};


// ---------------------------------------------------------------------------
// FICHA DE ATENCIÓN PRE HOSPITALARIA (MINSA, anexo 2016)
// ---------------------------------------------------------------------------

const fichaAphSpec = FormSpec(
  type: FormType.fichaAph,
  pdfTitle: 'FICHA DE ATENCIÓN PRE HOSPITALARIA',
  banner: 'Una ficha por paciente. Dicta por secciones: «paciente…», «presión arterial 120 sobre 80», «nueva evaluación», «medicamento…».',
  titleKey: 'paciente',
  subtitleKeys: ['dx1', 'numero'],
  signatures: [('MÉDICO RESPONSABLE', 'medico'), ('ENFERMERA(O)', 'enfermero'), ('MÉDICO QUE RECIBE AL PACIENTE', 'medicoRecibe')],
  sections: [
    SpecSection('Datos de la atención', [
      SpecField('numero', 'N° de ficha', aliases: ['número de ficha', 'ficha'], half: true),
      SpecField('samuBase', 'SAMU base', aliases: ['samu base', 'base'], half: true, prefill: 'base'),
      SpecField('horaDespacho', 'Hora de despacho', kind: SpecKind.time, aliases: ['hora de despacho', 'despacho'], half: true),
      SpecField('horaSalidaBase', 'Salida de base', kind: SpecKind.time, aliases: ['salida de base'], half: true),
      SpecField('horaLlegadaFoco', 'Llegada a foco', kind: SpecKind.time, aliases: ['llegada a foco', 'llegada al foco'], half: true),
      SpecField('horaSalidaFoco', 'Salida de foco', kind: SpecKind.time, aliases: ['salida de foco', 'salida del foco'], half: true),
      SpecField('horaLlegadaBase', 'Llegada a base', kind: SpecKind.time, aliases: ['llegada a base'], half: true),
      SpecField('atencion', 'Atención', kind: SpecKind.choice, aliases: ['atención', 'tipo de atención'], options: {'Foco': ['foco'], 'Traslado': ['traslado']}),
      SpecField('prioridad', 'Prioridad de la emergencia', kind: SpecKind.choice, aliases: ['prioridad'], options: _priority),
      SpecField('fallecido', 'Fallecido', kind: SpecKind.choice, aliases: ['fallecido', 'falleció'],
          options: {'No': ['no'], 'Foco': ['en foco', 'en el foco', 'foco'], 'Traslado': ['durante el traslado', 'traslado']}),
      SpecField('motivo', 'Motivo de la emergencia', aliases: ['motivo de la emergencia', 'motivo']),
    ]),
    SpecSection('Identificación del paciente', [
      SpecField('paciente', 'Apellidos y nombres', aliases: ['paciente', 'nombre del paciente', 'apellidos y nombres']),
      SpecField('dni', 'DNI', aliases: ['dni', 'documento'], half: true),
      SpecField('nacimiento', 'Fecha de nacimiento', aliases: ['fecha de nacimiento', 'nacimiento'], half: true),
      SpecField('edad', 'Edad', kind: SpecKind.integer, aliases: ['edad'], half: true, unit: 'años'),
      SpecField('sexo', 'Sexo', kind: SpecKind.choice, aliases: ['sexo'], options: _sex, half: true),
      SpecField('direccion', 'Dirección de la atención', aliases: ['dirección', 'dirección de la atención']),
      SpecField('distrito', 'Distrito', aliases: ['distrito'], half: true),
      SpecField('referencia', 'Referencia', aliases: ['referencia'], half: true),
      SpecField('seguro', 'Tipo de seguro', kind: SpecKind.choice, aliases: ['seguro', 'tipo de seguro'], options: {
        'SIS': ['sis'], 'EsSalud': ['essalud', 'es salud'], 'SOAT': ['soat'], 'EPS': ['eps'], 'Otros': ['otro', 'otros'], 'Sin seguro': ['sin seguro', 'ninguno'],
      }),
    ]),
    SpecSection('Antecedentes', [
      SpecField('patologias', 'Patologías previas', aliases: ['patologías previas', 'antecedentes', 'patologías']),
      SpecField('medicacionPrevia', 'Medicación habitual', aliases: ['medicación habitual', 'medicación previa', 'toma medicación']),
      SpecField('alergias', 'Alergias', aliases: ['alergias', 'alérgico', 'alérgica']),
      SpecField('otrosAntecedentes', 'Otros antecedentes', aliases: ['otros antecedentes']),
      SpecField('fur', 'FUR', aliases: ['fur', 'fecha de última regla'], half: true),
      SpecField('fpp', 'FPP', aliases: ['fpp', 'fecha probable de parto'], half: true),
      SpecField('fug', 'FUG', aliases: ['fug'], half: true),
      SpecField('gp', 'G / P', aliases: ['gestaciones', 'fórmula obstétrica'], half: true),
    ]),
    SpecSection('Enfermedad actual', [
      SpecField('tiempoEnfermedad', 'Tiempo de enfermedad', aliases: ['tiempo de enfermedad'], half: true),
      SpecField('inicio', 'Inicio', aliases: ['forma de inicio', 'inicio de la enfermedad'], half: true),
      SpecField('curso', 'Curso', aliases: ['curso de la enfermedad', 'curso'], half: true),
      SpecField('relato', 'Relato del evento', kind: SpecKind.longText, aliases: ['relato del evento', 'relato']),
    ]),
    SpecSection('Examen físico', [
      SpecField('cabeza', 'Cabeza', aliases: ['cabeza']),
      SpecField('cuello', 'Cuello', aliases: ['cuello']),
      SpecField('piel', 'Piel y TCSC', aliases: ['piel', 'piel y tcsc', 'tejido celular']),
      SpecField('respiratorio', 'Aparato respiratorio', aliases: ['aparato respiratorio', 'respiratorio', 'pulmones']),
      SpecField('cardiovascular', 'Aparato cardiovascular', aliases: ['aparato cardiovascular', 'cardiovascular', 'corazón']),
      SpecField('digestivo', 'Aparato digestivo', aliases: ['aparato digestivo', 'digestivo', 'abdomen']),
      SpecField('genitourinario', 'Genito-urinario', aliases: ['genitourinario', 'genito urinario']),
      SpecField('osteomioarticular', 'Sistema osteomioarticular', aliases: ['osteomioarticular', 'sistema osteomioarticular', 'extremidades']),
      SpecField('neurologico', 'Neurológico', aliases: ['neurológico', 'examen neurológico']),
      SpecField('zonaAfectada', 'Zona afectada', aliases: ['zona afectada', 'zona lesionada']),
    ]),
    SpecSection('Signos vitales, Glasgow y pupilas', [
      SpecField('evaluaciones', 'Evaluaciones', kind: SpecKind.rows, rowLabel: 'Evaluación', fields: [
        SpecField('momento', 'Momento', aliases: ['momento de la evaluación', 'momento']),
        SpecField('temp', 'Temperatura', kind: SpecKind.number, aliases: ['temperatura'], unit: '°C'),
        SpecField('fc', 'Frecuencia cardiaca', kind: SpecKind.integer, aliases: ['frecuencia cardiaca', 'pulso'], unit: '/min'),
        SpecField('pa', 'Presión arterial', kind: SpecKind.pressure, aliases: ['presión arterial', 'presión'], unit: 'mmHg'),
        SpecField('fr', 'Frecuencia respiratoria', kind: SpecKind.integer, aliases: ['frecuencia respiratoria'], unit: '/min'),
        SpecField('sat', 'Saturación de oxígeno', kind: SpecKind.integer, aliases: ['saturación', 'saturación de oxígeno'], unit: '%'),
        SpecField('glucemia', 'Glucemia', kind: SpecKind.integer, aliases: ['glucemia', 'glucosa'], unit: 'mg/dl'),
        SpecField('go', 'Apertura ocular (4)', kind: SpecKind.integer, aliases: ['apertura ocular', 'ocular']),
        SpecField('gv', 'Respuesta verbal (5)', kind: SpecKind.integer, aliases: ['respuesta verbal', 'verbal']),
        SpecField('gm', 'Respuesta motora (6)', kind: SpecKind.integer, aliases: ['respuesta motora', 'motora']),
        SpecField('gt', 'Glasgow total (15)', kind: SpecKind.integer, sumOf: ['go', 'gv', 'gm']),
        SpecField('pupilas', 'Pupilas', aliases: ['pupilas']),
      ]),
    ]),
    SpecSection('Mecanismo de lesión', [
      SpecField('caidaNivel', 'Caída: nivel', aliases: ['caída nivel', 'nivel de caída'], half: true),
      SpecField('caidaAltura', 'Caída: altura', aliases: ['altura de caída', 'caída altura', 'altura'], half: true),
      SpecField('caidaSuperficie', 'Caída: superficie', aliases: ['superficie de caída', 'superficie']),
      SpecField('quemaduraGrado', 'Quemadura: grado', aliases: ['quemadura grado', 'grado de quemadura'], half: true),
      SpecField('quemaduraSC', 'Superficie corporal', kind: SpecKind.number, aliases: ['superficie corporal', 'porcentaje quemado'], half: true, unit: '% SC'),
      SpecField('quemaduraTipo', 'Quemadura por', kind: SpecKind.flags, aliases: ['quemadura por', 'tipo de quemadura'],
          options: {'Calor': ['calor'], 'Frío': ['frío'], 'Eléctrico': ['eléctrica', 'electricidad'], 'Químico': ['química']}),
      SpecField('agresion', 'Agresión', kind: SpecKind.flags, aliases: ['agresión', 'agresión con'],
          options: {'Arma blanca': ['arma blanca', 'cuchillo'], 'Arma de fuego': ['arma de fuego', 'bala', 'disparo'], 'Otros': ['otros', 'otro']}),
    ]),
    SpecSection('Accidente de tránsito', [
      SpecField('tipoVictima', 'Tipo de víctima', kind: SpecKind.flags, aliases: ['tipo de víctima', 'víctima'],
          options: {'Conductor': ['conductor'], 'Pasajero': ['pasajero'], 'Peatón': ['peatón']}),
      SpecField('tipoVehiculo', 'Tipo de vehículo', kind: SpecKind.flags, aliases: ['tipo de vehículo', 'vehículo'], options: {
        'Mototaxi': ['mototaxi', 'moto taxi'], 'Automóvil': ['automóvil', 'auto', 'carro'], 'Cúster': ['cúster', 'coaster'], 'Autobús': ['autobús', 'bus'],
        'Motocicleta': ['motocicleta', 'moto'], 'Bicicleta': ['bicicleta'], 'Otros': ['otros', 'otro'],
      }),
      SpecField('cinematica', 'Cinemática del trauma', kind: SpecKind.flags, aliases: ['cinemática', 'cinemática del trauma'], options: {
        'Impacto frontal': ['frontal'], 'Impacto posterior': ['posterior'], 'Impacto lateral': ['lateral'], 'Atropello': ['atropello', 'atropellado'],
        'Volcamiento': ['volcamiento', 'volcadura'], 'Choque de vehículo': ['choque'], 'Expulsión de vehículo': ['expulsión', 'expulsado'],
        'Caída de vehículo': ['caída de vehículo', 'caída de la moto'],
      }),
      SpecField('ubicacion', 'Ubicación de la víctima', kind: SpecKind.flags, aliases: ['ubicación de la víctima', 'ubicación'], options: {
        'Asiento delantero': ['asiento delantero', 'delantero'], 'Asiento posterior': ['asiento posterior', 'asiento trasero'],
        'Víctima atrapada': ['atrapada', 'atrapado'], 'Otros': ['otros', 'otro'],
      }),
      SpecField('implementos', 'Implementos de seguridad', kind: SpecKind.flags, aliases: ['implementos de seguridad', 'implementos'], options: {
        'Bolsa inflada': ['bolsa inflada', 'airbag'], 'Cinturón colocado': ['cinturón'], 'Casco colocado': ['casco'], 'Ropa protectora': ['ropa protectora'],
      }),
    ]),
    SpecSection('Diagnósticos presuntivos', [
      SpecField('dx1', 'Diagnóstico 1', aliases: ['diagnóstico uno', 'diagnóstico 1', 'diagnóstico']),
      SpecField('cie1', 'CIE-10 (1)', aliases: ['cie uno', 'cie 1', 'cie'], half: true),
      SpecField('dx2', 'Diagnóstico 2', aliases: ['diagnóstico dos', 'diagnóstico 2', 'segundo diagnóstico']),
      SpecField('cie2', 'CIE-10 (2)', aliases: ['cie dos', 'cie 2'], half: true),
      SpecField('dx3', 'Diagnóstico 3', aliases: ['diagnóstico tres', 'diagnóstico 3', 'tercer diagnóstico']),
      SpecField('cie3', 'CIE-10 (3)', aliases: ['cie tres', 'cie 3'], half: true),
      SpecField('dx4', 'Diagnóstico 4', aliases: ['diagnóstico cuatro', 'diagnóstico 4', 'cuarto diagnóstico']),
      SpecField('cie4', 'CIE-10 (4)', aliases: ['cie cuatro', 'cie 4'], half: true),
    ]),
    SpecSection('Procedimientos y tratamiento', [
      SpecField('procedimientos', 'Procedimientos', kind: SpecKind.flags, aliases: ['procedimientos', 'procedimiento', 'se realizó'], options: {
        'Oxigenoterapia': ['oxigenoterapia', 'oxígeno'], 'Fluidoterapia': ['fluidoterapia', 'fluidos'], 'Monitoreo cardiaco': ['monitoreo'],
        'Ventilación mecánica': ['ventilación mecánica'], 'CPAP / PPI': ['cpap', 'presión positiva'], 'Tratamiento por inhalación': ['inhalación'],
        'Inmovilización completa': ['inmovilización completa'], 'Inmovilización MMSS': ['inmovilización de miembro superior', 'mmss'],
        'Inmovilización MMII': ['inmovilización de miembro inferior', 'mmii'], 'Vendaje': ['vendaje'], 'Sonda nasogástrica': ['sonda nasogástrica', 'nasogástrica'],
        'Sonda vesical': ['sonda vesical', 'vesical'], 'Sedación': ['sedación'], 'Intubación': ['intubación', 'intubado'], 'Traqueostomía': ['traqueostomía'],
        'Curación': ['curación'], 'Sutura': ['sutura'], 'Cuerpo extraño': ['cuerpo extraño'], 'Hemostasia': ['hemostasia'],
        'Taponamiento nasal': ['taponamiento nasal'], 'Infusión intraósea': ['intraósea'], 'Aspiración de secreciones': ['aspiración'],
        'Hemoglucotest': ['hemoglucotest'], 'Nebulización': ['nebulización'],
      }),
      SpecField('rcp', 'RCP', kind: SpecKind.choice, aliases: ['rcp', 'reanimación'], options: {'Exitoso': ['exitoso', 'exitosa'], 'No exitoso': ['no exitoso', 'no exitosa']}, half: true),
      SpecField('dea', 'Uso de DEA', kind: SpecKind.choice, aliases: ['dea', 'desfibrilador'], options: _yesNo, half: true),
      SpecField('cardioversion', 'Cardioversión', kind: SpecKind.choice, aliases: ['cardioversión'], options: {'Sí': ['si', 'sí'], 'Selectiva': ['selectiva']}, half: true),
      SpecField('otrosProcedimientos', 'Otros procedimientos', aliases: ['otros procedimientos']),
    ]),
    SpecSection('Medicación', [
      SpecField('medicacion', 'Medicación', kind: SpecKind.rows, rowLabel: 'Medicamento', fields: [
        SpecField('medicamento', 'Medicamento', aliases: ['medicamento', 'se administra']),
        SpecField('dosis', 'Dosis', aliases: ['dosis']),
        SpecField('via', 'Vía', kind: SpecKind.choice, aliases: ['vía', 'vía de administración'], options: {
          'Tópica': ['tópica'], 'SC': ['subcutánea'], 'IM': ['intramuscular'], 'EV': ['endovenosa', 'intravenosa'], 'SL': ['sublingual'], 'VO': ['oral'], 'INH': ['inhalada', 'inhalatoria'],
        }),
        SpecField('hora', 'Hora', kind: SpecKind.time, aliases: ['hora del medicamento', 'hora de administración']),
      ]),
    ]),
    SpecSection('Ocurrencias durante la atención', [
      SpecField('ocurrencias', 'Ocurrencias', kind: SpecKind.longText, aliases: ['ocurrencias', 'ocurrencia']),
    ]),
    SpecSection('Responsables de la atención', [
      SpecField('medico', 'Médico', aliases: ['médico responsable', 'médico'], prefill: 'doctor'),
      SpecField('cmp', 'N° CMP', aliases: ['cmp', 'colegiatura médica'], half: true),
      SpecField('enfermero', 'Enfermera(o)', aliases: ['enfermera', 'enfermero', 'licenciada'], prefill: 'nurse'),
      SpecField('cep', 'N° CEP', aliases: ['cep'], half: true),
    ]),
    SpecSection('Destino', [
      SpecField('medicoRegula', 'Médico de central que regula', aliases: ['médico regulador', 'médico de central']),
      SpecField('fichaRegulacion', 'N° ficha de regulación', aliases: ['ficha de regulación'], half: true),
      SpecField('establecimiento', 'Establecimiento de salud de destino', aliases: ['establecimiento de destino', 'establecimiento', 'hospital de destino', 'destino']),
      SpecField('codigoES', 'Código de E.S.', aliases: ['código del establecimiento'], half: true),
      SpecField('categoria', 'Categoría', aliases: ['categoría'], half: true),
      SpecField('profesionalAcepta', 'Profesional que acepta', aliases: ['profesional que acepta', 'acepta']),
      SpecField('medicoRecibe', 'Médico que recibe en el E.S.', aliases: ['médico que recibe', 'recibe']),
      SpecField('horaLlegadaES', 'Hora llegada al E.S.', kind: SpecKind.time, aliases: ['llegada al establecimiento', 'llegada al hospital'], half: true),
      SpecField('horaRecepcion', 'Hora de recepción del paciente', kind: SpecKind.time, aliases: ['recepción del paciente', 'hora de recepción'], half: true),
      SpecField('horaSalidaES', 'Hora salida del E.S.', kind: SpecKind.time, aliases: ['salida del establecimiento', 'salida del hospital'], half: true),
      SpecField('camillaRetenida', 'Camilla retenida', kind: SpecKind.choice, aliases: ['camilla retenida'], options: _yesNo, half: true),
      SpecField('camillaMinutos', 'Tiempo de camilla retenida', kind: SpecKind.integer, aliases: ['minutos de camilla', 'tiempo de camilla'], half: true, unit: 'min'),
    ]),
    SpecSection('Paciente / representante legal', [
      SpecField('representante', 'Nombres y apellidos', aliases: ['representante', 'familiar', 'representante legal']),
      SpecField('dniRepresentante', 'DNI', aliases: ['dni del representante', 'dni del familiar'], half: true),
      SpecField('parentesco', 'Parentesco', aliases: ['parentesco'], half: true),
      SpecField('pertenencias', 'Pertenencias del paciente', aliases: ['pertenencias']),
    ]),
  ],
);

// ---------------------------------------------------------------------------
// CENTRO REGULADOR DE URGENCIAS Y EMERGENCIAS (cuaderno de llamadas)
// ---------------------------------------------------------------------------

const crueSpec = FormSpec(
  type: FormType.crue,
  pdfTitle: 'CENTRO REGULADOR DE URGENCIAS Y EMERGENCIAS',
  banner: 'Un registro por llamada. Desde la lista genera el PDF del mes con todas las llamadas.',
  titleKey: 'paciente',
  subtitleKeys: ['nroCrue', 'sintomatologia'],
  sections: [
    SpecSection('Llamada', [
      SpecField('nroCrue', 'N° CRUE', aliases: ['número crue', 'crue', 'número de llamada'], half: true),
      SpecField('horaLlamada', 'Hora de la llamada', kind: SpecKind.time, aliases: ['hora de la llamada', 'hora de llamada'], half: true),
      SpecField('dniOperador', 'DNI del operador', aliases: ['dni del operador'], half: true),
      SpecField('operador', 'Nombres y apellidos del operador', aliases: ['operador', 'nombre del operador']),
    ]),
    SpecSection('Paciente', [
      SpecField('paciente', 'Nombres y apellidos', aliases: ['paciente', 'nombre del paciente', 'nombres y apellidos']),
      SpecField('edad', 'Edad', kind: SpecKind.integer, aliases: ['edad'], half: true, unit: 'años'),
      SpecField('dni', 'DNI', aliases: ['dni del paciente', 'dni'], half: true),
      SpecField('telefono', 'Teléfono de referencia', aliases: ['teléfono', 'celular', 'teléfono de referencia']),
    ]),
    SpecSection('Atención', [
      SpecField('tipoAtencion', 'Tipo de atención', kind: SpecKind.choice, aliases: ['tipo de atención', 'atención'], options: {
        'Foco': ['foco'], 'Frustro': ['frustro', 'frustrado'], 'Cancelado': ['cancelado'], 'Traslado': ['traslado'],
      }),
      SpecField('trasladoA', 'Traslado a', kind: SpecKind.choice, aliases: ['trasladado a', 'destino del traslado', 'destino'], options: {
        'MINSA': ['minsa', 'hospital'], 'EsSalud': ['essalud', 'es salud'], 'SP': ['sp', 'privado', 'clínica'],
      }),
      SpecField('distrito', 'Distrito', kind: SpecKind.choice, aliases: ['distrito'], options: {
        'Ilo': ['ilo'], 'Pacocha': ['pacocha'], 'El Algarrobal': ['algarrobal', 'el algarrobal'],
      }),
      SpecField('sector', 'Sector', aliases: ['sector']),
      SpecField('direccion', 'Dirección y referencia', aliases: ['dirección', 'dirección y referencia']),
    ]),
    SpecSection('Regulación', [
      SpecField('medico', 'Médico regulador', aliases: ['médico regulador', 'médico'], prefill: 'doctor'),
      SpecField('aph', 'APH', kind: SpecKind.choice, aliases: ['aph'], options: _yesNo, half: true),
      SpecField('covid', 'COVID-19', kind: SpecKind.choice, aliases: ['covid'], options: _yesNo, half: true),
      SpecField('transito', 'Accidente de tránsito', kind: SpecKind.choice, aliases: ['accidente de tránsito'], options: _yesNo, half: true),
      SpecField('prioridad', 'Prioridad', kind: SpecKind.choice, aliases: ['prioridad'], options: _priority, half: true),
      SpecField('seguro', 'Seguro', kind: SpecKind.choice, aliases: ['seguro'], options: {'SIS': ['sis'], 'EsSalud': ['essalud', 'es salud'], 'Otros': ['otro', 'otros', 'soat']}),
      SpecField('sintomatologia', 'Sintomatología', aliases: ['sintomatología', 'síntomas']),
      SpecField('cie10', 'CIE-10 presuntivo', aliases: ['cie', 'cie 10', 'diagnóstico presuntivo']),
    ]),
    SpecSection('Horas', [
      SpecField('horaDeriva', 'Hora deriva médico', kind: SpecKind.time, aliases: ['deriva médico', 'hora deriva'], half: true),
      SpecField('horaIndica', 'Hora indica ambulancia', kind: SpecKind.time, aliases: ['indica ambulancia', 'hora indica'], half: true),
      SpecField('horaSalida', 'Hora salida ambulancia', kind: SpecKind.time, aliases: ['salida ambulancia', 'salida de ambulancia', 'salida'], half: true),
      SpecField('horaLlegadaFoco', 'Hora llegada a foco', kind: SpecKind.time, aliases: ['llegada a foco', 'llegada al foco'], half: true),
      SpecField('horaSalidaFoco', 'Hora salida de foco', kind: SpecKind.time, aliases: ['salida de foco', 'salida del foco'], half: true),
      SpecField('horaLlegadaEESS', 'Hora llega a EE.SS.', kind: SpecKind.time, aliases: ['llegada al establecimiento', 'llegada al hospital', 'llega a establecimiento'], half: true),
      SpecField('horaLlegadaBase', 'Hora llegada a base', kind: SpecKind.time, aliases: ['llegada a base'], half: true),
    ]),
  ],
);

// ---------------------------------------------------------------------------
// REPORTE MÉDICO DIARIO
// ---------------------------------------------------------------------------

const reporteMedicoSpec = FormSpec(
  type: FormType.reporteMedico,
  pdfTitle: 'REPORTE MÉDICO DIARIO',
  banner: 'Un reporte por guardia. Para cada ocurrencia di «hora de ocurrencia 7 45, ocurrencia se acude a…»; la siguiente hora abre una nueva fila.',
  titleKey: 'medico',
  subtitleKeys: ['placa'],
  signatures: [('MÉDICO QUE ENTREGA EL TURNO', 'medico'), ('MÉDICO QUE RECIBE EL TURNO', 'medicoRecibe')],
  sections: [
    SpecSection('Unidad y equipo', [
      SpecField('tipoAmbulancia', 'Tipo de ambulancia', aliases: ['tipo de ambulancia'], half: true),
      SpecField('placa', 'Placa', aliases: ['placa'], half: true, prefill: 'plate'),
      SpecField('equipo', 'Equipo de trabajo N°', aliases: ['equipo de trabajo', 'equipo'], half: true),
      SpecField('medico', 'Médico', aliases: ['médico', 'doctor'], prefill: 'doctor'),
      SpecField('enfermero', 'Enfermero(a)', aliases: ['enfermera', 'enfermero', 'licenciada'], prefill: 'nurse'),
      SpecField('conductor', 'Conductor', aliases: ['conductor', 'piloto'], prefill: 'pilot'),
      SpecField('horaIngreso', 'Hora de ingreso', kind: SpecKind.time, aliases: ['hora de ingreso', 'ingreso'], half: true),
      SpecField('horaSalida', 'Hora de salida', kind: SpecKind.time, aliases: ['hora de salida'], half: true),
      SpecField('observaciones', 'Observaciones', aliases: ['observaciones']),
    ]),
    SpecSection('Ocurrencias y/o otras actividades realizadas', [
      SpecField('ocurrencias', 'Ocurrencias', kind: SpecKind.rows, rowLabel: 'Ocurrencia', fields: [
        SpecField('hora', 'Hora', kind: SpecKind.time, aliases: ['hora de ocurrencia', 'hora de la ocurrencia'], cutsText: true),
        SpecField('detalle', 'Detalle', kind: SpecKind.longText, aliases: ['ocurrencia', 'actividad']),
      ]),
      SpecField('pendientes', 'Pendientes', kind: SpecKind.longText, aliases: ['pendiente', 'pendientes']),
    ]),
    SpecSection('Cierre de la guardia', [
      SpecField('camillaHoras', 'Camilla retenida (horas)', kind: SpecKind.number, aliases: ['camilla retenida'], unit: 'h'),
      SpecField('efectivas', 'Atenciones efectivas', kind: SpecKind.integer, aliases: ['efectivas', 'atenciones efectivas'], half: true),
      SpecField('frustras', 'Frustras', kind: SpecKind.integer, aliases: ['frustras', 'frustradas'], half: true),
      SpecField('canceladas', 'Canceladas', kind: SpecKind.integer, aliases: ['canceladas'], half: true),
      SpecField('servEspec', 'Servicios especiales', kind: SpecKind.integer, aliases: ['servicios especiales', 'servicio especial'], half: true),
      SpecField('total', 'Total de atenciones', kind: SpecKind.integer, sumOf: ['efectivas', 'frustras', 'canceladas', 'servEspec']),
      SpecField('medicoRecibe', 'Médico que recibe el turno', aliases: ['médico que recibe', 'recibe el turno']),
    ]),
  ],
);

FormSpec? specFor(FormType t) => switch (t) {
      FormType.fichaAph => fichaAphSpec,
      FormType.crue => crueSpec,
      FormType.reporteMedico => reporteMedicoSpec,
      _ => null,
    };
