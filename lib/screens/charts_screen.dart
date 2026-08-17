import 'package:flutter/material.dart';
import '../theme.dart';
import '../widgets.dart';
import '../anthro/growth_curve.dart';
import '../anthro/indicators.dart';
import '../anthro/lms.dart';
import '../anthro/reference.dart';
import '../db/database.dart';
import '../db/models.dart';
import '../export/measurement_pdf.dart';
import '../reference/reference_repository.dart';
import 'common.dart';
import 'growth_curve_view.dart';

/// Una pestaña de la pantalla de curvas: su etiqueta y el indicador que grafica.
class _CurveTab {
  const _CurveTab(this.label, this.kind);
  final String label;
  final IndicatorKind kind;
}

/// Curvas de crecimiento con datos reales del paciente: bandas LMS de la
/// referencia, trayectoria histórica (controles guardados) + punto de la
/// medición actual, y análisis cuantitativo frente a cada corte de DS.
class ChartsScreen extends StatefulWidget {
  const ChartsScreen({
    super.key,
    required this.input,
    required this.result,
    this.patientId,
    this.currentMeasurementId,
  });

  final AnthroInput input;
  final AnthroResult result;

  /// Paciente cuyo historial se superpone (o `null` si no está guardado).
  final int? patientId;

  /// Id de la medición actual dentro del historial, para no duplicarla como
  /// punto histórico y punto actual a la vez.
  final int? currentMeasurementId;

  @override
  State<ChartsScreen> createState() => _ChartsScreenState();
}

class _ChartsScreenState extends State<ChartsScreen> {
  int _tab = 0;
  bool _analysis = true;
  bool _exporting = false;
  List<SavedMeasurement> _history = const [];

  static const _allTabs = [
    _CurveTab('Peso/Edad', IndicatorKind.weightForAge),
    _CurveTab('Talla/Edad', IndicatorKind.statureForAge),
    _CurveTab('Peso/Talla', IndicatorKind.weightForStature),
    _CurveTab('IMC/Edad', IndicatorKind.bmiForAge),
    _CurveTab('PC/Edad', IndicatorKind.headCircumferenceForAge),
  ];

  AnthroResult get _result => widget.result;
  AnthroInput get _input => widget.input;

  /// Pestañas visibles: PC/Edad solo si se midió perímetro cefálico.
  List<_CurveTab> get _tabs => [
        for (final t in _allTabs)
          if (t.kind != IndicatorKind.headCircumferenceForAge ||
              _result.headCircumferenceCm != null)
            t,
      ];

  @override
  void initState() {
    super.initState();
    if (widget.patientId != null) _loadHistory();
  }

  Future<void> _loadHistory() async {
    final history =
        await AnthroDatabase.instance.measurementsForPatient(widget.patientId!);
    if (!mounted) return;
    setState(() => _history = history);
  }

  /// Valor de la medición actual para el indicador (misma regla que la gráfica).
  double? _currentValue(IndicatorKind kind) => growthValue(kind,
      weightKg: _result.weightKg,
      statureCm: _input.statureCm,
      position: _input.position,
      ageDays: _result.age.days,
      bmi: _result.bmi,
      headCircumferenceCm: _result.headCircumferenceCm);

  /// Clave con la que se consulta la curva del indicador: talla (cm) en
  /// Peso/Talla —indexada por talla— y día de vida en los indicadores por edad.
  double _axisKey(IndicatorKind kind) => growthAxisKey(kind,
      statureCm: _input.statureCm,
      position: _input.position,
      ageDays: _result.age.days);

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final tabs = _tabs;
    final tab = tabs[_tab.clamp(0, tabs.length - 1)];
    final ref = ReferenceRepository.reference(_result.standardId);
    final table = ref?.tableFor(tab.kind, _result.sex, ageDays: _result.age.days);
    final sexWord = _result.sex == Sex.female ? 'niñas' : 'niños';
    final stdShort = _result.standardId.startsWith('oms') ? 'OMS' : 'Colombia';

