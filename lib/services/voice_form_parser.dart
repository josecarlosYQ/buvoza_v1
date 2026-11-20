// Interpreta frases habladas del tipo «km inicio 120350 hora de salida diez y cuarto
// sirena inoperativa» y las reparte entre los campos de un formulario.
//
// Cada formulario declara sus campos con uno o varios nombres hablados (alias).
// El texto entre un alias y el siguiente es el valor de ese campo.

/// Un campo que se puede llenar por voz.
class VoiceField {
  VoiceField({
    required this.label,
    required this.aliases,
    required this.apply,
    this.hint = '',
    this.needsValue = true,
    this.optionalValue = false,
    this.freeText = false,
  });

  /// El valor puede faltar («nebulización» suma 1, «nebulización 3» suma 3).
  final bool optionalValue;

  /// Nombre que se muestra en la ayuda y en el resumen.
  final String label;

  /// Formas de nombrar el campo al hablar («km inicio», «kilometraje inicial»…).
  final List<String> aliases;

  /// Aplica el valor hablado. Devuelve el valor tal como quedó, o null si no se entendió.
  final String? Function(String value) apply;

  /// Ejemplo del valor para la ayuda («número», «hora», «operativo / inoperativo / falta»).
  final String hint;

  /// false para órdenes sin valor («guardar», «nueva emergencia»).
  final bool needsValue;

  /// Texto libre (observaciones, SOAPIE): dentro de él solo otro campo de texto libre
  /// corta el valor, para que palabras como «sirena» u «hospital» no se tomen como campos.
  final bool freeText;

  // ---- Constructores de uso frecuente ----

  static VoiceField text(String label, List<String> aliases, void Function(String) set, {bool freeText = false}) => VoiceField(
        label: label,
        aliases: aliases,
        freeText: freeText,
        hint: freeText ? 'texto libre' : 'texto',
        apply: (v) {
          final t = cleanText(v);
          if (t.isEmpty) return null;
          set(t);
          return t;
        },
      );

  static VoiceField number(String label, List<String> aliases, void Function(String) set, {bool integer = false}) => VoiceField(
        label: label,
        aliases: aliases,
        hint: 'número',
        apply: (v) {
          final n = spokenNumber(v);
          if (n == null) return null;
          final s = integer ? n.round().toString() : formatNumber(n);
          set(s);
          return s;
        },
      );

  static VoiceField time(String label, List<String> aliases, void Function(String) set, {DateTime Function()? now}) => VoiceField(
        label: label,
        aliases: aliases,
        hint: 'hora',
        apply: (v) {
          final t = spokenTime(v, now: now);
          if (t == null) return null;
          set(t);
          return t;
        },
      );

  /// [options]: valor guardado → formas de decirlo.
  static VoiceField choice(String label, List<String> aliases, Map<String, List<String>> options, void Function(String) set) => VoiceField(
        label: label,
        aliases: aliases,
        hint: options.keys.join(' / '),
        apply: (v) {
          final o = matchOption(v, options);
          if (o == null) return null;
          set(o);
          return o;
        },
      );

  static VoiceField command(String label, List<String> aliases, void Function() run) => VoiceField(
        label: label,
        aliases: aliases,
        needsValue: false,
        hint: 'orden',
        apply: (_) {
          run();
          return 'hecho';
        },
      );
}

/// Resultado de aplicar una frase.
class VoiceFillResult {
  final applied = <(String label, String value)>[];
  final failed = <(String label, String heard)>[];
  final unmatched = <String>[];
  bool get isEmpty => applied.isEmpty && failed.isEmpty;
}

