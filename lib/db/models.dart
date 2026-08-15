/// Modelos de lectura de la base de datos local (patients · measurements ·
/// indicators). Son DTOs planos que reconstruyen lo que la pantalla de
/// resultados muestra, para poder presentar el historial sin recalcular.
library;

import '../data.dart';
import '../anthro/reference.dart';
import '../theme.dart' show ClinicalStatus;

/// Un paciente guardado con el número de mediciones asociadas y su última
/// medición (para la lista de pacientes).
class SavedPatient {
  const SavedPatient({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.measurementCount,
    this.latest,
  });

  final int id;
  final String name;
  final DateTime createdAt;
  final int measurementCount;

  /// Mediciones más reciente (por fecha de medición) o `null` si no tiene.
  final SavedMeasurement? latest;
}

/// Una medición guardada completa (entrada + resultado + indicadores).
class SavedMeasurement {
  const SavedMeasurement({
    required this.id,
    required this.patientId,
    required this.patientName,
    required this.birthDate,
    required this.measurementDate,
    required this.sex,
    required this.position,
    required this.standardId,
    required this.standardLabel,
    required this.weightKg,
    required this.statureCm,
    this.headCircumferenceCm,
    this.bmi,
    required this.ageDays,
    required this.ageYears,
    required this.ageMonths,
    required this.ageRemDays,
    required this.overall,
    required this.overallLabel,
    required this.createdAt,
    this.updatedAt,
    required this.indicators,
  });

  final int id;
  final int patientId;
  final String patientName;
  final DateTime birthDate;
  final DateTime measurementDate;
  final Sex sex;
  final MeasurePosition position;
  final String standardId;
  final String standardLabel;
  final double weightKg;
  final double statureCm;
  final double? headCircumferenceCm;
  final double? bmi;
  final int ageDays;
  final int ageYears;
  final int ageMonths;
  final int ageRemDays;
  final ClinicalStatus overall;
  final String overallLabel;
  final DateTime createdAt;

  /// Última vez que se re-persistió la medición (`null` en registros creados
  /// antes de la columna `updated_at`).
  final DateTime? updatedAt;
  final List<SavedIndicator> indicators;
}

/// Un indicador de una medición, en el orden original en que se mostró.
class SavedIndicator {
  const SavedIndicator({
    required this.name,
    required this.z,
    required this.percentile,
    required this.percentileLabel,
    required this.classification,
    required this.status,
    this.deficitNote,
  });

  final String name;
  final double? z;
  final double? percentile;
  final String? percentileLabel;
  final String classification;
  final ClinicalStatus status;
  final String? deficitNote;
}