    return Scaffold(
      backgroundColor: p.background,
      appBar: ScreenHeader(
        title: 'Curvas de crecimiento',
        subtitle: '$stdShort · $sexWord',
        trailing: _pdfPill(context),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
        children: [
          SizedBox(
            height: 34,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: tabs.length,
              separatorBuilder: (_, _) => const SizedBox(width: 6),
              itemBuilder: (context, i) {
                final active = i == _tab;
                return GestureDetector(
                  onTap: () => setState(() => _tab = i),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 13),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: active ? p.primary : p.surface,
                      borderRadius: BorderRadius.circular(999),
                      border: active ? null : Border.all(color: p.border),
                    ),
                    child: Text(tabs[i].label,
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: active
                                ? (p.isDark ? p.background : Colors.white)
                                : p.muted)),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          SectionCard(
            padding: const EdgeInsets.fromLTRB(12, 14, 12, 10),
            child: GrowthCurveChart(
              key: ValueKey(tab.kind),
              kind: tab.kind,
              input: _input,
              result: _result,
              history: _history,
              currentMeasurementId: widget.currentMeasurementId,
            ),
          ),
          const SizedBox(height: 12),
          _analysisCard(context, tab, table),
          const Footer(),
        ],
      ),
    );
  }

  // ── Análisis cuantitativo ──────────────────────────────────────────────────

  Widget _analysisCard(BuildContext context, _CurveTab tab, ReferenceTable? table) {
    final p = AppPalette.of(context);
    final lms = table?.lmsAt(_axisKey(tab.kind));
    final cv = _currentValue(tab.kind);
    final canShow = lms != null && cv != null && !cv.isNaN;

    return SectionCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          InkWell(
            onTap: canShow ? () => setState(() => _analysis = !_analysis) : null,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Análisis cuantitativo',
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: p.onSurface)),
                        const SizedBox(height: 2),
                        Text('Déficit / exceso frente a cada curva',
                            style: TextStyle(fontSize: 11, color: p.muted)),
                      ],
                    ),
                  ),
                  if (canShow) Chevron(expanded: _analysis),
                ],
              ),
            ),
          ),
          if (canShow)
            AnimatedCrossFade(
              duration: const Duration(milliseconds: 200),
              crossFadeState:
                  _analysis ? CrossFadeState.showFirst : CrossFadeState.showSecond,
              firstChild: _analysisTable(context, tab.kind, lms, cv),
              secondChild: const SizedBox(width: double.infinity),
            )
          else
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: Text(
                  'Sin análisis: la medición está fuera del rango de la curva.',
                  style: TextStyle(fontSize: 11.5, height: 1.4, color: p.muted)),
            ),
        ],
      ),
    );
  }

  Widget _analysisTable(
      BuildContext context, IndicatorKind kind, Lms lms, double patientValue) {
    final p = AppPalette.of(context);
    final unit = unitForIndicator(kind);
    final rows = deficitRows(lms, patientValue);
    final median = valueFromLms(0, lms);
    final gainToMedian = median - patientValue;
    final belowMedian = gainToMedian >= 0;
    // Umbral de la zona sana más cercano: −1 DS si está por debajo, +1 si arriba.
    final riskZ = belowMedian ? -1.0 : 1.0;
    final riskValue = valueFromLms(riskZ, lms);
    // En Peso/Talla la mediana es la del peso para esa talla, no para esa edad.
    final atLabel = kind == IndicatorKind.weightForStature
        ? 'a esta talla'
        : 'a esta edad';

    return Container(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: p.borderSoft)),
      ),
      padding: const EdgeInsets.fromLTRB(14, 4, 14, 12),
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++)
            _row(context, rows[i], unit, last: i == rows.length - 1),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            decoration: BoxDecoration(
              color: p.primaryTint,
              borderRadius: BorderRadius.circular(Radii.control),
            ),
            child: Text.rich(
              TextSpan(
                style: TextStyle(fontSize: 11.5, height: 1.45, color: p.onPrimaryTint),
                children: belowMedian
                    ? [
                        TextSpan(
                            text: 'Para alcanzar la mediana $atLabel se requieren '),
                        TextSpan(
                            text: '+${gainToMedian.abs().toStringAsFixed(2)} $unit',
                            style: const TextStyle(fontWeight: FontWeight.w700)),
                        const TextSpan(
                            text: '. El umbral de la zona de riesgo (−1 DS) es '),
                        TextSpan(
                            text: '${riskValue.toStringAsFixed(1)} $unit',
                            style: const TextStyle(fontWeight: FontWeight.w700)),
                        const TextSpan(text: '.'),
                      ]
                    : [
                        const TextSpan(text: 'La medición está '),
                        TextSpan(
                            text: '+${gainToMedian.abs().toStringAsFixed(2)} $unit',
                            style: const TextStyle(fontWeight: FontWeight.w700)),
                        const TextSpan(
                            text: ' por encima de la mediana. El umbral de la zona de '
                                'riesgo (+1 DS) es '),
                        TextSpan(
                            text: '${riskValue.toStringAsFixed(1)} $unit',
                            style: const TextStyle(fontWeight: FontWeight.w700)),
                        const TextSpan(text: '.'),
                      ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(BuildContext context, DeficitRow row, String unit, {bool last = false}) {
    final p = AppPalette.of(context);
    final median = row.z == 0;
    final abs = '${row.value.toStringAsFixed(1)} $unit';
    final deltaColor = median
        ? p.onSurface
        : (row.z > 0 ? p.primary : p.ok);
    final deltaSign = row.delta >= 0 ? '+' : '−';
    var deltaText = '$deltaSign${row.delta.abs().toStringAsFixed(2)} $unit';
    if (median) {
      final pct = row.value == 0 ? 0.0 : row.delta / row.value * 100;
      final pctSign = pct >= 0 ? '+' : '−';
      deltaText = '$deltaText ($pctSign${pct.abs().toStringAsFixed(1)} %)';
    }
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        border: last ? null : Border(bottom: BorderSide(color: p.borderSoft)),
        color: median ? (p.isDark ? p.surfaceAlt : const Color(0xFFF7FAFC)) : null,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text.rich(
              TextSpan(
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: median ? FontWeight.w600 : FontWeight.w500,
                    color: median ? p.onSurface : p.muted),
                children: [
                  TextSpan(text: '${_zLabel(row.z)}  '),
                  TextSpan(
                      text: abs,
                      style: TextStyle(
                          fontSize: 11, fontFamily: 'monospace', color: p.faint)),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(deltaText,
              style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  fontFeatures: kTabular,
                  color: deltaColor)),
        ],
      ),
    );
  }

  String _zLabel(double z) => z == 0
      ? 'Mediana'
      : '${z > 0 ? '+' : '−'}${z.abs().toStringAsFixed(0)} DS';

  /// Genera el PDF de las curvas y abre la hoja de compartir. El nombre del
  /// paciente se toma del historial cargado (todas las mediciones son del mismo
  /// paciente); `null` si la medición aún no está guardada.
  Future<void> _exportPdf() async {
    if (_exporting) return;
    setState(() => _exporting = true);
    try {
      await exportChartsPdf(
        context,
        input: _input,
        result: _result,
        history: _history,
        currentMeasurementId: widget.currentMeasurementId,
        patientName: _history.isNotEmpty ? _history.first.patientName : null,
      );
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Widget _pdfPill(BuildContext context) {
    final p = AppPalette.of(context);
    return GestureDetector(
      onTap: _exporting ? null : _exportPdf,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: p.isDark ? p.border : const Color(0xFFCFE2EF)),
        ),
        child: _exporting
            ? SizedBox(
                width: 22,
                height: 13,
                child: Center(
                  child: SizedBox(
                    width: 11,
                    height: 11,
                    child: CircularProgressIndicator(
                        strokeWidth: 1.6, color: p.primary),
                  ),
                ),
              )
            : Text('PDF',
                style: TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w500, color: p.primary)),
      ),
    );
  }
}
