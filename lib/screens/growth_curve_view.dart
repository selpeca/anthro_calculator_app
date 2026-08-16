/// Widget compartido de la curva de crecimiento LMS de un indicador con la
/// trayectoria del paciente. Lo usan tanto la pantalla completa de curvas
/// (`charts_screen.dart`) como la ficha del paciente (`patient_detail.dart`),
/// para no duplicar el armado de bandas y puntos.
library;

import 'package:flutter/material.dart';

import '../anthro/growth_curve.dart';
import '../anthro/indicators.dart';
import '../anthro/reference.dart';
import '../charts.dart';
import '../data.dart';
import '../db/models.dart';
import '../reference/reference_repository.dart';
import '../theme.dart';

/// Valor de la medida del indicador [kind] a partir de las medidas crudas.
/// Talla/Edad usa la talla ajustada por posición (igual que el cálculo del Z).
double? growthValue(
  IndicatorKind kind, {
  required double weightKg,
  required double statureCm,
  required MeasurePosition position,
  required int ageDays,
  double? bmi,
  double? headCircumferenceCm,
}) =>
    switch (kind) {
      IndicatorKind.weightForAge => weightKg,
      IndicatorKind.statureForAge => adjustedStature(statureCm, position, ageDays),
      IndicatorKind.bmiForAge => bmi,
      IndicatorKind.headCircumferenceForAge => headCircumferenceCm,
      IndicatorKind.weightForStature => weightKg,
    };

/// Puntos del paciente para el indicador [kind]: controles del [history]
/// (conectados) + la medición actual ([input]/[result]) resaltada. Solo se
/// incluyen puntos dentro del rango de la curva [table]; el actual se deduplica
/// del historial por [currentMeasurementId].
List<GrowthPoint> buildGrowthPoints({
  required IndicatorKind kind,
  required AnthroInput input,
  required AnthroResult result,
  required ReferenceTable table,
  List<SavedMeasurement> history = const [],
  int? currentMeasurementId,
}) {
  final points = <GrowthPoint>[];
  bool inRange(int d) => d >= table.minKey && d <= table.maxKey;

  for (final m in history) {
    if (currentMeasurementId != null && m.id == currentMeasurementId) continue;
    final v = growthValue(kind,
        weightKg: m.weightKg,
        statureCm: m.statureCm,
        position: m.position,
        ageDays: m.ageDays,
        bmi: m.bmi,
        headCircumferenceCm: m.headCircumferenceCm);
    if (v == null || v.isNaN || !inRange(m.ageDays)) continue;
    points.add(GrowthPoint(
      key: m.ageDays.toDouble(),
      value: v,
      status: _statusOf(m.indicators, kind),
    ));
  }

  final cv = growthValue(kind,
      weightKg: result.weightKg,
      statureCm: input.statureCm,
      position: input.position,
      ageDays: result.age.days,
      bmi: result.bmi,
      headCircumferenceCm: result.headCircumferenceCm);
  final cDays = result.age.days;
  if (cv != null && !cv.isNaN && inRange(cDays)) {
    final ind = _currentIndicatorOf(result, kind);
    points.add(GrowthPoint(
      key: cDays.toDouble(),
      value: cv,
      status: ind?.status ?? ClinicalStatus.none,
      isCurrent: true,
      callout: _calloutTitle(kind, cv, result),
      subCallout: _calloutSub(ind),
    ));
  }
  return points;
}

ClinicalStatus _statusOf(List<SavedIndicator> indicators, IndicatorKind kind) {
  final name = nameForIndicator(kind);
  for (final ind in indicators) {
    if (ind.name == name) return ind.status;
  }
  return ClinicalStatus.none;
}

Indicator? _currentIndicatorOf(AnthroResult result, IndicatorKind kind) {
  final name = nameForIndicator(kind);
  for (final ind in result.indicators) {
    if (ind.name == name) return ind;
  }
  return null;
}

String _calloutTitle(IndicatorKind kind, double value, AnthroResult result) {
  final months = result.age.decimalMonths.toStringAsFixed(1);
  final unit = unitForIndicator(kind);
  return '$months m · ${value.toStringAsFixed(1)} $unit';
}

String? _calloutSub(Indicator? ind) {
  if (ind == null || ind.z == null) return null;
  final z = ind.z!;
  final zStr = '${z >= 0 ? '+' : '−'}${z.abs().toStringAsFixed(2)}';
  final pct = ind.percentile;
  return pct == null ? 'Z $zStr' : 'Z $zStr · p${pct.round()}';
}

/// Curva LMS del indicador [kind] con la trayectoria del paciente. Toma la
/// referencia cargada en memoria (`ReferenceRepository`) y el historial.
class GrowthCurveChart extends StatelessWidget {
  const GrowthCurveChart({
    super.key,
    required this.kind,
    required this.input,
    required this.result,
    this.history = const [],
    this.currentMeasurementId,
    this.showLegend = true,
  });

  final IndicatorKind kind;
  final AnthroInput input;
  final AnthroResult result;
  final List<SavedMeasurement> history;
  final int? currentMeasurementId;

  /// Si muestra la leyenda de colores bajo la gráfica.
  final bool showLegend;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final ref = ReferenceRepository.reference(result.standardId);
    final table = ref?.tableFor(kind, result.sex, ageDays: result.age.days);
    if (table == null) {
      return Text('La referencia seleccionada no incluye esta curva.',
          style: TextStyle(fontSize: 11.5, height: 1.4, color: p.muted));
    }
    final bands = sampleBands(table);
    final points = buildGrowthPoints(
      kind: kind,
      input: input,
      result: result,
      table: table,
      history: history,
      currentMeasurementId: currentMeasurementId,
    );
    final (yMin, yMax) = valueRange(bands, points.map((e) => e.value));

    final chart = LmsChart(
      bands: bands,
      points: points,
      xMinKey: table.minKey,
      xMaxKey: table.maxKey,
      yMin: yMin,
      yMax: yMax,
    );
    if (!showLegend) return chart;

    return Column(
      children: [
        chart,
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.only(top: 10),
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: p.borderSoft)),
          ),
          child: Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              _legend(context, const Color(0xFF1E5F8C), 'Mediana (M)', line: true),
              _legend(context, const Color(0xFF7FB2D4), '±1 / ±2 DS', line: true),
              _legend(context, const Color(0xFFE3A2A2), '±3 DS', line: true),
              _legend(context, const Color(0xFFC0392B), 'Paciente'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _legend(BuildContext context, Color color, String label,
      {bool line = false}) {
    final p = AppPalette.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        line
            ? Container(width: 14, height: 2, color: color)
            : Container(
                width: 9,
                height: 9,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(fontSize: 10.5, color: p.muted)),
      ],
    );
  }
}
