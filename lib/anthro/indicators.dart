/// Motor de indicadores antropométricos: de las medidas de entrada a la lista
/// de Z-scores clasificados que muestra la pantalla de resultados.
///
/// Sin dependencias de Flutter. Ver `test/anthro/indicators_test.dart`.
library;

import '../data.dart';
import '../theme.dart' show ClinicalStatus;
import 'age.dart';
import 'lms.dart';
import 'reference.dart';

/// Entrada del cálculo. Las fechas ya deben estar validadas por la UI.
class AnthroInput {
  const AnthroInput({
    required this.birthDate,
    required this.measurementDate,
    required this.sex,
    required this.weightKg,
    required this.statureCm,
    required this.position,
    required this.standardId,
    this.headCircumferenceCm,
  });

  final DateTime birthDate;
  final DateTime measurementDate;
  final Sex sex;
  final double weightKg;

  /// Talla o longitud tal como se midió (cruda; el ajuste de 0.7 cm es interno).
  final double statureCm;
  final MeasurePosition position;

  /// Perímetro cefálico (cm) o `null` si no se midió.
  final double? headCircumferenceCm;

  /// Id del estándar de referencia (`'oms-2006'`, `'col-2465'`).
  final String standardId;
}

/// Resultado completo del cálculo.
class AnthroResult {
  const AnthroResult({
    required this.age,
    required this.sex,
    required this.standardId,
    required this.standardLabel,
    required this.weightKg,
    required this.statureCm,
    required this.headCircumferenceCm,
    required this.bmi,
    required this.indicators,
    required this.overall,
    required this.overallLabel,
  });

  final Age age;
  final Sex sex;
  final String standardId;
  final String standardLabel;
  final double weightKg;
  final double statureCm;
  final double? headCircumferenceCm;
  final double? bmi;
  final List<Indicator> indicators;

  /// Peor estado interpretable del conjunto (para el chip global).
  final ClinicalStatus overall;
  final String overallLabel;
}

/// Color clínico a partir del Z, alineado con la leyenda de la app:
/// |Z|>3 severo · |Z|>2 rojo · |Z|>1 ámbar · resto verde. `>` estricto:
/// |Z|==1 es verde y |Z|==2 es ámbar.
ClinicalStatus statusFromZ(double z) {
  final a = z.abs();
  if (a > 3) return ClinicalStatus.severe;
  if (a > 2) return ClinicalStatus.bad;
  if (a > 1) return ClinicalStatus.warn;
  return ClinicalStatus.ok;
}

/// Indicadores basados en peso: la OMS aplana la cola |Z|>3.
const _weightBased = {
  IndicatorKind.weightForAge,
  IndicatorKind.weightForStature,
  IndicatorKind.bmiForAge,
};

const _kindNames = {
  IndicatorKind.weightForAge: 'Peso / Edad',
  IndicatorKind.statureForAge: 'Talla / Edad',
  IndicatorKind.weightForStature: 'Peso / Talla',
  IndicatorKind.bmiForAge: 'IMC / Edad',
  IndicatorKind.headCircumferenceForAge: 'Perímetro cefálico / Edad',
};

/// Ajusta la talla/longitud para consultar la curva (no para mostrar).
///
/// < 24 meses medido de pie → +0.7 cm; ≥ 24 meses medido acostado → −0.7 cm.
double adjustedStature(double measuredCm, MeasurePosition pos, int ageDays) {
  final underTwo = ageDays < kLengthHeightCutDays;
  if (underTwo && pos == MeasurePosition.standing) return measuredCm + 0.7;
  if (!underTwo && pos == MeasurePosition.lying) return measuredCm - 0.7;
  return measuredCm;
}

const _overallLabels = {
  ClinicalStatus.ok: 'Adecuado',
  ClinicalStatus.warn: 'Riesgo',
  ClinicalStatus.bad: 'Alteración',
  ClinicalStatus.severe: 'Severo',
  ClinicalStatus.none: 'Sin datos',
};