/// Reparte [utterance] entre [fields] y aplica cada valor en orden.
VoiceFillResult applyUtterance(String utterance, List<VoiceField> fields) {
  final result = VoiceFillResult();
  final tokens = _tokenize(utterance);
  final matches = findFieldMentions(tokens, fields);

  if (matches.isEmpty) {
    if (utterance.trim().isNotEmpty) result.unmatched.add(utterance.trim());
    return result;
  }
  final lead = utterance.substring(0, tokens[matches.first.start].start).trim();
  if (_hasContent(lead)) result.unmatched.add(lead);

  for (var i = 0; i < matches.length; i++) {
    final m = matches[i];
    final valueStart = m.end < tokens.length ? tokens[m.end].start : utterance.length;
    final valueEnd = i + 1 < matches.length ? tokens[matches[i + 1].start].start : utterance.length;
    final value = valueStart < valueEnd ? utterance.substring(valueStart, valueEnd).trim() : '';
    final field = m.field;
    if (!field.needsValue && !field.optionalValue && _hasContent(value)) result.unmatched.add(value);
    if (field.needsValue && !field.optionalValue && !_hasContent(value)) {
      result.failed.add((field.label, ''));
      continue;
    }
    final applied = field.apply(value);
    if (applied == null) {
      result.failed.add((field.label, value));
    } else {
      result.applied.add((field.label, applied));
    }
  }
  return result;
}

class FieldMention {
  FieldMention(this.field, this.start, this.end);
  final VoiceField field;
  final int start, end; // índices de token [start, end)
}

/// Busca de izquierda a derecha los alias de los campos, prefiriendo el más largo.
List<FieldMention> findFieldMentions(List<Token> tokens, List<VoiceField> fields) {
  final aliases = <(List<String>, VoiceField)>[
    for (final f in fields)
      for (final a in f.aliases)
        if (_tokenize(a).where((t) => !_fillers.contains(t.norm)).isNotEmpty)
          ([for (final t in _tokenize(a)) if (!_fillers.contains(t.norm)) t.norm], f),
  ]..sort((a, b) => b.$1.length.compareTo(a.$1.length));

  final out = <FieldMention>[];
  var insideFree = false;
  var i = 0;
  while (i < tokens.length) {
    FieldMention? best;
    if (!_fillers.contains(tokens[i].norm)) {
      for (final (words, field) in aliases) {
        if (insideFree && field.needsValue && !field.freeText) continue;
        final end = _matchAt(tokens, i, words);
        if (end != null && (best == null || end > best.end)) best = FieldMention(field, i, end);
      }
    }
    // «hospital Hospital de Ilo»: el mismo campo justo después de nombrarlo es parte del valor.
    if (best != null && out.isNotEmpty && identical(out.last.field, best.field) && out.last.end == best.start) {
      i = best.end;
      continue;
    }
    if (best != null) {
      out.add(best);
      insideFree = best.field.freeText;
      i = best.end;
    } else {
      i++;
    }
  }
  return out;
}

int? _matchAt(List<Token> tokens, int start, List<String> words) {
  var j = start;
  for (var w = 0; w < words.length; w++) {
    if (w > 0) {
      while (j < tokens.length && _fillers.contains(tokens[j].norm) && tokens[j].norm != words[w]) {
        j++;
      }
    }
    if (j >= tokens.length || tokens[j].norm != words[w]) return null;
    j++;
  }
  return j;
}

// ---------------------------------------------------------------------------
// Normalización

class Token {
  Token(this.text, this.start, this.end) : norm = normalizeWord(text);
  final String text;
  final int start, end;
  final String norm;
}

/// Palabras con signos internos («10:15», «120/80», «36.5») cuentan como una sola.
final _wordPattern = RegExp(r"[\p{L}\p{N}°³ºª]+(?:[/:.,'-][\p{L}\p{N}°³ºª]+)*", unicode: true);

List<Token> _tokenize(String s) => [for (final m in _wordPattern.allMatches(s)) Token(m.group(0)!, m.start, m.end)];

