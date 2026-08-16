import 'package:flutter_test/flutter_test.dart';

import 'package:anthro_calculator_app/anthro/reference.dart';
import 'package:anthro_calculator_app/data.dart';
import 'package:anthro_calculator_app/db/models.dart';
import 'package:anthro_calculator_app/export/measurement_export.dart';
import 'package:anthro_calculator_app/import/measurement_import.dart';
import 'package:anthro_calculator_app/theme.dart' show ClinicalStatus;

String? _std(String label) => label == 'OMS 2006' ? 'oms-2006' : null;

SavedMeasurement _measurement({required String name, double? pc}) =>
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
      weightKg: 7.2,
      statureCm: 64.5,
      headCircumferenceCm: pc,
      bmi: 17.3,
      ageDays: 150,
      ageYears: 0,
      ageMonths: 4,
      ageRemDays: 28,
      overall: ClinicalStatus.ok,
      overallLabel: 'Adecuado',
      createdAt: DateTime(2024, 6, 3),
      indicators: const [],
    );

void main() {
  test('round-trip export→import conserva la entrada cruda', () {
    final csv = buildMeasurementsCsv([_measurement(name: 'Ana Pérez', pc: 44.1)]);
    final parse = parseMeasurementsCsv(csv, standardIdForLabel: _std);

    expect(parse.errors, isEmpty);
    expect(parse.rows.length, 1);
    final row = parse.rows.single;
    expect(row.patientName, 'Ana Pérez');
    final i = row.input;
    expect(i.standardId, 'oms-2006');
    expect(i.sex, Sex.female);
    expect(i.position, MeasurePosition.lying);
    expect(i.weightKg, 7.2);
    expect(i.statureCm, 64.5);
    expect(i.headCircumferenceCm, 44.1);
    expect(i.birthDate, DateTime(2024, 1, 5));
    expect(i.measurementDate, DateTime(2024, 6, 3));
  });

  test('PC vacío se importa como null', () {
    final csv = buildMeasurementsCsv([_measurement(name: 'Ana', pc: null)]);
    final parse = parseMeasurementsCsv(csv, standardIdForLabel: _std);
    expect(parse.rows.single.input.headCircumferenceCm, isNull);
  });

  test('omite filas con datos inválidos y las reporta por número de línea', () {
    const csv =
        'Paciente,Fecha medición,Fecha nacimiento,Sexo,Posición,Estándar,Peso (kg),Talla (cm),PC (cm)\r\n'
        'Ana,2024-06-03,2024-01-05,X,De pie,OMS 2006,7.2,64.5,\r\n' // sexo inválido
        'Beto,2024-06-03,2024-01-05,M,De pie,OMS 2006,8.0,70.0,\r\n';
    final parse = parseMeasurementsCsv(csv, standardIdForLabel: _std);

    expect(parse.rows.length, 1);
    expect(parse.rows.single.patientName, 'Beto');
    expect(parse.rows.single.input.sex, Sex.male);
    expect(parse.rows.single.input.position, MeasurePosition.standing);
    expect(parse.errors.length, 1);
    expect(parse.errors.single, contains('Fila 2'));
  });

  test('reporta estándar no reconocido', () {
    const csv =
        'Paciente,Fecha medición,Fecha nacimiento,Sexo,Estándar,Peso (kg),Talla (cm)\r\n'
        'Ana,2024-06-03,2024-01-05,F,Marciano,7.2,64.5\r\n';
    final parse = parseMeasurementsCsv(csv, standardIdForLabel: _std);
    expect(parse.rows, isEmpty);
    expect(parse.errors.single, contains('estándar no reconocido'));
  });

  test('cabecera incompleta se rechaza con mensaje claro', () {
    const csv = 'Paciente,Peso (kg)\r\nAna,7.2\r\n';
    final parse = parseMeasurementsCsv(csv, standardIdForLabel: _std);
    expect(parse.rows, isEmpty);
    expect(parse.errors.single, contains('faltan columnas'));
  });
}
