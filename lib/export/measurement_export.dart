/// Exporta mediciones guardadas a CSV y las entrega por la hoja de compartir
/// nativa (share_plus).
///
/// El armado del CSV ([buildMeasurementsCsv] / [buildSingleMeasurementCsv]) es
/// una función pura y testeable; la capa de IO + UI ([shareCsv] y los
/// envoltorios `export*`) se mantiene separada para poder verificar la
/// serialización sin depender de plataforma.
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../anthro/indicators.dart';
import '../anthro/reference.dart';
import '../data.dart';
import '../db/models.dart';
import '../screens/patient_format.dart' show ageLabel, sexLabel, shortIndicatorName;

/// Orden canónico de indicadores para aplanar cada medición en columnas fijas.
/// Coincide con los nombres almacenados (`SavedIndicator.name` / `Indicator.name`).
const List<String> _indicatorOrder = [
  'Peso / Edad',
  'Talla / Edad',
  'Peso / Talla',
  'IMC / Edad',
  'Perímetro cefálico / Edad',
];

// ---------------------------------------------------------------------------
// Armado del CSV (puro)
// ---------------------------------------------------------------------------

/// CSV de una lista de mediciones guardadas (una fila por medición).
/// Usado por "Exportar" (todas) y "Exportar ficha" (historial de un paciente).
String buildMeasurementsCsv(List<SavedMeasurement> measurements) {
  final rows = [for (final m in measurements) _cells(_rowFromSaved(m))];
  return _csvFromRows(_header(), rows);
}

/// CSV de una sola medición reconstruida desde el par entrada/resultado
/// (pantalla de resultados, que aún no tiene una `SavedMeasurement`).
String buildSingleMeasurementCsv({
  required AnthroInput input,
  required AnthroResult result,
  String? patientName,
}) {
  final name = _cleanName(patientName);
  return _csvFromRows(_header(), [_cells(_rowFromResult(input, result, name))]);
}

/// Fila normalizada común a ambos orígenes (SavedMeasurement / input+result).
class _Row {
  const _Row({
    required this.patientName,
    required this.birthDate,
    required this.measurementDate,
    required this.sex,
    required this.position,
    required this.standardLabel,
    required this.weightKg,
    required this.statureCm,
    required this.headCircumferenceCm,
    required this.bmi,
    required this.ageYears,
    required this.ageMonths,
    required this.ageRemDays,
    required this.ageDays,
    required this.overallLabel,
    required this.indicators,
  });

  final String patientName;
  final DateTime birthDate;
  final DateTime measurementDate;
  final Sex sex;
  final MeasurePosition position;
  final String standardLabel;
  final double weightKg;
  final double statureCm;
  final double? headCircumferenceCm;
  final double? bmi;
  final int ageYears;
  final int ageMonths;
  final int ageRemDays;
  final int ageDays;
  final String overallLabel;

  /// Indicadores de la medición indexados por nombre.
  final Map<String, ({double? z, String classification})> indicators;
}

_Row _rowFromSaved(SavedMeasurement m) => _Row(
      patientName: m.patientName,
      birthDate: m.birthDate,
      measurementDate: m.measurementDate,
      sex: m.sex,
      position: m.position,
      standardLabel: m.standardLabel,
      weightKg: m.weightKg,
      statureCm: m.statureCm,
      headCircumferenceCm: m.headCircumferenceCm,
      bmi: m.bmi,
      ageYears: m.ageYears,
      ageMonths: m.ageMonths,
      ageRemDays: m.ageRemDays,
      ageDays: m.ageDays,
      overallLabel: m.overallLabel,
      indicators: {
        for (final i in m.indicators)
          i.name: (z: i.z, classification: i.classification),
      },
    );

_Row _rowFromResult(AnthroInput input, AnthroResult result, String patientName) =>
    _Row(
      patientName: patientName,
      birthDate: input.birthDate,
      measurementDate: input.measurementDate,
      sex: result.sex,
      position: input.position,
      standardLabel: result.standardLabel,
      weightKg: result.weightKg,
      statureCm: result.statureCm,
      headCircumferenceCm: result.headCircumferenceCm,
      bmi: result.bmi,
      ageYears: result.age.years,
      ageMonths: result.age.months,
      ageRemDays: result.age.remDays,
      ageDays: result.age.days,
      overallLabel: result.overallLabel,
      indicators: {
        for (final i in result.indicators)
          i.name: (z: i.z, classification: i.classification),
      },
    );

List<String> _header() => <String>[
      'Paciente',
      'Fecha medición',
      'Fecha nacimiento',
      'Sexo',
      'Edad',
      'Edad (días)',
      'Posición',
      'Estándar',
      'Peso (kg)',
      'Talla (cm)',
      'PC (cm)',
      'IMC',
      'Estado general',
      for (final name in _indicatorOrder) ...[
        '${shortIndicatorName(name)} Z',
        '${shortIndicatorName(name)} Clasif',
      ],
    ];

