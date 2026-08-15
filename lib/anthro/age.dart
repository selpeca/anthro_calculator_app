/// Cálculo de edad y utilidades de fecha (dd/MM/yyyy), sin dependencias de Flutter.
///
/// Módulo puro y testeable. Ver `test/anthro/age_test.dart`.
library;

/// Edad de un paciente entre el nacimiento y la fecha de medición.
class Age {
  const Age({
    required this.days,
    required this.years,
    required this.months,
    required this.remDays,
  });

  /// Días cumplidos de vida. Es la clave con la que se consultan las tablas
  /// OMS 0–5 años (indexadas por día), nunca los meses redondeados.
  final int days;

  /// Desglose calendario: años, meses y días restantes.
  final int years;
  final int months;
  final int remDays;

  /// Edad decimal en meses, **solo para mostrar** (365.25 / 12 = 30.4375).
  double get decimalMonths => days / 30.4375;

  /// Meses completos (años·12 + meses), útil para reglas de posición.
  int get totalMonths => years * 12 + months;

  /// Etiqueta compacta tipo `'2 a 3 m 1 d'`, omitiendo componentes en cero.
  String get label {
    final parts = <String>[];
    if (years > 0) parts.add('$years a');
    if (months > 0) parts.add('$months m');
    if (remDays > 0) parts.add('$remDays d');
    if (parts.isEmpty) return '0 d';
    return parts.join(' ');
  }

  /// Detalle tipo `'823 días de vida · 27.0 meses'`.
  String get detail =>
      '$days días de vida · ${decimalMonths.toStringAsFixed(1)} meses';
}

/// Fecha sin componente horario (medianoche local).
DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// Días completos entre dos fechas, robusto ante horario de verano.
///
/// `DateTime.difference().inDays` sobre fechas locales puede errar por un día
/// al cruzar un cambio de horario (un día de 23 h se trunca). Se normaliza a
/// UTC para contar días de calendario reales.
int daysBetween(DateTime a, DateTime b) => DateTime.utc(b.year, b.month, b.day)
    .difference(DateTime.utc(a.year, a.month, a.day))
    .inDays;

/// Número de días del mes `month` del año `year` (1–12).
int daysInMonth(int year, int month) => DateTime(year, month + 1, 0).day;

/// Edad entre `birth` y `at`. Asume `at >= birth` (el llamador valida).
Age ageBetween(DateTime birth, DateTime at) {
  final b = dateOnly(birth);
  final a = dateOnly(at);
  final totalDays = daysBetween(b, a);

  var years = a.year - b.year;
  var months = a.month - b.month;
  var days = a.day - b.day;

  if (days < 0) {
    months -= 1;
    // Longitud del mes anterior a `a`.
    final prevMonth = a.month == 1 ? 12 : a.month - 1;
    final prevYear = a.month == 1 ? a.year - 1 : a.year;
    days += daysInMonth(prevYear, prevMonth);
  }
  if (months < 0) {
    years -= 1;
    months += 12;
  }

  return Age(days: totalDays, years: years, months: months, remDays: days);
}

/// Parsea `dd/MM/yyyy`. Devuelve `null` ante cualquier formato inválido.
///
/// Rechaza fechas imposibles (p. ej. `31/02/2025`): Dart normalizaría
/// silenciosamente `DateTime(2025, 2, 31)` a marzo, así que se compara el
/// resultado contra los componentes de entrada.
DateTime? parseDmy(String s) {
  final m = RegExp(r'^(\d{1,2})/(\d{1,2})/(\d{4})$').firstMatch(s.trim());
  if (m == null) return null;
  final d = int.parse(m.group(1)!);
  final mo = int.parse(m.group(2)!);
  final y = int.parse(m.group(3)!);
  if (mo < 1 || mo > 12 || d < 1 || d > 31) return null;
  final dt = DateTime(y, mo, d);
  if (dt.year != y || dt.month != mo || dt.day != d) return null;
  return dt;
}

/// Formatea a `dd/MM/yyyy` con ceros a la izquierda.
String formatDmy(DateTime d) {
  final dd = d.day.toString().padLeft(2, '0');
  final mm = d.month.toString().padLeft(2, '0');
  final yyyy = d.year.toString().padLeft(4, '0');
  return '$dd/$mm/$yyyy';
}
