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

  test('searchPatients filtra por nombre, insensible a acentos, solo con historial', () async {
    final db = AnthroDatabase.instance;
    await db.saveMeasurement(patientName: 'Sofía Restrepo', input: input(), result: result());
    await db.saveMeasurement(patientName: 'Mateo', input: input(), result: result());

    expect(await db.searchPatients('sofía'), hasLength(1));
    expect((await db.searchPatients('sofía')).first.name, 'Sofía Restrepo');
    expect(await db.searchPatients('rest'), hasLength(1));
    expect(await db.searchPatients('SOFIA'), hasLength(1));
    expect(await db.searchPatients('zzz'), isEmpty);
    expect(await db.searchPatients(''), isEmpty);
  });

  test('saveMeasurement con patientId asocia la medición a ese paciente', () async {
    final db = AnthroDatabase.instance;
    await db.saveMeasurement(patientName: 'Ana', input: input(), result: result());
    final ana = (await db.listPatients()).first;

    await db.saveMeasurement(
      patientName: 'Otro nombre ignorado',
      patientId: ana.id,
      input: input(),
      result: result(),
    );

    final patients = await db.listPatients();
    expect(patients, hasLength(1));
    expect(patients.first.id, ana.id);
    expect(patients.first.measurementCount, 2);
    final history = await db.measurementsForPatient(ana.id);
    expect(history, hasLength(2));
  });

  test('updateMeasurement re-persiste valores e indicadores y marca updated_at', () async {
    final db = AnthroDatabase.instance;
    final id = await db.saveMeasurement(
        patientName: 'Mateo', input: input(), result: result());
    final before = (await db.measurementsForPatient(
        (await db.listPatients()).first.id)).first;
    expect(before.updatedAt, isNull);

    final newInput = AnthroInput(
      birthDate: DateTime(2024, 5, 14),
      measurementDate: DateTime(2026, 8, 15),
      sex: Sex.female,
      weightKg: 13.0,
      statureCm: 88.0,
      position: MeasurePosition.standing,
      headCircumferenceCm: 44.5,
      standardId: 'oms-2006',
    );
    final newResult = AnthroResult(
      age: const Age(days: 823, years: 2, months: 3, remDays: 1),
      sex: Sex.female,
      standardId: 'oms-2006',
      standardLabel: 'OMS 2006',
      weightKg: 13.0,
      statureCm: 88.0,
      headCircumferenceCm: 44.5,
      bmi: 16.8,
      indicators: const [
        Indicator(
          name: 'Peso / Edad',
          z: 0.1,
          percentile: 54.0,
          percentileLabel: '54',
          classification: 'Adecuado',
          status: ClinicalStatus.ok,
        ),
      ],
      overall: ClinicalStatus.ok,
      overallLabel: 'Normal',
    );

    await db.updateMeasurement(
      measurementId: id,
      patientName: 'Mateo',
      input: newInput,
      result: newResult,
    );

    final history = await db.measurementsForPatient((await db.listPatients()).first.id);
    expect(history, hasLength(1));
    final m = history.first;
    expect(m.weightKg, 13.0);
    expect(m.statureCm, 88.0);
    expect(m.headCircumferenceCm, 44.5);
    expect(m.overall, ClinicalStatus.ok);
    expect(m.indicators, hasLength(1));
    expect(m.indicators.first.z, closeTo(0.1, 1e-9));
    expect(m.updatedAt, isNotNull);
  });

  test('updateMeasurement reasigna a otro paciente cuando cambia el paciente', () async {
    final db = AnthroDatabase.instance;
    final id = await db.saveMeasurement(
        patientName: 'Mateo', input: input(), result: result());
    await db.saveMeasurement(patientName: 'Ana', input: input(), result: result());
    final ana = (await db.listPatients())
        .firstWhere((p) => p.name == 'Ana');

    await db.updateMeasurement(
      measurementId: id,
      patientName: 'Ana',
      patientId: ana.id,
      input: input(),
      result: result(),
    );

    expect(await db.measurementsForPatient(ana.id), hasLength(2));
    expect((await db.listPatients()).firstWhere((p) => p.name == 'Mateo').measurementCount, 0);
  });

  group('monitoreo y mantenimiento', () {
    test('stats reporta conteos, esquema, integridad y fichas vacías', () async {
      final db = AnthroDatabase.instance;
      await db.saveMeasurement(
          patientName: 'Sofía', input: input(), result: result());
      // Ficha sin mediciones (candidata a limpieza).
      final raw = await db.database;
      await raw.insert('patients',
          {'name': 'Vacío', 'created_at': DateTime.now().toIso8601String()});

      final s = await db.stats();
      expect(s.patientCount, 2);
      expect(s.measurementCount, 1);
      expect(s.indicatorCount, 2);
      expect(s.emptyPatientCount, 1);
      expect(s.orphanCount, 0);
      expect(s.integrityOk, isTrue);
      expect(s.schemaVersion, 2);
      expect(s.isHealthy, isTrue);
      expect(s.earliest, DateTime(2026, 8, 15));
      expect(s.latest, DateTime(2026, 8, 15));
    });

    test('deleteEmptyPatients borra solo las fichas sin mediciones', () async {
      final db = AnthroDatabase.instance;
      await db.saveMeasurement(
          patientName: 'Sofía', input: input(), result: result());
      final raw = await db.database;
      await raw.insert('patients',
          {'name': 'Vacío', 'created_at': DateTime.now().toIso8601String()});

      expect(await db.deleteEmptyPatients(), 1);
      final patients = await db.listPatients();
      expect(patients, hasLength(1));
      expect(patients.first.name, 'Sofía');
      expect((await db.stats()).emptyPatientCount, 0);
    });

    test('purgeOrphans depura mediciones e indicadores sin relación', () async {
      final db = AnthroDatabase.instance;
      final mid = await db.saveMeasurement(
          patientName: 'Sofía', input: input(), result: result());
      // Huérfano: se borra la fila del paciente dejando la medición suelta.
      final raw = await db.database;
      final pid = (await raw.query('measurements',
              columns: ['patient_id'], where: 'id = ?', whereArgs: [mid]))
          .first['patient_id'] as int;
      await raw.delete('patients', where: 'id = ?', whereArgs: [pid]);

      expect((await db.stats()).orphanMeasurementCount, 1);
      // Medición huérfana (1) + sus indicadores, ya sueltos (2) = 3.
      expect(await db.purgeOrphans(), 3);
      final s = await db.stats();
      expect(s.measurementCount, 0);
      expect(s.indicatorCount, 0);
      expect(s.orphanCount, 0);
    });

    test('deleteAllData deja la base vacía', () async {
      final db = AnthroDatabase.instance;
      await db.saveMeasurement(
          patientName: 'Sofía', input: input(), result: result());
      await db.saveMeasurement(
          patientName: 'Mateo', input: input(), result: result());

      await db.deleteAllData();
      final s = await db.stats();
      expect(s.patientCount, 0);
      expect(s.measurementCount, 0);
      expect(s.indicatorCount, 0);
      expect(await db.listPatients(), isEmpty);
    });

    test('revision notifica ante guardar, limpiar y borrar datos', () async {
      final db = AnthroDatabase.instance;
      var ticks = 0;
      void listener() => ticks++;
      db.revision.addListener(listener);
      addTearDown(() => db.revision.removeListener(listener));

      await db.saveMeasurement(
          patientName: 'Sofía', input: input(), result: result());
      expect(ticks, 1); // guardar notifica

      final raw = await db.database;
      await raw.insert('patients',
          {'name': 'Vacío', 'created_at': DateTime.now().toIso8601String()});
      await db.deleteEmptyPatients();
      expect(ticks, 2); // limpieza con cambios notifica

      await db.deleteEmptyPatients();
      expect(ticks, 2); // sin cambios no notifica

      await db.deleteAllData();
      expect(ticks, 3); // borrado total notifica
    });

    test('vacuum se ejecuta sin error tras borrar datos', () async {
      final db = AnthroDatabase.instance;
      await db.saveMeasurement(
          patientName: 'Sofía', input: input(), result: result());
      await db.deleteAllData();
      await db.vacuum(); // no debe lanzar
      expect((await db.stats()).measurementCount, 0);
    });
  });
}