/// Palabras de relleno que se saltan al buscar nombres de campo (ya normalizadas).
/// Las unidades («balón de 7 metros cúbicos») también se saltan entre las palabras de un nombre.
final _fillers = {
  'de', 'del', 'la', 'el', 'los', 'las', 'y', 'en', 'con', 'al', 'a', 'es', 'por', 'para', 'su', 'un', 'una',
  'metro', 'metros', 'cubico', 'cubicos', 'm3', 'm³',
}.map(normalizeWord).toSet();

String stripAccents(String s) {
  const from = 'áàäâéèëêíìïîóòöôúùüûñÁÀÄÂÉÈËÊÍÌÏÎÓÒÖÔÚÙÜÛÑ';
  const to = 'aaaaeeeeiiiioooouuuunAAAAEEEEIIIIOOOOUUUUN';
  final b = StringBuffer();
  for (final ch in s.split('')) {
    final i = from.indexOf(ch);
    b.write(i < 0 ? ch : to[i]);
  }
  return b.toString();
}

const _wordSynonyms = {
  'kilometro': 'km', 'kilometros': 'km', 'kilometraje': 'km', 'kms': 'km',
  'nro': 'numero', 'n°': 'numero', 'no.': 'numero', 'num': 'numero',
  'der': 'derecho', 'izq': 'izquierdo', 'lat': 'lateral', 'post': 'posterior', 'del.': 'delantero',
  'hrs': 'hora', 'horas': 'hora', 'hr': 'hora',
  'saturacion': 'spo2', 'sat': 'spo2', 'oxigenacion': 'spo2',
  'uno': '1', 'dos': '2', 'tres': '3', 'cuatro': '4', 'cinco': '5', 'seis': '6', 'siete': '7', 'ocho': '8', 'nueve': '9', 'diez': '10',
  'doce': '12', 'veinte': '20',
  'kilo': 'kg', 'kilos': 'kg', 'kilogramos': 'kg', 'kilogramo': 'kg',
};

/// Nivel de combustible en décimos: «8», «tanque lleno», «medio tanque», «tres cuartos», «reserva».
int? spokenFuelLevel(String v) {
  final s = ' ${stripAccents(v.toLowerCase())} ';
  if (RegExp(r'\b(lleno|full)\b').hasMatch(s)) return 10;
  if (s.contains('tres cuartos')) return 8;
  if (RegExp(r'\b(medio|mitad)\b').hasMatch(s)) return 5;
  if (RegExp(r'\bcuarto\b').hasMatch(s)) return 3;
  if (RegExp(r'\breserva\b').hasMatch(s)) return 1;
  if (RegExp(r'\bvacio\b').hasMatch(s)) return 0;
  final n = spokenNumber(v);
  if (n == null) return null;
  // «80 por ciento» → 8/10.
  if (n > 10 && n <= 100 && RegExp(r'(%|por ?ciento)').hasMatch(s)) return (n / 10).round();
  return n >= 0 && n <= 10 ? n.round() : null;
}

/// Forma comparable de una palabra: minúsculas, sin tildes, sinónimos y sin plural ni género.
String normalizeWord(String w) {
  var s = stripAccents(w.toLowerCase()).replaceAll(RegExp(r'[.,:;]+$'), '');
  s = _wordSynonyms[s] ?? s;
  if (RegExp(r'^\d').hasMatch(s)) return s.replaceAll(RegExp(r'[^\d]'), '');
  if (s.length > 4 && s.endsWith('es') && !s.endsWith('ces')) s = s.substring(0, s.length - 2);
  if (s.length > 4 && s.endsWith('ces')) s = '${s.substring(0, s.length - 3)}z';
  if (s.length > 3 && s.endsWith('s')) s = s.substring(0, s.length - 1);
  if (s.length > 3 && (s.endsWith('a') || s.endsWith('o') || s.endsWith('e'))) s = s.substring(0, s.length - 1);
  return s;
}

/// Frase normalizada palabra por palabra (para comparar opciones).
String normalizePhrase(String s) => _tokenize(s).map((t) => t.norm).where((w) => !_fillers.contains(w)).join(' ');