List<String> _cells(_Row r) {
  final cells = <String>[
    r.patientName,
    _isoDate(r.measurementDate),
    _isoDate(r.birthDate),
    sexLabel(r.sex),
    ageLabel(r.ageYears, r.ageMonths, r.ageRemDays),
    '${r.ageDays}',
    _positionLabel(r.position),
    r.standardLabel,
    _num(r.weightKg),
    _num(r.statureCm),
    r.headCircumferenceCm == null ? '' : _num(r.headCircumferenceCm!),
    r.bmi == null ? '' : r.bmi!.toStringAsFixed(1),
    r.overallLabel,
  ];
  for (final name in _indicatorOrder) {
    final ind = r.indicators[name];
    // Signo ASCII y sin '+' para que Excel/Sheets lo lean como número.
    cells.add(ind?.z == null ? '' : ind!.z!.toStringAsFixed(3));
    cells.add(ind?.classification ?? '');
  }
  return cells;
}

/// Une filas en un CSV con escapado manual (comas, comillas, saltos de línea) y
/// BOM UTF-8 al inicio para que Excel abra los acentos correctamente.
String _csvFromRows(List<String> header, List<List<String>> rows) {
  final buf = StringBuffer('﻿');
  buf.write(header.map(_escape).join(','));
  buf.write('\r\n');
  for (final row in rows) {
    buf.write(row.map(_escape).join(','));
    buf.write('\r\n');
  }
  return buf.toString();
}

String _escape(String field) {
  if (field.contains(',') ||
      field.contains('"') ||
      field.contains('\n') ||
      field.contains('\r')) {
    return '"${field.replaceAll('"', '""')}"';
  }
  return field;
}

String _isoDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

/// Entero sin decimales, en caso contrario un decimal (ASCII, mismo criterio
/// que la presentación de la app).
String _num(double v) =>
    v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);

String _positionLabel(MeasurePosition p) =>
    p == MeasurePosition.lying ? 'Acostado' : 'De pie';

String _cleanName(String? name) {
  final trimmed = name?.trim() ?? '';
  return trimmed.isEmpty ? 'Paciente' : trimmed;
}

// ---------------------------------------------------------------------------
// IO + compartir
// ---------------------------------------------------------------------------

/// Escribe el CSV en un archivo temporal y abre la hoja de compartir nativa.
Future<void> shareCsv(
  BuildContext context, {
  required String csv,
  required String fileBaseName,
}) async {
  final origin = _shareOrigin(context);
  final name = '${_sanitize(fileBaseName)}_${_stamp(DateTime.now())}.csv';
  final dir = await getTemporaryDirectory();
  final file = File('${dir.path}/$name');
  await file.writeAsString(csv);
  await SharePlus.instance.share(ShareParams(
    files: [XFile(file.path, mimeType: 'text/csv', name: name)],
    subject: name,
    sharePositionOrigin: origin,
  ));
}

/// Exporta TODAS las mediciones recibidas (pantalla de pacientes).
Future<void> exportAllMeasurements(
    BuildContext context, List<SavedMeasurement> measurements) async {
  if (measurements.isEmpty) {
    _snack(context, 'No hay mediciones para exportar');
    return;
  }
  final csv = buildMeasurementsCsv(measurements);
  if (!context.mounted) return;
  await _guardShare(context, csv: csv, fileBaseName: 'mediciones');
}

/// Exporta el historial completo de un paciente (ficha).
Future<void> exportPatientFicha(
  BuildContext context, {
  required String name,
  required List<SavedMeasurement> history,
}) async {
  if (history.isEmpty) {
    _snack(context, 'Este paciente no tiene mediciones para exportar');
    return;
  }
  final csv = buildMeasurementsCsv(history);
  if (!context.mounted) return;
  await _guardShare(context, csv: csv, fileBaseName: 'ficha_$name');
}

/// Exporta la medición individual mostrada en resultados.
Future<void> exportSingleMeasurement(
  BuildContext context, {
  required AnthroInput input,
  required AnthroResult result,
  String? patientName,
}) async {
  final csv =
      buildSingleMeasurementCsv(input: input, result: result, patientName: patientName);
  final trimmed = patientName?.trim() ?? '';
  final base = trimmed.isEmpty ? 'medicion' : 'medicion_$trimmed';
  await _guardShare(context, csv: csv, fileBaseName: base);
}

Future<void> _guardShare(
  BuildContext context, {
  required String csv,
  required String fileBaseName,
}) async {
  try {
    await shareCsv(context, csv: csv, fileBaseName: fileBaseName);
  } catch (e) {
    if (context.mounted) _snack(context, 'No se pudo exportar: $e');
  }
}

/// Origen del popover de compartir (necesario en iPad); `null` si no aplica.
Rect? _shareOrigin(BuildContext context) {
  final box = context.findRenderObject() as RenderBox?;
  if (box == null || !box.hasSize) return null;
  return box.localToGlobal(Offset.zero) & box.size;
}

String _stamp(DateTime d) =>
    '${d.year}${_pad2(d.month)}${_pad2(d.day)}_${_pad2(d.hour)}${_pad2(d.minute)}';

String _pad2(int v) => v.toString().padLeft(2, '0');

String _sanitize(String s) {
  final cleaned = s
      .trim()
      .replaceAll(RegExp(r'[^A-Za-z0-9]+'), '_')
      .replaceAll(RegExp(r'^_+|_+$'), '');
  return cleaned.isEmpty ? 'export' : cleaned;
}

void _snack(BuildContext context, String msg) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
}
