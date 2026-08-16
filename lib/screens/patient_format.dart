/// Helpers de presentación para derivar de una medición guardada los textos de
/// las fichas de paciente (lista, detalle y resumen del home).
library;

import '../anthro/reference.dart';
import '../db/models.dart';
import '../theme.dart' show ClinicalStatus;

const List<String> _monthsShort = [
  'ene', 'feb', 'mar', 'abr', 'may', 'jun',
  'jul', 'ago', 'sep', 'oct', 'nov', 'dic',
];

const List<String> _monthsUpper = [
  'ENE', 'FEB', 'MAR', 'ABR', 'MAY', 'JUN',
  'JUL', 'AGO', 'SEP', 'OCT', 'NOV', 'DIC',
];

/// Iniciales del nombre (primera letra de las dos primeras palabras).
String initialsOf(String name) {
  final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
  if (parts.isEmpty) return '?';
  if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
  return (parts.first.substring(0, 1) + parts.last.substring(0, 1)).toUpperCase();
}

String sexLabel(Sex s) => s == Sex.female ? 'F' : 'M';

/// Etiqueta compacta de edad tipo `'2 a 3 m 1 d'`.
String ageLabel(int years, int months, int remDays) {
  final parts = <String>[];
  if (years > 0) parts.add('$years a');
  if (months > 0) parts.add('$months m');
  if (remDays > 0) parts.add('$remDays d');
  if (parts.isEmpty) return '0 d';
  return parts.join(' ');
}

String _fmt(double v) =>
    v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);

String zLabelOf(double? z) =>
    z == null ? '—' : '${z > 0 ? '+' : '−'}${z.abs().toStringAsFixed(3)}';

/// Resumen de una medición tipo `'12.4 kg · 86.5 cm · PC 44.1'`.
String measurementSummary(SavedMeasurement m) {
  final parts = ['${_fmt(m.weightKg)} kg', '${_fmt(m.statureCm)} cm'];
  if (m.headCircumferenceCm != null) {
    parts.add('PC ${_fmt(m.headCircumferenceCm!)}');
  }
  return parts.join(' · ');
}

/// Edad y estándar de una medición tipo `'2 a 3 m · 823 d · OMS 2006'`.
String measurementAgeLabel(SavedMeasurement m) =>
    '${ageLabel(m.ageYears, m.ageMonths, m.ageRemDays)} · '
    '${m.ageDays} d · ${m.standardLabel}';

int _severity(ClinicalStatus s) => switch (s) {
      ClinicalStatus.none => -1,
      ClinicalStatus.ok => 0,
      ClinicalStatus.warn => 1,
      ClinicalStatus.bad => 2,
      ClinicalStatus.severe => 3,
    };

/// El indicador interpretable "peor" de la medición (el que pinta la semaforía
/// del chip), o el primero si ninguno es interpretable.
SavedIndicator worstIndicator(SavedMeasurement m) {
  SavedIndicator? worst;
  for (final ind in m.indicators) {
    if (ind.status == ClinicalStatus.none) continue;
    if (worst == null || _severity(ind.status) > _severity(worst.status)) {
      worst = ind;
    }
  }
  return worst ?? m.indicators.first;
}

String shortIndicatorName(String name) => switch (name) {
      'Peso / Edad' => 'P/E',
      'Talla / Edad' => 'T/E',
      'Peso / Talla' => 'P/T',
      'IMC / Edad' => 'IMC/E',
      'Perímetro cefálico / Edad' => 'PC/E',
      _ => name,
    };

/// Meta de la fila de paciente: `'F · 2 a 3 m · 12.4 kg · 86.5 cm'`.
String patientMeta(SavedMeasurement? latest) {
  if (latest == null) return 'Sin mediciones';
  return '${sexLabel(latest.sex)} · '
      '${ageLabel(latest.ageYears, latest.ageMonths, latest.ageRemDays)} · '
      '${_fmt(latest.weightKg)} kg · ${_fmt(latest.statureCm)} cm';
}

/// Chip de la fila de paciente: `'Normal'` o el indicador peor con su Z.
String patientTag(SavedMeasurement? latest) {
  if (latest == null) return 'Sin datos';
  if (latest.overall == ClinicalStatus.ok) return 'Normal';
  final w = worstIndicator(latest);
  return '${shortIndicatorName(w.name)} ${zLabelOf(w.z)}';
}

/// Etiqueta relativa de la última medición: `'hoy'`, `'ayer'` o `'12 ago'`.
String relativeDateLabel(SavedMeasurement? latest, {DateTime? now}) {
  if (latest == null) return '—';
  final d = latest.measurementDate;
  final ref = now ?? DateTime.now();
  final day = DateTime(d.year, d.month, d.day);
  final today = DateTime(ref.year, ref.month, ref.day);
  final diff = today.difference(day).inDays;
  if (diff == 0) return 'hoy';
  if (diff == 1) return 'ayer';
  return '${day.day} ${_monthsShort[day.month - 1]}';
}

/// Fecha del historial tipo `'15 AGO 26'`.
String historyDateLabel(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')} '
    '${_monthsUpper[d.month - 1]} '
    '${(d.year % 100).toString().padLeft(2, '0')}';

/// Etiqueta corta del mes para las gráficas de trayectoria, tipo `'Feb'`.
String monthChartLabel(DateTime d) {
  final s = _monthsShort[d.month - 1];
  return '${s[0].toUpperCase()}${s.substring(1)}';
}