bool _hasContent(String s) => _tokenize(s).any((t) => !_fillers.contains(t.norm));

/// Quita muletillas al inicio («es», «a», «:») y pone mayúscula inicial.
String cleanText(String v) {
  var t = v.trim().replaceAll(RegExp(r'^[,.:;\s]+|[,;:\s]+$'), '');
  t = t.replaceFirst(RegExp(r'^(es|son|está|a|de|el|la|:)\s+', caseSensitive: false), '');
  t = t.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (t.endsWith('.')) t = t.substring(0, t.length - 1);
  return t.isEmpty ? t : t[0].toUpperCase() + t.substring(1);
}

/// Elige la opción cuya forma hablada aparece en [v] (la más larga gana).
String? matchOption(String v, Map<String, List<String>> options) {
  final heard = ' ${normalizePhrase(v)} ';
  String? best;
  var bestLen = 0;
  for (final o in options.entries) {
    for (final spoken in [o.key, ...o.value]) {
      final n = normalizePhrase(spoken);
      if (n.isNotEmpty && heard.contains(' $n ') && n.length > bestLen) {
        best = o.key;
        bestLen = n.length;
      }
    }
  }
  return best;
}

// ---------------------------------------------------------------------------
// Números

const _units = {
  'cero': 0, 'un': 1, 'uno': 1, 'una': 1, 'dos': 2, 'tres': 3, 'cuatro': 4, 'cinco': 5, 'seis': 6, 'siete': 7, 'ocho': 8, 'nueve': 9,
  'diez': 10, 'once': 11, 'doce': 12, 'trece': 13, 'catorce': 14, 'quince': 15, 'dieciseis': 16, 'diecisiete': 17, 'dieciocho': 18,
  'diecinueve': 19, 'veinte': 20, 'veintiun': 21, 'veintiuno': 21, 'veintiuna': 21, 'veintidos': 22, 'veintitres': 23, 'veinticuatro': 24,
  'veinticinco': 25, 'veintiseis': 26, 'veintisiete': 27, 'veintiocho': 28, 'veintinueve': 29, 'treinta': 30, 'cuarenta': 40,
  'cincuenta': 50, 'sesenta': 60, 'setenta': 70, 'ochenta': 80, 'noventa': 90, 'cien': 100, 'ciento': 100, 'doscientos': 200,
  'doscientas': 200, 'trescientos': 300, 'trescientas': 300, 'cuatrocientos': 400, 'cuatrocientas': 400, 'quinientos': 500,
  'quinientas': 500, 'seiscientos': 600, 'seiscientas': 600, 'setecientos': 700, 'setecientas': 700, 'ochocientos': 800,
  'ochocientas': 800, 'novecientos': 900, 'novecientas': 900,
};

/// Primer número de [v], dicho con cifras («120.350», «36,5») o con palabras
/// («ciento veinte mil trescientos», «treinta y seis punto cinco»).
double? spokenNumber(String v) {
  final words = stripAccents(v.toLowerCase())
      .split(RegExp(r'\s+'))
      .map((w) => w.replaceAll(RegExp(r'^[^\w]+|[^\w]+$'), ''))
      .where((w) => w.isNotEmpty)
      .toList();

  double? intPart;
  double total = 0, current = 0;
  var started = false, lastDigits = false;
  String? decimals;

  for (var i = 0; i < words.length; i++) {
    final w = words[i];
    final digits = _digitValue(w);
    if (digits != null) {
      if (digits.contains('.')) {
        // «36.5» con decimales: es el número completo.
        if (started) break;
        return double.tryParse(digits);
      }
      // «120 350»: el reconocedor a veces separa los miles con un espacio.
      final value = double.parse(digits);
      current = lastDigits && RegExp(r'^\d{3}$').hasMatch(digits) ? current * 1000 + value : current + value;
      started = lastDigits = true;
      continue;
    } else if (_units.containsKey(w)) {
      current += _units[w]!;
      started = true;
    } else if (w == 'mil' && started) {
      total += (current == 0 ? 1 : current) * 1000;
      current = 0;
    } else if (w == 'mil' && !started) {
      total += 1000;
      started = true;
    } else if ((w == 'punto' || w == 'coma') && started && i + 1 < words.length) {
      intPart = total + current;
      final rest = <String>[];
      for (var j = i + 1; j < words.length; j++) {
        final d = _digitValue(words[j]) ?? (_units.containsKey(words[j]) ? _units[words[j]]!.toString() : null);
        if (d == null) break;
        rest.add(d);
        if (_digitValue(words[j]) != null) break;
      }
      if (rest.isNotEmpty) decimals = rest.join();
      break;
    } else if (w == 'y' && started) {
      continue;
    } else if (w == 'menos' && !started) {
      final n = spokenNumber(words.sublist(i + 1).join(' '));
      return n == null ? null : -n;
    } else if (started) {
      break;
    }
    lastDigits = false;
  }
  if (!started) return null;
  final whole = intPart ?? (total + current);
  return decimals == null ? whole : double.tryParse('${whole.toInt()}.$decimals');
}

