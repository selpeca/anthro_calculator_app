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

/// Pure anthropometric helpers translated from the design's `renderVals`.
class Anthro {
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
