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

/// A single anthropometric indicator result (a Z-score against a curve).
class Indicator {
  const Indicator({
    required this.name,
    required this.value,
    required this.median,
    required this.z,
    required this.percentile,
    required this.classification,
    required this.status,
  });

  final String name;
  final String value;
  final String median;
  final double z;
  final int percentile;
  final String classification;
  final ClinicalStatus status;

  String get zLabel => '${z > 0 ? '+' : '−'}${z.abs().toStringAsFixed(2)}';
}

/// The result set shown on the design's "Resultados" screen (1d).
const List<Indicator> kSampleIndicators = [
  Indicator(
    name: 'Peso / Talla',
    value: '12.4 kg',
    median: '12.1',
    z: 0.31,
    percentile: 62,
    classification: 'Peso adecuado para la talla',
    status: ClinicalStatus.ok,
  ),
  Indicator(
    name: 'Peso / Edad',
    value: '12.4 kg',
    median: '12.9',
    z: -0.42,
    percentile: 34,
    classification: 'Peso normal',
    status: ClinicalStatus.ok,
  ),
  Indicator(
    name: 'Talla / Edad',
    value: '86.5 cm',
    median: '89.9',
    z: -1.15,
    percentile: 13,
    classification: 'Riesgo de talla baja',
    status: ClinicalStatus.warn,
  ),
  Indicator(
    name: 'IMC / Edad',
    value: '16.6',
    median: '16.4',
    z: 0.28,
    percentile: 61,
    classification: 'Estado nutricional normal',
    status: ClinicalStatus.ok,
  ),
  Indicator(
    name: 'Perímetro cefálico / Edad',
    value: '44.1 cm',
    median: '47.2',
    z: -2.30,
    percentile: 1,
    classification: 'Microcefalia — requiere valoración',
    status: ClinicalStatus.severe,
  ),
];

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
    tag: 'PC/E −2.30',
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
    tag: 'IMC/E +2.14',
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
    z: 'Z −0.42',
    status: ClinicalStatus.ok,
  ),
  Measurement(
    date: '15 JUN 26',
    summary: '12.0 kg · 85.4 cm · PC 43.9',
    age: '2 a 1 m · 762 d · OMS',
    z: 'Z −0.50',
    status: ClinicalStatus.ok,
  ),
  Measurement(
    date: '15 ABR 26',
    summary: '11.6 kg · 84.3 cm · PC 43.6',
    age: '1 a 11 m · 701 d · OMS',
    z: 'Z −0.58',
    status: ClinicalStatus.warn,
  ),
  Measurement(
    date: '15 FEB 26',
    summary: '11.1 kg · 82.9 cm · PC 43.2',
    age: '1 a 9 m · 642 d · OMS',
    z: 'Z −0.75',
    status: ClinicalStatus.warn,
  ),
];

/// Pure anthropometric helpers translated from the design's `renderVals`.
class Anthro {
  /// Approx. reference median weight curve (kg) by age in months, used by the
  /// LMS chart. Matches `M(t)` in the design script.
  static double medianWeight(double months) =>
      3.3 + 6.5 * (1 - math.exp(-months / 4.5)) + 0.15 * months;

  static double? imc(double? kg, double? cm) {
    if (kg == null || cm == null || kg <= 0 || cm <= 0) return null;
    final m = cm / 100.0;
    return kg / (m * m);
  }

  /// Plausibility state for a weight value (kg) at ~27 months, per the design.
  static ClinicalStatus weightState(double? kg) {
    if (kg == null || kg == 0) return ClinicalStatus.bad;
    if (kg < 6 || kg > 30) return ClinicalStatus.bad;
    if (kg < 9.5 || kg > 17) return ClinicalStatus.warn;
    return ClinicalStatus.ok;
  }

  static ClinicalStatus heightState(double? cm) {
    if (cm == null || cm == 0) return ClinicalStatus.bad;
    if (cm < 60 || cm > 130) return ClinicalStatus.bad;
    if (cm < 80 || cm > 97) return ClinicalStatus.warn;
    return ClinicalStatus.ok;
  }

  static String plausibilityHint(ClinicalStatus s) {
    switch (s) {
      case ClinicalStatus.ok:
        return '✓ Valor plausible para la edad';
      case ClinicalStatus.warn:
        return '! Fuera del rango esperado (−2/+2 DS)';
      default:
        return '✕ Valor implausible — verificar';
    }
  }

  /// Position note. `ageMonths` fixed to the sample patient (27 m).
  static (String note, bool warning) positionNote(
      MeasurePosition pos, double ageMonths) {
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
