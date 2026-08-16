/// Importa mediciones desde un CSV con la misma estructura que produce la
/// exportación (`lib/export/measurement_export.dart`).
///
/// Solo se leen las columnas "crudas" (paciente, fechas, sexo, posición,
/// estándar, peso, talla, PC): los indicadores (Z, clasificación) se
/// **recalculan** con el mismo motor de la app en vez de confiar en los valores
/// redondeados del archivo. Cada fila se guarda con
/// [AnthroDatabase.saveMeasurement], que agrupa por nombre de paciente
/// (get-or-create, insensible a mayúsculas).
///
/// El parseo ([parseMeasurementsCsv]) es puro y testeable; la selección de
/// archivo ([pickAndParseCsv]) y el guardado ([importMeasurements]) tocan
/// plataforma/BD.
library;

import 'dart:convert';

import 'package:file_picker/file_picker.dart';

import '../anthro/age.dart' show parseDmy;
import '../anthro/indicators.dart';
import '../anthro/reference.dart';
import '../data.dart';
import '../db/database.dart';
import '../reference/reference_repository.dart';

/// Una fila válida del CSV, lista para calcular y guardar.
class ImportRow {
  const ImportRow(this.patientName, this.input);
  final String patientName;
  final AnthroInput input;
}

/// Resultado de parsear el CSV: filas válidas y mensajes de error por fila.
class ImportParse {
  const ImportParse(this.rows, this.errors);
  final List<ImportRow> rows;
  final List<String> errors;
}

// ---------------------------------------------------------------------------
// Parseo (puro)
// ---------------------------------------------------------------------------

/// Convierte el contenido del CSV en filas importables. [standardIdForLabel]
/// resuelve el nombre visible del estándar (columna "Estándar") a su id; se
/// inyecta para poder probar sin `ReferenceRepository`.
ImportParse parseMeasurementsCsv(
  String csv, {
  required String? Function(String label) standardIdForLabel,
}) {
  final records = _parseCsv(csv);
  if (records.isEmpty) {
    return const ImportParse([], ['El archivo está vacío']);
  }

  final header = records.first.map((h) => h.trim()).toList();
  int col(String name) => header.indexOf(name);

  final iName = col('Paciente');
  final iMeas = col('Fecha medición');
  final iBirth = col('Fecha nacimiento');
  final iSex = col('Sexo');
  final iPos = col('Posición');
  final iStd = col('Estándar');
  final iWeight = col('Peso (kg)');
  final iStature = col('Talla (cm)');
  final iPc = col('PC (cm)');

  final missing = <String>[
    if (iName < 0) 'Paciente',
    if (iMeas < 0) 'Fecha medición',
    if (iBirth < 0) 'Fecha nacimiento',
    if (iSex < 0) 'Sexo',
    if (iStd < 0) 'Estándar',
    if (iWeight < 0) 'Peso (kg)',
    if (iStature < 0) 'Talla (cm)',
  ];
  if (missing.isNotEmpty) {
    return ImportParse(
        const [], ['Cabecera no reconocida; faltan columnas: ${missing.join(', ')}']);
  }

  final rows = <ImportRow>[];
  final errors = <String>[];
  for (var r = 1; r < records.length; r++) {
    final rec = records[r];
    if (rec.every((c) => c.trim().isEmpty)) continue; // fila en blanco
    String cell(int i) => (i >= 0 && i < rec.length) ? rec[i].trim() : '';
    final line = r + 1; // línea "humana" (1-based, con cabecera)

    final name = cell(iName);
    if (name.isEmpty) {
      errors.add('Fila $line: falta el nombre del paciente');
      continue;
    }

    final birth = _parseDate(cell(iBirth));
    final meas = _parseDate(cell(iMeas));
    if (birth == null || meas == null) {
      errors.add('Fila $line: fecha inválida');
      continue;
    }
    if (meas.isBefore(birth)) {
      errors.add('Fila $line: la medición es anterior al nacimiento');
      continue;
    }

    final sex = _parseSex(cell(iSex));
    if (sex == null) {
      errors.add('Fila $line: sexo no reconocido "${cell(iSex)}"');
      continue;
    }

    final weight = _parseNum(cell(iWeight));
    final stature = _parseNum(cell(iStature));
    if (weight == null || weight <= 0 || stature == null || stature <= 0) {
      errors.add('Fila $line: peso o talla inválidos');
      continue;
    }

    final stdLabel = cell(iStd);
    final standardId = standardIdForLabel(stdLabel);
    if (standardId == null) {
      errors.add('Fila $line: estándar no reconocido "$stdLabel"');
      continue;
    }

    rows.add(ImportRow(
      name,
      AnthroInput(
        birthDate: birth,
        measurementDate: meas,
        sex: sex,
        weightKg: weight,
        statureCm: stature,
        position: _parsePosition(iPos >= 0 ? cell(iPos) : ''),
        headCircumferenceCm: iPc >= 0 ? _parseNum(cell(iPc)) : null,
        standardId: standardId,
      ),
    ));
  }
  return ImportParse(rows, errors);
}

