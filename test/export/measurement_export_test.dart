import 'package:flutter_test/flutter_test.dart';

import 'package:anthro_calculator_app/anthro/reference.dart';
import 'package:anthro_calculator_app/data.dart';
import 'package:anthro_calculator_app/db/models.dart';
import 'package:anthro_calculator_app/export/measurement_export.dart';
import 'package:anthro_calculator_app/theme.dart' show ClinicalStatus;

SavedMeasurement _measurement({
  required String name,
  double? headCircumferenceCm,
  double? bmi,
  List<SavedIndicator> indicators = const [],
}) =>
    SavedMeasurement(
      id: 1,
      patientId: 1,
      patientName: name,
      birthDate: DateTime(2024, 1, 5),
      measurementDate: DateTime(2024, 6, 3),
      sex: Sex.female,
      position: MeasurePosition.lying,
      standardId: 'oms-2006',
      standardLabel: 'OMS 2006',
      weightKg: 7,
      statureCm: 64.5,
      headCircumferenceCm: headCircumferenceCm,
      bmi: bmi,
      ageDays: 150,
      ageYears: 0,
      ageMonths: 4,
      ageRemDays: 28,
      overall: ClinicalStatus.warn,
      overallLabel: 'Riesgo',
      createdAt: DateTime(2024, 6, 3),
      indicators: indicators,
    );

SavedIndicator _ind(String name, double? z, String classification) => SavedIndicator(
      name: name,
      z: z,
      percentile: null,
      percentileLabel: null,
      classification: classification,
      status: ClinicalStatus.warn,
    );

void main() {
  test('antepone BOM UTF-8 y cabecera esperada', () {
    final csv = buildMeasurementsCsv([_measurement(name: 'Ana')]);
    expect(csv.codeUnitAt(0), 0xFEFF, reason: 'debe iniciar con BOM');
    final header = csv.substring(1).split('\r\n').first.split(',');
    expect(header.first, 'Paciente');
    expect(header.contains('P/E Z'), isTrue);
    expect(header.contains('PC/E Clasif'), isTrue);
    expect(header.length, 13 + 5 * 2, reason: '13 base + 5 indicadores × 2');
  });

  test('escapa comas y comillas en las celdas', () {
    final csv = buildMeasurementsCsv([_measurement(name: 'Pérez, Ana "AJ"')]);
    final row = csv.substring(1).split('\r\n')[1];
    expect(row.startsWith('"Pérez, Ana ""AJ"""'), isTrue);
  });

  test('aplana indicadores y deja vacías las celdas faltantes', () {
    final csv = buildMeasurementsCsv([
      _measurement(
        name: 'Ana',
        headCircumferenceCm: null,
        bmi: null,
        indicators: [_ind('Peso / Edad', -1.5, 'Riesgo')],
      ),
    ]);
    final lines = csv.substring(1).split('\r\n');
    final header = lines[0].split(','); // sin comas dentro de campos
    final cells = lines[1].split(',');
    expect(cells.length, header.length);

    String cell(String col) => cells[header.indexOf(col)];
    expect(cell('PC (cm)'), '');
    expect(cell('IMC'), '');
    expect(cell('P/E Z'), '-1.500');
    expect(cell('P/E Clasif'), 'Riesgo');
    expect(cell('T/E Z'), '', reason: 'indicador ausente → celda vacía');
  });
}