/// Calcula todos los indicadores para `input` contra `ref`.
AnthroResult computeAnthro(AnthroInput input, GrowthReference ref) {
  final age = ageBetween(input.birthDate, input.measurementDate);
  final bmi = Anthro.imc(input.weightKg, input.statureCm);
  final indicators = <Indicator>[];

  // Peso/Edad.
  indicators.add(_ageIndicator(
      ref, IndicatorKind.weightForAge, input.sex, age, input.weightKg));

  // Talla/Edad — usa la talla ajustada por posición.
  final adj = adjustedStature(input.statureCm, input.position, age.days);
  indicators.add(_ageIndicator(
      ref, IndicatorKind.statureForAge, input.sex, age, adj));

  // Peso/Talla — eje de talla (ajustada), pero también gated por edad.
  indicators.add(_statureIndicator(ref, input.sex, age, input.weightKg, adj));

  // IMC/Edad.
  indicators.add(_ageIndicator(
      ref, IndicatorKind.bmiForAge, input.sex, age, bmi ?? 0));

  // PC/Edad — solo si se midió.
  if (input.headCircumferenceCm != null) {
    indicators.add(_ageIndicator(ref, IndicatorKind.headCircumferenceForAge,
        input.sex, age, input.headCircumferenceCm!));
  }

  // Estado global: el peor entre los interpretables.
  var overall = ClinicalStatus.none;
  for (final ind in indicators) {
    if (ind.status == ClinicalStatus.none) continue;
    if (_severity(ind.status) > _severity(overall)) overall = ind.status;
  }

  return AnthroResult(
    age: age,
    sex: input.sex,
    standardId: ref.standardId,
    standardLabel: ref.displayName,
    weightKg: input.weightKg,
    statureCm: input.statureCm,
    headCircumferenceCm: input.headCircumferenceCm,
    bmi: bmi,
    indicators: indicators,
    overall: overall,
    overallLabel: _overallLabels[overall] ?? '—',
  );
}

int _severity(ClinicalStatus s) => switch (s) {
      ClinicalStatus.none => -1,
      ClinicalStatus.ok => 0,
      ClinicalStatus.warn => 1,
      ClinicalStatus.bad => 2,
      ClinicalStatus.severe => 3,
    };

Indicator _notInterpretable(IndicatorKind kind, String reason) => Indicator(
      name: _kindNames[kind]!,
      z: null,
      percentile: null,
      percentileLabel: null,
      classification: 'No interpretable',
      status: ClinicalStatus.none,
      deficitNote: reason,
    );

Indicator _ageIndicator(GrowthReference ref, IndicatorKind kind, Sex sex,
    Age age, double value) {
  final window = ref.ageWindow(kind);
  if (window != null && !window.contains(age.days)) {
    return _notInterpretable(kind,
        'Edad fuera del rango de la referencia (0–${(window.maxDays / 365.25).floor()} años).');
  }
  final table = ref.tableFor(kind, sex, ageDays: age.days);
  final lms = table?.lmsAt(age.days.toDouble());
  if (lms == null) {
    return _notInterpretable(kind, 'Fuera del rango de la referencia.');
  }
  return _build(ref, kind, value, lms);
}

Indicator _statureIndicator(
    GrowthReference ref, Sex sex, Age age, double weightKg, double statureCm) {
  const kind = IndicatorKind.weightForStature;
  final window = ref.ageWindow(kind);
  if (window != null && !window.contains(age.days)) {
    return _notInterpretable(kind,
        'Edad fuera del rango de la referencia (0–5 años).');
  }
  final table = ref.tableFor(kind, sex, ageDays: age.days);
  final lms = table?.lmsAt(statureCm);
  if (lms == null) {
    final range = age.days < kLengthHeightCutDays ? '45–110 cm' : '65–120 cm';
    return _notInterpretable(
        kind, 'Talla fuera del rango de la curva peso/talla ($range).');
  }
  return _build(ref, kind, weightKg, lms);
}

Indicator _build(
    GrowthReference ref, IndicatorKind kind, double value, Lms lms) {
  final z = _weightBased.contains(kind)
      ? restrictedZ(value, lms)
      : rawZFromLms(value, lms);
  if (z.isNaN) {
    return _notInterpretable(kind, 'Valor fuera del dominio de la curva.');
  }
  final status = statusFromZ(z);
  String? deficit;
  if (status == ClinicalStatus.severe && z < 0) {
    // Déficit real frente al corte −2 DS, en la unidad de la medida.
    final cut = valueFromLms(-2, lms);
    final unit = _unitFor(kind);
    deficit = 'Déficit frente a −2 DS: '
        '${(cut - value).abs().toStringAsFixed(2)} $unit. '
        'Confirmar técnica de medición y comparar con controles previos.';
  }
  return Indicator(
    name: _kindNames[kind]!,
    z: z,
    percentile: percentileFromZ(z),
    percentileLabel: percentileLabel(z),
    classification: ref.classify(kind, z),
    status: status,
    deficitNote: deficit,
  );
}

String _unitFor(IndicatorKind kind) => switch (kind) {
      IndicatorKind.weightForAge => 'kg',
      IndicatorKind.weightForStature => 'kg',
      IndicatorKind.bmiForAge => 'kg/m²',
      IndicatorKind.statureForAge => 'cm',
      IndicatorKind.headCircumferenceForAge => 'cm',
    };
