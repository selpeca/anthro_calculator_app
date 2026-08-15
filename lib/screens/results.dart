import 'package:flutter/material.dart';
import '../theme.dart';
import '../data.dart';
import '../widgets.dart';
import '../anthro/indicators.dart';
import '../anthro/reference.dart';
import '../db/database.dart';
import 'common.dart';
import 'charts_screen.dart';

class ResultsScreen extends StatelessWidget {
  const ResultsScreen({
    super.key,
    required this.input,
    required this.result,
    this.savedMeasurementId,
    this.savedPatientName,
  });

  /// Entrada del cálculo; se persiste junto con el resultado.
  final AnthroInput input;
  final AnthroResult result;

  /// Si ya se guardó al calcular (opción "guardar en historial"), el id y el
  /// nombre permiten "Actualizar" en lugar de duplicar.
  final int? savedMeasurementId;
  final String? savedPatientName;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final sexLabel = result.sex == Sex.female ? 'F' : 'M';
    final subtitle = '${result.standardLabel} · $sexLabel · '
        '${result.age.decimalMonths.toStringAsFixed(1)} meses · ${result.age.days} d';
    return Scaffold(
      backgroundColor: p.background,
      appBar: ScreenHeader(
        title: 'Resultados',
        subtitle: subtitle,
        trailing: _pillButton(context, 'Exportar'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
        children: [
          // Legend opener.
          InkWell(
            onTap: () => showLegendSheet(context),
            borderRadius: BorderRadius.circular(Radii.card),
            child: SectionCard(
              child: Row(
                children: [
                  Container(
                    width: 26,
                    height: 26,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: p.isDark ? p.primaryTint : p.primaryTint,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text('?',
                        style: TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w700, color: p.primary)),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Text('¿Qué significa cada color?',
                        style: TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w500, color: p.muted)),
                  ),
                  Row(
                    children: [
                      _dot(p.ok),
                      const SizedBox(width: 4),
                      _dot(p.warn),
                      const SizedBox(width: 4),
                      _dot(p.bad),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          // Nutritional summary.
          SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Resumen nutricional',
                        style: TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w600, color: p.onSurface)),
                    StatusChip(result.overallLabel, result.overall),
                  ],
                ),
                const SizedBox(height: 11),
                Wrap(
                  spacing: 16,
                  runSpacing: 10,
                  children: [
                    _summaryStat(context, 'Peso', '${_fmt(result.weightKg)} kg'),
                    _summaryStat(context, 'Talla', '${_fmt(result.statureCm)} cm'),
                    _summaryStat(context, 'IMC',
                        result.bmi == null ? '—' : result.bmi!.toStringAsFixed(1)),
                    if (result.headCircumferenceCm != null)
                      _summaryStat(context, 'PC',
                          '${_fmt(result.headCircumferenceCm!)} cm',
                          color: _pcColor(p)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          // Indicator cards.
          for (final ind in result.indicators) ...[
            _IndicatorCard(indicator: ind),
            const SizedBox(height: 10),
          ],
          const SizedBox(height: 2),
          Row(
            children: [
              Expanded(
                child: PrimaryButton('Ver gráficas', onTap: () {
                  Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const ChartsScreen()));
                }),
              ),
              const SizedBox(width: 10),
              SecondaryButton(savedMeasurementId != null ? 'Actualizar' : 'Guardar',
                  onTap: () async {
                final target = await promptPatientName(context,
                    initialName: savedPatientName);
                if (target == null || !context.mounted) return;
                final savedId = savedMeasurementId;
                if (savedId != null) {
                  await AnthroDatabase.instance.updateMeasurement(
                    measurementId: savedId,
                    patientName: target.name,
                    patientId: target.patientId,
                    input: input,
                    result: result,
                  );
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text(
                            'Medición actualizada en el historial de ${target.name}')),
                  );
                } else {
                  await AnthroDatabase.instance.saveMeasurement(
                    patientName: target.name,
                    patientId: target.patientId,
                    input: input,
                    result: result,
                  );
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text(
                            'Medición guardada en el historial de ${target.name}')),
                  );
                }
              }),
            ],
          ),
          const Footer(),
        ],
      ),
    );
  }

  static Widget _dot(Color c) => Container(
        width: 9,
        height: 9,
        decoration: BoxDecoration(color: c, shape: BoxShape.circle),
      );

  static Widget _pillButton(BuildContext context, String label) {
    final p = AppPalette.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: p.isDark ? const Color(0xFF2B4356) : const Color(0xFFCFE2EF)),
      ),
      child: Text(label,
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: p.primary)),
    );
  }

  Widget _summaryStat(BuildContext context, String label, String value, {Color? color}) {
    final p = AppPalette.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        SectionLabel(label),
        const SizedBox(height: 2),
        Text(value,
            style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                fontFeatures: kTabular,
                color: color ?? p.onSurface)),
      ],
    );
  }

  static String _fmt(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);

  Color _pcColor(AppPalette p) {
    final pc = result.indicators.where((i) => i.name.startsWith('Perímetro'));
    if (pc.isEmpty || pc.first.status == ClinicalStatus.none) return p.onSurface;
    return p.statusColor(pc.first.status);
  }
}

class _IndicatorCard extends StatelessWidget {
  const _IndicatorCard({required this.indicator});
  final Indicator indicator;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final none = indicator.status == ClinicalStatus.none;
    final color = none ? p.faint : p.statusColor(indicator.status);
    final classColor = none
        ? p.faint
        : (indicator.status == ClinicalStatus.ok
            ? p.muted
            : p.statusText(indicator.status));
    final severe = indicator.status == ClinicalStatus.severe;

