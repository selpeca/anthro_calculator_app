import 'dart:math' as math;
import 'theme.dart';

/// Reference standard selectable in the calculator.
enum RefStandard { oms, colombia }

extension RefStandardX on RefStandard {
  String get label => this == RefStandard.oms ? 'OMS' : 'Colombia';
  String get note => this == RefStandard.oms
      ? 'OMS 2006 (0–5 a) y 2007 (5–19 a) · estándar prescriptivo internacional.'
      : 'Resolución 2465 de 2016 · adopta patrones OMS con las clasificaciones nacionales de estado nutricional.';
}

/// Measurement position: standing height vs. recumbent length.
enum MeasurePosition { standing, lying }

/// Resultado de un indicador antropométrico (un Z-score contra una curva).
///
/// DTO de presentación que renderiza `results.dart`. Lo llena el motor
/// (`lib/anthro/indicators.dart`) a partir del cálculo real. Cuando el
/// indicador no es interpretable (edad/talla fuera del rango de la
/// referencia), `z`, `percentile` y `percentileLabel` van en `null` y
/// `status` es `ClinicalStatus.none`.
class Indicator {
  const Indicator({
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

  /// Nota del déficit frente a −2 DS para el caso severo (o `null`).
  final String? deficitNote;

  String get zLabel =>
      z == null ? '—' : '${z! > 0 ? '+' : '−'}${z!.abs().toStringAsFixed(3)}';

  /// Subtítulo de la tarjeta: percentil + clasificación, o solo clasificación
  /// cuando no hay percentil (no interpretable).
  String get subtitle => percentile == null
      ? classification
      : 'Percentil $percentileLabel · $classification';
}

/// Patient list entry (design 1i).
class Patient {
  const Patient({
    required this.initials,
    required this.name,
    required this.meta,
    required this.tag,
    required this.status,
    required this.date,
  });

  final String initials;
  final String name;
  final String meta;
  final String tag;
  final ClinicalStatus status;
  final String date;
}

const List<Patient> kSamplePatients = [
  Patient(
    initials: 'SR',
    name: 'Sofía Restrepo M.',
    meta: 'F · 2 a 3 m · 12.4 kg · 86.5 cm',
    tag: 'PC/E −2.300',
    status: ClinicalStatus.severe,
    date: 'hoy',
  ),
  Patient(
    initials: 'MG',
    name: 'Mateo Gómez A.',
    meta: 'M · 8 m · 8.1 kg · 69.0 cm',
    tag: 'Normal',
    status: ClinicalStatus.ok,
    date: '12 ago',
  ),
  Patient(
    initials: 'LT',
    name: 'Luciana Tovar B.',
    meta: 'F · 29+4 sem · 1420 g · Fenton',
    tag: 'P/EG p8',
    status: ClinicalStatus.warn,
    date: '11 ago',
  ),
  Patient(
    initials: 'JC',
    name: 'Julián Cárdenas R.',
    meta: 'M · 6 a 1 m · GMFCS V-TF',
    tag: 'PC · seguim.',
    status: ClinicalStatus.warn,
    date: '9 ago',
  ),
  Patient(
    initials: 'VA',
    name: 'Valentina Ardila P.',
    meta: 'F · 4 a 2 m · Down · 16.2 kg',
    tag: 'Normal',
    status: ClinicalStatus.ok,
    date: '8 ago',
  ),
  Patient(
    initials: 'SP',
    name: 'Samuel Peña L.',
    meta: 'M · 3 a 7 m · 19.8 kg · 98.0 cm',
    tag: 'IMC/E +2.140',
    status: ClinicalStatus.severe,
    date: '7 ago',
  ),
];

/// A stored measurement in a patient's history (design 1j).
class Measurement {
  const Measurement({
    required this.date,
    required this.summary,
    required this.age,
    required this.z,
    required this.status,
  });

  final String date;
  final String summary;
  final String age;
  final String z;
  final ClinicalStatus status;
}

const List<Measurement> kSampleHistory = [
  Measurement(
    date: '15 AGO 26',
    summary: '12.4 kg · 86.5 cm · PC 44.1',
    age: '2 a 3 m · 823 d · OMS',
    z: 'Z −0.420',
    status: ClinicalStatus.ok,
  ),
  Measurement(
    date: '15 JUN 26',
    summary: '12.0 kg · 85.4 cm · PC 43.9',
    age: '2 a 1 m · 762 d · OMS',
    z: 'Z −0.500',
    status: ClinicalStatus.ok,
  ),
  Measurement(
    date: '15 ABR 26',
    summary: '11.6 kg · 84.3 cm · PC 43.6',
    age: '1 a 11 m · 701 d · OMS',
    z: 'Z −0.580',
    status: ClinicalStatus.warn,
  ),
  Measurement(
    date: '15 FEB 26',
    summary: '11.1 kg · 82.9 cm · PC 43.2',
    age: '1 a 9 m · 642 d · OMS',
    z: 'Z −0.750',
    status: ClinicalStatus.warn,
  ),
];

/// Pure anthropometric helpers translated from the design's `renderVals`.
class Anthro {
  /// Curva de mediana de peso (kg) aproximada por edad en meses. Solo la usan
  /// las gráficas de `charts.dart` (fuera de alcance de este cálculo real).
  @Deprecated('Curva simulada; el cálculo real usa ReferenceTable / WHO LMS.')
  static double medianWeight(double months) =>
      3.3 + 6.5 * (1 - math.exp(-months / 4.5)) + 0.15 * months;

  static double? imc(double? kg, double? cm) {
    if (kg == null || cm == null || kg <= 0 || cm <= 0) return null;
    final m = cm / 100.0;
    return kg / (m * m);
  }

  /// Texto de plausibilidad bajo un campo numérico según su estado.
  /// La lógica de estado vive ahora en `lib/anthro/plausibility.dart`.
  static String plausibilityHint(ClinicalStatus s) {
    switch (s) {
      case ClinicalStatus.ok:
        return '✓ Valor plausible para la edad';
      case ClinicalStatus.warn:
        return '! Fuera del rango esperado (±3 DS)';
      case ClinicalStatus.none:
        return '';
      default:
        return '✕ Valor implausible — verificar';
    }
  }

  /// Nota de posición según la edad. Con `ageMonths` nulo (sin fechas aún)
  /// devuelve una nota neutra.
  static (String note, bool warning) positionNote(
      MeasurePosition pos, double? ageMonths) {
    if (ageMonths == null) {
      return ('Ingrese las fechas para validar la posición de medición.', false);
    }
    final standing = pos == MeasurePosition.standing;
    final mismatch = standing ? ageMonths < 24 : ageMonths >= 24;
    if (mismatch) {
      return (
        standing
            ? '! Menor de 24 meses: se recomienda longitud en decúbito. Si mide de pie, se suman 0.7 cm para comparar con la curva.'
            : '! Mayor de 24 meses: se recomienda talla de pie. Si mide acostado, se restan 0.7 cm para comparar con la curva.',
        true
      );
    }
    return (
      standing
          ? '✓ Talla de pie · correcto para 24 meses o más. Curva talla/edad.'
          : '✓ Longitud en decúbito · correcto para menores de 24 meses. Curva longitud/edad.',
      false
    );
  }
}