/// Parser CSV mínimo (RFC 4180): comillas con `""` escapadas, comas y saltos de
/// línea dentro de comillas, filas separadas por `\r\n` o `\n`, BOM inicial.
List<List<String>> _parseCsv(String text) {
  var s = text;
  if (s.isNotEmpty && s.codeUnitAt(0) == 0xFEFF) s = s.substring(1); // BOM
  final rows = <List<String>>[];
  var row = <String>[];
  var field = StringBuffer();
  var inQuotes = false;
  var i = 0;
  while (i < s.length) {
    final c = s[i];
    if (inQuotes) {
      if (c == '"') {
        if (i + 1 < s.length && s[i + 1] == '"') {
          field.write('"');
          i += 2;
          continue;
        }
        inQuotes = false;
        i++;
        continue;
      }
      field.write(c);
      i++;
      continue;
    }
    if (c == '"') {
      inQuotes = true;
      i++;
    } else if (c == ',') {
      row.add(field.toString());
      field = StringBuffer();
      i++;
    } else if (c == '\r') {
      i++; // se ignora; el salto real lo marca '\n'
    } else if (c == '\n') {
      row.add(field.toString());
      rows.add(row);
      row = <String>[];
      field = StringBuffer();
      i++;
    } else {
      field.write(c);
      i++;
    }
  }
  if (field.isNotEmpty || row.isNotEmpty) {
    row.add(field.toString());
    rows.add(row);
  }
  return rows;
}

DateTime? _parseDate(String s) {
  final t = s.trim();
  if (t.isEmpty) return null;
  return DateTime.tryParse(t) ?? parseDmy(t); // ISO (export) o dd/mm/aaaa
}

Sex? _parseSex(String s) {
  final t = s.trim().toUpperCase();
  if (t == 'F' || t == 'FEMENINO' || t == 'FEMALE') return Sex.female;
  if (t == 'M' || t == 'MASCULINO' || t == 'MALE') return Sex.male;
  return null;
}

MeasurePosition _parsePosition(String s) {
  final t = s.trim().toLowerCase();
  return t.startsWith('acost') || t == 'lying'
      ? MeasurePosition.lying
      : MeasurePosition.standing;
}

/// Número tolerante: acepta `.` (formato de exportación) y, como respaldo, `,`
/// decimal por si el archivo se editó en una hoja de cálculo en español.
double? _parseNum(String s) {
  final t = s.trim();
  if (t.isEmpty) return null;
  return double.tryParse(t) ?? double.tryParse(t.replaceAll(',', '.'));
}

// ---------------------------------------------------------------------------
// Selección de archivo + guardado
// ---------------------------------------------------------------------------

/// Abre el selector de archivos y parsea el CSV elegido. `null` si se canceló.
Future<ImportParse?> pickAndParseCsv() async {
  final file = await FilePicker.pickFile(
    type: FileType.custom,
    allowedExtensions: ['csv'],
    dialogTitle: 'Selecciona un CSV de mediciones',
  );
  if (file == null) return null;
  final bytes = await file.readAsBytes();
  final content = utf8.decode(bytes, allowMalformed: true);
  return parseMeasurementsCsv(content, standardIdForLabel: repoStandardIdForLabel);
}

/// Resuelve el id del estándar desde su nombre visible usando las referencias
/// cargadas (`ReferenceRepository`). `null` si no hay coincidencia.
String? repoStandardIdForLabel(String label) {
  if (!ReferenceRepository.isLoaded) return null;
  final l = label.trim();
  for (final std in ReferenceRepository.store.standards.values) {
    if (std.displayName == l || std.standardId == l) return std.standardId;
  }
  return null;
}

/// Calcula y guarda cada fila (agrupando por nombre). Devuelve cuántas
/// mediciones se guardaron; omite en silencio las cuyo estándar no esté cargado.
Future<int> importMeasurements(List<ImportRow> rows) async {
  var saved = 0;
  for (final row in rows) {
    final ref = ReferenceRepository.reference(row.input.standardId);
    if (ref == null) continue;
    final result = computeAnthro(row.input, ref);
    await AnthroDatabase.instance.saveMeasurement(
      patientName: row.patientName,
      input: row.input,
      result: result,
    );
    saved++;
  }
  return saved;
}