    final body = Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(indicator.name,
                  style: TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600, height: 1.2, color: p.onSurface)),
              const SizedBox(height: 5),
              Text(indicator.subtitle,
                  style: TextStyle(fontSize: 11.5, height: 1.3, color: classColor)),
              if (indicator.percentile != null) ...[
                const SizedBox(height: 8),
                PercentileBar(percentile: indicator.percentile!, color: color),
              ],
            ],
          ),
        ),
        const SizedBox(width: 14),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(indicator.zLabel,
                style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w700,
                    height: 1,
                    letterSpacing: -1,
                    fontFeatures: kTabular,
                    color: severe ? p.bad : (none ? p.faint : p.onSurface))),
            const SizedBox(height: 4),
            SectionLabel('Z-score'),
          ],
        ),
      ],
    );

    if (severe && indicator.deficitNote != null) {
      return SectionCard(
        background: p.isDark ? const Color(0x1FC0392B) : p.badBg,
        borderColor: p.isDark ? const Color(0xFF6E2A22) : p.badBg,
        leftAccent: p.bad,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            body,
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.only(top: 9),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: p.bad.withValues(alpha: 0.3))),
              ),
              child: Text(
                indicator.deficitNote!,
                style: TextStyle(fontSize: 11, height: 1.4, color: p.badText),
              ),
            ),
          ],
        ),
      );
    }

    return SectionCard(leftAccent: color, child: body);
  }
}

void showLegendSheet(BuildContext context) {
  final p = AppPalette.of(context);
  showModalBottomSheet(
    context: context,
    backgroundColor: p.surface,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(Radii.sheet)),
    ),
    builder: (context) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: p.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Semaforización de resultados',
                            style: TextStyle(
                                fontSize: 17, fontWeight: FontWeight.w700, color: p.onSurface)),
                        const SizedBox(height: 4),
                        Text(
                          'El color se aplica al borde de la tarjeta, al chip de clasificación y al punto sobre la curva.',
                          style: TextStyle(fontSize: 11.5, height: 1.4, color: p.muted),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      width: 28,
                      height: 28,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: p.segmentBg,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(Icons.close, size: 16, color: p.muted),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              // DS scale bar.
              Row(
                children: [
                  Expanded(flex: 1, child: _scaleSeg(p.bad)),
                  Expanded(flex: 1, child: _scaleSeg(p.warn)),
                  Expanded(flex: 2, child: _scaleSeg(p.ok)),
                  Expanded(flex: 1, child: _scaleSeg(p.warn)),
                  Expanded(flex: 1, child: _scaleSeg(p.bad)),
                ],
              ),
              const SizedBox(height: 5),
              DefaultTextStyle(
                style: TextStyle(fontSize: 9.5, fontFamily: 'monospace', color: p.faint),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: const [
                    Text('−3 DS'),
                    Text('−2 DS'),
                    Text('−1 DS'),
                    Text('+1 DS'),
                    Text('+2 DS'),
                    Text('+3 DS'),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              _legendRow(context, p.ok, 'Verde · Adecuado',
                  'Z entre −1 y +1 · percentil 15 a 85. Hallazgo normal; continuar controles de rutina.'),
              const SizedBox(height: 9),
              _legendRow(context, p.warn, 'Ámbar · Riesgo',
                  'Z entre −2 y −1, o entre +1 y +2 · percentil 3–15 / 85–97. Vigilar velocidad de crecimiento y citar control temprano.'),
              const SizedBox(height: 9),
              _legendRow(context, p.bad, 'Rojo · Alteración',
                  'Z menor a −2 o mayor a +2 · por debajo del percentil 3 o por encima del 97. Requiere conducta clínica y registro de la alerta.'),
              const SizedBox(height: 9),
              _legendRow(context, p.severe, 'Rojo intenso · Severo',
                  'Z menor a −3 o mayor a +3. Desnutrición u obesidad severa: manejo prioritario.'),
              const SizedBox(height: 9),
              _legendRow(context, p.faint, 'Gris · No interpretable',
                  'Dato faltante o edad fuera del rango de validez de la referencia seleccionada.'),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.only(top: 11),
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: p.borderSoft)),
                ),
                child: Text(
                  'Puntos de corte según OMS 2006/2007 y Resolución 2465 de 2016 (Colombia). El indicador IMC/Edad usa el corte de +1 DS para sobrepeso en menores de 5 años.',
                  style: TextStyle(fontSize: 10.5, height: 1.4, color: p.faint),
                ),
              ),
              const SizedBox(height: 12),
              PrimaryButton('Entendido', onTap: () => Navigator.of(context).pop()),
            ],
          ),
        ),
      );
    },
  );
}

Widget _scaleSeg(Color c) => Container(height: 12, color: c);

Widget _legendRow(BuildContext context, Color color, String title, String desc) {
  final p = AppPalette.of(context);
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
    decoration: BoxDecoration(
      color: color.withValues(alpha: p.isDark ? 0.12 : 0.06),
      borderRadius: BorderRadius.circular(11),
      border: Border.all(color: color.withValues(alpha: 0.3)),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 12,
          height: 12,
          margin: const EdgeInsets.only(top: 2),
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4)),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: TextStyle(
                      fontSize: 12.5, fontWeight: FontWeight.w600, color: p.onSurface)),
              const SizedBox(height: 3),
              Text(desc, style: TextStyle(fontSize: 11, height: 1.4, color: p.muted)),
            ],
          ),
        ),
      ],
    ),
  );
}
