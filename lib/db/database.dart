/// Persistencia local de pacientes y mediciones en SQLite (offline-first).
///
/// Esquema relacional: `patients` (1) → `measurements` (N) → `indicators` (N).
/// Guarda toda la entrada del cálculo y todo lo que `results.dart` muestra:
/// edad, sexo, estándar, medidas, IMC y cada indicador con Z, percentil,
/// clasificación, estado y nota de déficit.
///
/// En los tests (sin path_provider) se puede apuntar a un archivo propio o a
/// memoria con `overridePath = inMemoryDatabasePath` y `databaseFactory =
/// databaseFactoryFfi` (sqflite_common_ffi).
library;

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../anthro/age.dart';
import '../anthro/indicators.dart';
import '../anthro/reference.dart';
import '../data.dart';
import '../theme.dart' show ClinicalStatus;
import 'models.dart';

/// Versión del esquema; subir con las migraciones en `onUpgrade`.
/// v2: columna `measurements.updated_at` para el flujo de "Actualizar".
const int _schemaVersion = 2;

class AnthroDatabase {
  AnthroDatabase._();

  static final AnthroDatabase instance = AnthroDatabase._();

  /// Ruta de la BD para pruebas (p. ej. `inMemoryDatabasePath`). Si es `null`
  /// se usa `<appDocuments>/anthro_calculator.db`.
  static String? overridePath;

  Database? _db;

  /// Ruta con la que se abrió la base; se resuelve en `_open` y se reporta en
  /// [stats] (para mostrar ubicación y tamaño en disco).
  String? _resolvedPath;

  /// Se notifica ante cualquier mutación de datos (guardar, actualizar, limpiar
  /// o borrar). Las pantallas que muestran agregados —como el home— pueden
  /// escucharlo para refrescarse. El valor es un contador de revisión sin
  /// significado propio; solo interesan sus cambios.
  final ValueNotifier<int> revision = ValueNotifier<int>(0);

  void _notifyChanged() => revision.value++;

  /// Abre (una vez) la base y la reutiliza. Forma explícita para no depender
  /// del análisis de tipos de `??=` sobre un campo anulable.
  Future<Database> get database async {
    final existing = _db;
    if (existing != null) return existing;
    return _db = await _open();
  }

  Future<void> close() async {
    await _db?.close();
    _db = null;
  }