/// Cifras de una palabra: «120.350» → 120350, «36,5» → 36.5, «2000psi» → 2000.
String? _digitValue(String w) {
  final m = RegExp(r'^-?\d[\d.,]*').firstMatch(w);
  if (m == null) return null;
  var s = m.group(0)!;
  if (RegExp(r'^\d{1,3}([.,]\d{3})+$').hasMatch(s)) return s.replaceAll(RegExp(r'[.,]'), '');
  s = s.replaceAll(',', '.');
  if ('.'.allMatches(s).length > 1) s = s.replaceAll('.', '');
  return s.endsWith('.') ? s.substring(0, s.length - 1) : s;
}

String formatNumber(double n) => n == n.roundToDouble() ? n.toInt().toString() : n.toString();

/// Presión arterial: «120 sobre 80», «ciento veinte ochenta», «120/80».
String? spokenPressure(String v) {
  final direct = RegExp(r'(\d{2,3})\s*[/x-]\s*(\d{2,3})').firstMatch(v);
  if (direct != null) return '${direct.group(1)}/${direct.group(2)}';
  final parts = stripAccents(v.toLowerCase()).split(RegExp(r'\b(sobre|entre|con)\b'));
  if (parts.length >= 2) {
    final a = spokenNumber(parts[0]), b = spokenNumber(parts[1]);
    if (a != null && b != null) return '${a.round()}/${b.round()}';
  }
  final nums = RegExp(r'\d{2,3}').allMatches(v).map((m) => m.group(0)).toList();
  if (nums.length >= 2) return '${nums[0]}/${nums[1]}';
  return null;
}

// ---------------------------------------------------------------------------
// Horas

