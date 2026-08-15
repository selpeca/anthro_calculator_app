import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:anthro_calculator_app/anthro/age.dart';
import 'package:anthro_calculator_app/anthro/indicators.dart';
import 'package:anthro_calculator_app/anthro/reference.dart';
import 'package:anthro_calculator_app/data.dart';
import 'package:anthro_calculator_app/db/database.dart';
import 'package:anthro_calculator_app/theme.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    AnthroDatabase.overridePath = inMemoryDatabasePath;
  });

  tearDown(() => AnthroDatabase.instance.close());

  AnthroResult result() => AnthroResult(
        age: const Age(days: 823, years: 2, months: 3, remDays: 1),
        sex: Sex.female,
        standardId: 'oms-2006',
        standardLabel: 'OMS 2006',
        weightKg: 12.4,
        statureCm: 86.5,
        headCircumferenceCm: 44.1,
        bmi: 16.6,
        indicators: const [
          Indicator(
            name: 'Peso / Edad',
            z: -0.42,
            percentile: 33.7,
            percentileLabel: '33',
            classification: 'Adecuado',
            status: ClinicalStatus.ok,
          ),
          Indicator(
            name: 'Talla / Edad',
            z: -2.3,
            percentile: 1.1,
            percentileLabel: '1',
            classification: 'Alteración',
            status: ClinicalStatus.bad,
            deficitNote: 'Déficit frente a −2 DS: 1.20 cm.',
          ),
        ],
        overall: ClinicalStatus.bad,
        overallLabel: 'Alteración',
      );

  AnthroInput input() => AnthroInput(
        birthDate: DateTime(2024, 5, 14),
        measurementDate: DateTime(2026, 8, 15),
        sex: Sex.female,
        weightKg: 12.4,
        statureCm: 86.5,
        position: MeasurePosition.standing,
        headCircumferenceCm: 44.1,
        standardId: 'oms-2006',
      );

  test('saveMeasurement persiste paciente, medición e indicadores', () async {
    final id = await AnthroDatabase.instance
        .saveMeasurement(patientName: 'Sofía Restrepo', input: input(), result: result());
    expect(id, greaterThan(0));

    final patients = await AnthroDatabase.instance.listPatients();
    expect(patients, hasLength(1));
    expect(patients.first.name, 'Sofía Restrepo');
    expect(patients.first.measurementCount, 1);
    expect(patients.first.latest, isNotNull);
    expect(patients.first.latest!.patientName, 'Sofía Restrepo');
    expect(patients.first.latest!.weightKg, 12.4);

    final history =
        await AnthroDatabase.instance.measurementsForPatient(patients.first.id);
    expect(history, hasLength(1));
    expect(history.first.patientName, 'Sofía Restrepo');
    final m = history.first;
    expect(m.weightKg, 12.4);
    expect(m.statureCm, 86.5);
    expect(m.headCircumferenceCm, 44.1);
    expect(m.bmi, closeTo(16.6, 1e-9));
    expect(m.sex, Sex.female);
    expect(m.position, MeasurePosition.standing);
    expect(m.standardId, 'oms-2006');
    expect(m.ageDays, 823);
    expect(m.overall, ClinicalStatus.bad);
    expect(m.overallLabel, 'Alteración');
    expect(m.indicators, hasLength(2));
    expect(m.indicators.first.name, 'Peso / Edad');
    expect(m.indicators.first.z, closeTo(-0.42, 1e-9));
    expect(m.indicators.first.status, ClinicalStatus.ok);
    expect(m.indicators.last.status, ClinicalStatus.bad);
    expect(m.indicators.last.deficitNote, contains('Déficit'));
  });

  test('el mismo nombre de paciente acumula historial', () async {
    final db = AnthroDatabase.instance;
    await db.saveMeasurement(patientName: 'Mateo', input: input(), result: result());
    await db.saveMeasurement(patientName: ' mateo ', input: input(), result: result());

    final patients = await db.listPatients();
    expect(patients, hasLength(1));
    expect(patients.first.measurementCount, 2);

    final history = await db.measurementsForPatient(patients.first.id);
    expect(history, hasLength(2));
  });

  test('dos pacientes distintos son registros separados', () async {
    final db = AnthroDatabase.instance;
    await db.saveMeasurement(patientName: 'Ana', input: input(), result: result());
    await db.saveMeasurement(patientName: 'Luis', input: input(), result: result());

    final patients = await db.listPatients();
    expect(patients, hasLength(2));
    expect(patients.map((p) => p.name), containsAll(['Ana', 'Luis']));
  });
}