  Future<Database> _open() async {
    final path = overridePath ?? p.join(await _defaultDir(), 'anthro.db');
    _resolvedPath = path;
    return openDatabase(
      path,
      version: _schemaVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<String> _defaultDir() async {
    final docs = await getApplicationDocumentsDirectory();
    return docs.path;
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute(
          'ALTER TABLE measurements ADD COLUMN updated_at TEXT');
    }
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE patients (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL COLLATE NOCASE,
        created_at TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE measurements (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        patient_id INTEGER NOT NULL REFERENCES patients(id) ON DELETE CASCADE,
        birth_date TEXT NOT NULL,
        measurement_date TEXT NOT NULL,
        sex TEXT NOT NULL,
        position TEXT NOT NULL,
        standard_id TEXT NOT NULL,
        standard_label TEXT NOT NULL,
        weight_kg REAL NOT NULL,
        stature_cm REAL NOT NULL,
        head_circumference_cm REAL,
        bmi REAL,
        age_days INTEGER NOT NULL,
        age_years INTEGER NOT NULL,
        age_months INTEGER NOT NULL,
        age_rem_days INTEGER NOT NULL,
        overall TEXT NOT NULL,
        overall_label TEXT NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE indicators (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        measurement_id INTEGER NOT NULL REFERENCES measurements(id) ON DELETE CASCADE,
        position INTEGER NOT NULL,
        name TEXT NOT NULL,
        z REAL,
        percentile REAL,
        percentile_label TEXT,
        classification TEXT NOT NULL,
        status TEXT NOT NULL,
        deficit_note TEXT
      )
    ''');
    await db.execute(
        'CREATE INDEX idx_measurements_patient ON measurements(patient_id)');
    await db.execute(
        'CREATE INDEX idx_indicators_measurement ON indicators(measurement_id)');
  }

  /// Guarda una medición asociada a un paciente por nombre (get-or-create).
  ///
  /// Si se pasa [patientId] se usa ese paciente directamente (ya existía y el
  /// usuario la seleccionó al buscar). En caso contrario se reutiliza el
  /// paciente cuando ya existe un registro con el mismo nombre (insensible a
  /// mayúsculas), acumulando así su historial.
  Future<int> saveMeasurement({
    required String patientName,
    required AnthroInput input,
    required AnthroResult result,
    int? patientId,
  }) async {
    final db = await database;
    final name = patientName.trim();
    final id = await db.transaction((txn) async {
      final pid = patientId ?? await _resolvePatientId(txn, name);
      final now = _isoNow();
      final measurementId = await txn.insert('measurements', {
        'patient_id': pid,
        'birth_date': _isoDate(input.birthDate),
        'measurement_date': _isoDate(input.measurementDate),
        'sex': input.sex.name,
        'position': input.position.name,
        'standard_id': input.standardId,
        'standard_label': result.standardLabel,
        'weight_kg': input.weightKg,
        'stature_cm': input.statureCm,
        'head_circumference_cm': result.headCircumferenceCm,
        'bmi': result.bmi,
        'age_days': result.age.days,
        'age_years': result.age.years,
        'age_months': result.age.months,
        'age_rem_days': result.age.remDays,
        'overall': result.overall.name,
        'overall_label': result.overallLabel,
        'created_at': now,
      });

      await _insertIndicators(txn, measurementId, result);
      return measurementId;
    });
    _notifyChanged();
    return id;
  }

  /// Actualiza una medición ya guardada (flujo del botón "Actualizar").
  ///
  /// Re-persiste los datos del cálculo y sus indicadores. Si el paciente
  /// elegido es distinto al actual, la medición se reasigna (get-or-create
  /// por nombre cuando [patientId] es `null`).
  Future<void> updateMeasurement({
    required int measurementId,
    required String patientName,
    required AnthroInput input,
    required AnthroResult result,
    int? patientId,
  }) async {
    final db = await database;
    final name = patientName.trim();
    await db.transaction((txn) async {
      final pid = patientId ?? await _resolvePatientId(txn, name);
      await txn.update(
        'measurements',
        {
          'patient_id': pid,
          'birth_date': _isoDate(input.birthDate),
          'measurement_date': _isoDate(input.measurementDate),
          'sex': input.sex.name,
          'position': input.position.name,
          'standard_id': input.standardId,
          'standard_label': result.standardLabel,
          'weight_kg': input.weightKg,
          'stature_cm': input.statureCm,
          'head_circumference_cm': result.headCircumferenceCm,
          'bmi': result.bmi,
          'age_days': result.age.days,
          'age_years': result.age.years,
          'age_months': result.age.months,
          'age_rem_days': result.age.remDays,
          'overall': result.overall.name,
          'overall_label': result.overallLabel,
          'updated_at': _isoNow(),
        },
        where: 'id = ?',
        whereArgs: [measurementId],
      );
      await txn.delete('indicators',
          where: 'measurement_id = ?', whereArgs: [measurementId]);
      await _insertIndicators(txn, measurementId, result);
    });
    _notifyChanged();
  }

  /// Id del paciente existente con ese nombre, o crea uno nuevo.
  Future<int> _resolvePatientId(DatabaseExecutor txn, String name) async {
    final existing = await txn.query(
      'patients',
      columns: ['id'],
      where: 'name = ?',
      whereArgs: [name],
      limit: 1,
    );
    return existing.isNotEmpty
        ? existing.first['id'] as int
        : txn.insert('patients', {
            'name': name,
            'created_at': _isoNow(),
          });
  }

  Future<void> _insertIndicators(
      DatabaseExecutor txn, int measurementId, AnthroResult result) async {
    for (var i = 0; i < result.indicators.length; i++) {
      final ind = result.indicators[i];
      await txn.insert('indicators', {
        'measurement_id': measurementId,
        'position': i,
        'name': ind.name,
        'z': ind.z,
        'percentile': ind.percentile,
        'percentile_label': ind.percentileLabel,
        'classification': ind.classification,
        'status': ind.status.name,
        'deficit_note': ind.deficitNote,
      });
    }
  }

  /// Pacientes con mediciones cuyo nombre contiene [query] (insensible a
  /// mayúsculas, tolerante a acentos). Devuelve los que ya tienen historial,
  /// ordenados por actividad reciente.
  Future<List<SavedPatient>> searchPatients(String query) async {
    final q = _normalize(query);
    if (q.isEmpty) return const [];
    final all = await listPatients();
    return [
      for (final p in all)
        if (p.measurementCount > 0 && _normalize(p.name).contains(q)) p,
    ];
  }

  /// Minúsculas sin acentos para que "sofia" encuentre "Sofía" y viceversa.
  static String _normalize(String s) {
    const from = 'áéíóúüñ';
    const to = 'aeiouun';
    final out = s.toLowerCase();
    final sb = StringBuffer();
    for (var i = 0; i < out.length; i++) {
      final c = out[i];
      final idx = from.indexOf(c);
      sb.write(idx >= 0 ? to[idx] : c);
    }
    return sb.toString();
  }

  /// Pacientes con su última medición, ordenados por actividad reciente
  /// (última medición o creación si no tienen).
  Future<List<SavedPatient>> listPatients() async {
    final db = await database;
    final rows = await db.rawQuery('''
      SELECT p.id, p.name, p.created_at,
             (SELECT COUNT(*) FROM measurements m
              WHERE m.patient_id = p.id) AS measurement_count,
             (SELECT m.id FROM measurements m
              WHERE m.patient_id = p.id
              ORDER BY m.measurement_date DESC, m.id DESC LIMIT 1) AS latest_id
      FROM patients p
      ORDER BY COALESCE(
        (SELECT MAX(m.measurement_date) FROM measurements m
         WHERE m.patient_id = p.id), p.created_at) DESC
    ''');
    final out = <SavedPatient>[];
    for (final r in rows) {
      final latestId = r['latest_id'] as int?;
      SavedMeasurement? latest;
      if (latestId != null) {
        latest = await _measurementFromRow(
            db, r['name'] as String, await _measurementRow(db, latestId));
      }
      out.add(SavedPatient(
        id: r['id'] as int,
        name: r['name'] as String,
        createdAt: DateTime.parse(r['created_at'] as String),
        measurementCount: (r['measurement_count'] as int?) ?? 0,
        latest: latest,
      ));
    }
    return out;
  }

  /// Fecha de medición de cada medición guardada.
  ///
  /// Sirve para consolidar en el tiempo la cantidad de mediciones
  /// registradas por semana o por mes.
  Future<List<DateTime>> measurementDates() async {
    final db = await database;
    final rows = await db.rawQuery(
        'SELECT measurement_date FROM measurements ORDER BY measurement_date');
    return [for (final r in rows) DateTime.parse(r['measurement_date'] as String)];
  }

  /// Cantidad de mediciones cuya fecha está en el rango [desde, hasta]
  /// (inclusive). Se usa para paginar la vista semanal sin cargar todo.
  Future<int> countMeasurementsBetween(DateTime desde, DateTime hasta) async {
    final db = await database;
    final rows = await db.rawQuery(
      'SELECT COUNT(*) AS c FROM measurements '
      'WHERE measurement_date BETWEEN ? AND ?',
      [_isoDate(desde), _isoDate(hasta)],
    );
    return (rows.first['c'] as int?) ?? 0;
  }

  /// Fecha de la medición más antigua guardada, o `null` si no hay ninguna.
  Future<DateTime?> earliestMeasurementDate() async {
    final db = await database;
    final rows = await db
        .rawQuery('SELECT MIN(measurement_date) AS d FROM measurements');
    final d = rows.first['d'] as String?;
    return d == null ? null : DateTime.parse(d);
  }

  // ── Monitoreo y mantenimiento ────────────────────────────────────────────

  /// Foto del estado de la base para la pantalla de administración: conteos por
  /// tabla, registros a depurar, integridad, versión de esquema y tamaño en
  /// disco. Todo en una sola pasada para poder refrescar con un toque.
  Future<DatabaseStats> stats() async {
    final db = await database;

    Future<int> count(String sql) async =>
        Sqflite.firstIntValue(await db.rawQuery(sql)) ?? 0;

    final patients = await count('SELECT COUNT(*) FROM patients');
    final measurements = await count('SELECT COUNT(*) FROM measurements');
    final indicators = await count('SELECT COUNT(*) FROM indicators');
    final emptyPatients = await count(
      'SELECT COUNT(*) FROM patients pt '
      'WHERE NOT EXISTS (SELECT 1 FROM measurements m WHERE m.patient_id = pt.id)',
    );
    final orphanMeasurements = await count(
      'SELECT COUNT(*) FROM measurements m '
      'WHERE NOT EXISTS (SELECT 1 FROM patients pt WHERE pt.id = m.patient_id)',
    );
    final orphanIndicators = await count(
      'SELECT COUNT(*) FROM indicators i '
      'WHERE NOT EXISTS (SELECT 1 FROM measurements m WHERE m.id = i.measurement_id)',
    );
    final version =
        Sqflite.firstIntValue(await db.rawQuery('PRAGMA user_version')) ?? 0;

    final integrity = await db.rawQuery('PRAGMA integrity_check');
    final detail = integrity.isEmpty
        ? 'desconocido'
        : (integrity.first.values.first?.toString() ?? 'desconocido');

    final range = await db.rawQuery(
      'SELECT MIN(measurement_date) AS lo, MAX(measurement_date) AS hi '
      'FROM measurements',
    );
    DateTime? parse(Object? v) =>
        v is String ? DateTime.parse(v) : null;

    return DatabaseStats(
      patientCount: patients,
      measurementCount: measurements,
      indicatorCount: indicators,
      emptyPatientCount: emptyPatients,
      orphanMeasurementCount: orphanMeasurements,
      orphanIndicatorCount: orphanIndicators,
      schemaVersion: version,
      sizeBytes: await _databaseFileBytes(),
      path: _resolvedPath ?? '(sin abrir)',
      integrityOk: detail == 'ok',
      integrityDetail: detail,
      earliest: parse(range.first['lo']),
      latest: parse(range.first['hi']),
    );
  }

  /// Tamaño del archivo `.db` en disco, o 0 si es en memoria / no existe.
  Future<int> _databaseFileBytes() async {
    final path = _resolvedPath;
    if (path == null || path == inMemoryDatabasePath) return 0;
    final f = File(path);
    return await f.exists() ? f.length() : 0;
  }

  /// Elimina las fichas de paciente que no tienen ninguna medición asociada.
  /// Devuelve cuántas se borraron.
  Future<int> deleteEmptyPatients() async {
    final db = await database;
    final removed = await db.delete(
      'patients',
      where: 'NOT EXISTS '
          '(SELECT 1 FROM measurements m WHERE m.patient_id = patients.id)',
    );
    if (removed > 0) _notifyChanged();
    return removed;
  }

  /// Depura registros inconsistentes: mediciones sin paciente e indicadores sin
  /// medición (incluidos los que quedaron sueltos al borrar la medición).
  /// Devuelve el total de filas eliminadas.
  Future<int> purgeOrphans() async {
    final db = await database;
    final removed = await db.transaction((txn) async {
      final measurements = await txn.delete(
        'measurements',
        where: 'NOT EXISTS '
            '(SELECT 1 FROM patients pt WHERE pt.id = measurements.patient_id)',
      );
      final indicators = await txn.delete(
        'indicators',
        where: 'NOT EXISTS '
            '(SELECT 1 FROM measurements m WHERE m.id = indicators.measurement_id)',
      );
      return measurements + indicators;
    });
    if (removed > 0) _notifyChanged();
    return removed;
  }

  /// Compacta el archivo de la base (`VACUUM`), recuperando el espacio liberado
  /// por borrados. No puede correr dentro de una transacción.
  Future<void> vacuum() async {
    final db = await database;
    await db.execute('VACUUM');
  }

  /// Borra todos los pacientes, mediciones e indicadores (deja la base vacía).
  /// Acción destructiva: la pantalla la protege con confirmación.
  Future<void> deleteAllData() async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('indicators');
      await txn.delete('measurements');
      await txn.delete('patients');
    });
    _notifyChanged();
  }

  /// Historial completo de mediciones de un paciente, más reciente primero.
  Future<List<SavedMeasurement>> measurementsForPatient(int patientId) async {
    final db = await database;
    final nameRows = await db.query(
      'patients',
      columns: ['name'],
      where: 'id = ?',
      whereArgs: [patientId],
      limit: 1,
    );
    final patientName = nameRows.isNotEmpty
        ? nameRows.first['name'] as String
        : '';
    final rows = await db.query(
      'measurements',
      where: 'patient_id = ?',
      whereArgs: [patientId],
      orderBy: 'measurement_date DESC, id DESC',
    );
    final out = <SavedMeasurement>[];
    for (final r in rows) {
      out.add(await _measurementFromRow(db, patientName, r));
    }
    return out;
  }

  Future<Map<String, Object?>> _measurementRow(Database db, int id) async {
    final rows = await db.query(
      'measurements',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) {
      throw StateError('Medición $id no encontrada');
    }
    return rows.first;
  }

  Future<SavedMeasurement> _measurementFromRow(
      DatabaseExecutor db, String patientName, Map<String, Object?> r) async {
    final indRows = await db.query(
      'indicators',
      where: 'measurement_id = ?',
      whereArgs: [r['id']],
      orderBy: 'position ASC',
    );
    final ind = [
      for (final i in indRows)
        SavedIndicator(
          name: i['name'] as String,
          z: (i['z'] as num?)?.toDouble(),
          percentile: (i['percentile'] as num?)?.toDouble(),
          percentileLabel: i['percentile_label'] as String?,
          classification: i['classification'] as String,
          status: _statusFromName(i['status'] as String),
          deficitNote: i['deficit_note'] as String?,
        ),
    ];
    return SavedMeasurement(
      id: r['id'] as int,
      patientId: r['patient_id'] as int,
      patientName: patientName,
      birthDate: DateTime.parse(r['birth_date'] as String),
      measurementDate: DateTime.parse(r['measurement_date'] as String),
      sex: _sexFromName(r['sex'] as String),
      position: _positionFromName(r['position'] as String),
      standardId: r['standard_id'] as String,
      standardLabel: r['standard_label'] as String,
      weightKg: (r['weight_kg'] as num).toDouble(),
      statureCm: (r['stature_cm'] as num).toDouble(),
      headCircumferenceCm: (r['head_circumference_cm'] as num?)?.toDouble(),
      bmi: (r['bmi'] as num?)?.toDouble(),
      ageDays: r['age_days'] as int,
      ageYears: r['age_years'] as int,
      ageMonths: r['age_months'] as int,
      ageRemDays: r['age_rem_days'] as int,
      overall: _statusFromName(r['overall'] as String),
      overallLabel: r['overall_label'] as String,
      createdAt: DateTime.parse(r['created_at'] as String),
      updatedAt: (r['updated_at'] as String?) != null
          ? DateTime.parse(r['updated_at'] as String)
          : null,
      indicators: ind,
    );
  }

  static ClinicalStatus _statusFromName(String name) {
    for (final s in ClinicalStatus.values) {
      if (s.name == name) return s;
    }
    return ClinicalStatus.none;
  }

  static Sex _sexFromName(String name) =>
      name == Sex.male.name ? Sex.male : Sex.female;

  static MeasurePosition _positionFromName(String name) =>
      name == MeasurePosition.lying.name
          ? MeasurePosition.lying
          : MeasurePosition.standing;

  static String _isoDate(DateTime d) =>
      dateOnly(d).toIso8601String().split('T').first;

  static String _isoNow() => DateTime.now().toIso8601String();
}