/// Hora en formato 24 h: «10:15», «10 y 15», «diez y cuarto», «las 8 y media de la noche»,
/// «ocho menos cuarto», «20 horas», «ahora».
String? spokenTime(String v, {DateTime Function()? now}) {
  final s = stripAccents(v.toLowerCase()).replaceAll(RegExp(r'p\.\s*m\.?'), ' pm ').replaceAll(RegExp(r'a\.\s*m\.?'), ' am ');
  if (RegExp(r'\b(ahora|actual|ya)\b').hasMatch(s)) {
    final t = (now ?? DateTime.now)();
    return _hhmm(t.hour, t.minute);
  }
  int? hour, minute;
  // «10:15», «10.15», «10h15» y también «7 46» (el reconocedor a veces omite los dos puntos).
  final clock = RegExp(r'\b(\d{1,2})\s*[:h.]\s*(\d{2})\b').firstMatch(s) ?? RegExp(r'^\D*\b(\d{1,2})\s+(\d{2})\b').firstMatch(s);
  if (clock != null) {
    hour = int.parse(clock.group(1)!);
    minute = int.parse(clock.group(2)!);
  } else {
    // Separa la hora de los minutos por «y», «con», «menos» u «horas».
    final m = RegExp(r'^(.*?)\b(y|con|menos|horas?)\b(.*)$').firstMatch(s);
    final hourText = m?.group(1) ?? s;
    hour = spokenNumber(hourText.replaceAll(RegExp(r'\b(las|la|a)\b'), ''))?.round();
    if (hour == null) return null;
    final sep = m?.group(2);
    final rest = (m?.group(3) ?? '').trim();
    var mins = 0;
    if (rest.contains('media')) {
      mins = 30;
    } else if (rest.contains('cuarto')) {
      mins = 15;
    } else {
      final n = spokenNumber(rest.replaceFirst(RegExp(r'^(y|con)\b'), ''));
      // «20 horas 15»: los minutos vienen tras «horas».
      mins = n == null || n >= 60 ? 0 : n.round();
    }
    if (sep == 'menos') {
      hour = (hour - 1) % 24;
      mins = 60 - mins;
      if (mins == 60) mins = 0;
    }
    minute = mins;
  }
  if (hour > 23 || minute > 59) return null;
  final pm = RegExp(r'\b(pm|tarde|noche)\b').hasMatch(s);
  final midnightish = RegExp(r'\b(madrugada)\b').hasMatch(s);
  final night = RegExp(r'\bnoche\b').hasMatch(s);
  if (pm && hour < 12 && !(night && hour <= 4)) hour += 12;
  if (night && hour == 12) hour = 0;
  if (RegExp(r'\b(am|manana)\b').hasMatch(s) && hour == 12) hour = 0;
  if (midnightish && hour == 12) hour = 0;
  return _hhmm(hour, minute);
}

String _hhmm(int h, int m) => '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';

// ---------------------------------------------------------------------------
// Fechas

const _months = {
  'enero': 1, 'febrero': 2, 'marzo': 3, 'abril': 4, 'mayo': 5, 'junio': 6, 'julio': 7, 'agosto': 8,
  'septiembre': 9, 'setiembre': 9, 'octubre': 10, 'noviembre': 11, 'diciembre': 12,
};

/// «hoy», «ayer», «anteayer», «5 de octubre», «05/10», «cinco de octubre del 2026».
DateTime? spokenDate(String v, {DateTime? today}) {
  final base = today ?? DateTime.now();
  final d0 = DateTime(base.year, base.month, base.day);
  final s = stripAccents(v.toLowerCase());
  if (RegExp(r'\banteayer\b').hasMatch(s)) return d0.subtract(const Duration(days: 2));
  if (RegExp(r'\bayer\b').hasMatch(s)) return d0.subtract(const Duration(days: 1));
  if (RegExp(r'\bhoy\b').hasMatch(s)) return d0;
  final numeric = RegExp(r'\b(\d{1,2})[/-](\d{1,2})(?:[/-](\d{2,4}))?\b').firstMatch(s);
  if (numeric != null) {
    var y = int.tryParse(numeric.group(3) ?? '') ?? base.year;
    if (y < 100) y += 2000;
    return _validDate(y, int.parse(numeric.group(2)!), int.parse(numeric.group(1)!));
  }
  for (final m in _months.entries) {
    final idx = s.indexOf(m.key);
    if (idx < 0) continue;
    final day = spokenNumber(s.substring(0, idx).replaceAll(RegExp(r'\b(el|dia|de)\b'), ''))?.round();
    if (day == null) return null;
    final yearMatch = RegExp(r'\b(20\d{2})\b').firstMatch(s.substring(idx));
    return _validDate(yearMatch == null ? base.year : int.parse(yearMatch.group(1)!), m.value, day);
  }
  return null;
}

DateTime? _validDate(int y, int m, int d) {
  if (m < 1 || m > 12 || d < 1) return null;
  final date = DateTime(y, m, d);
  return date.month == m ? date : null;
}
