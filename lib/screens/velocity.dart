import 'package:flutter/material.dart';
import '../theme.dart';
import '../widgets.dart';
import '../charts.dart';
import '../settings.dart';
import 'common.dart';

/// Growth velocity (design 1f): compares two evaluations and shows Δ weight/
/// height with velocity Z-scores and an increment history.
class VelocityScreen extends StatelessWidget {
  const VelocityScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Scaffold(
      backgroundColor: p.background,
      appBar: const ScreenHeader(
        title: 'Velocidad de crecimiento',
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
        children: [
          _evalCards(context, p),
          const SizedBox(height: 12),
          ValueListenableBuilder<UnitSystem>(
            valueListenable: unitSystemNotifier,
            builder: (context, activeUnit, _) {
              return IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: _deltaCard(context,
                          accent: p.ok,
                          label: 'Δ Peso',
                          value: '+1.30',
                          unit: activeUnit.weightUnit,
                          detail: '7.2 g/día · 218 g/mes',
                          chip: 'Vel. Z +0.34 · adecuada',
                          chipStatus: ClinicalStatus.ok),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _deltaCard(context,
                          accent: p.warn,
                          label: 'Δ Talla',
                          value: '+3.60',
                          unit: activeUnit.heightUnit,
                          detail: '7.3 cm/año esperado 9.1',
                          chip: 'Vel. Z −1.42 · lenta',
                          chipStatus: ClinicalStatus.warn),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          SectionCard(
            padding: const EdgeInsets.fromLTRB(12, 14, 12, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Progreso del Z-score',
                          style: TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w600, color: p.onSurface)),
                      Text('Peso/Edad · Talla/Edad',
                          style: TextStyle(fontSize: 10.5, color: p.muted)),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                const ZScoreChart(dark: false),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SectionCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 11, 14, 11),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: SectionLabel('Historial de incrementos'),
                  ),
                ),
                const ThinDivider(),
                _incRow(context, 'Feb → Abr 2026', '61 d · +0.5 kg · +1.4 cm', '8.2 g/d', p.ok),
                const ThinDivider(),
                _incRow(context, 'Abr → Jun 2026', '59 d · +0.4 kg · +1.1 cm', '6.8 g/d', p.warn),
                const ThinDivider(),
                _incRow(context, 'Jun → Ago 2026', '61 d · +0.4 kg · +1.1 cm', '6.6 g/d', p.ok, last: true),
              ],
            ),
          ),
          const Footer(),
        ],
      ),
    );
  }

  Widget _evalCards(BuildContext context, AppPalette p) {
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionLabel('Intervalo comparado'),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _evalBox(context,
                    label: 'Evaluación 1',
                    date: '15/02/2026',
                    meas: '11.1 kg · 82.9 cm',
                    selected: false),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Icon(Icons.arrow_forward, size: 16, color: p.primary),
              ),
              Expanded(
                child: _evalBox(context,
                    label: 'Evaluación 4',
                    date: '15/08/2026',
                    meas: '12.4 kg · 86.5 cm',
                    selected: true),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text('Intervalo: 181 días (5.95 meses)',
              style: TextStyle(fontSize: 11, fontFamily: 'monospace', color: p.muted)),
        ],
      ),
    );
  }

  Widget _evalBox(BuildContext context,
      {required String label,
      required String date,
      required String meas,
      required bool selected}) {
    final p = AppPalette.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 10),
      decoration: BoxDecoration(
        color: selected ? p.primaryTint : p.surfaceAlt,
        borderRadius: BorderRadius.circular(Radii.control),
        border: Border.all(
            color: selected ? p.primary : (p.isDark ? p.border : const Color(0xFFDDE4EA)),
            width: selected ? 1.5 : 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionLabel(label, color: selected ? p.primary : p.muted),
          const SizedBox(height: 4),
          Text(date,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  fontFeatures: kTabular,
                  color: selected ? p.onPrimaryTint : p.onSurface)),
          const SizedBox(height: 2),
          Text(meas,
              style: TextStyle(
                  fontSize: 11,
                  fontFeatures: kTabular,
                  color: selected ? p.onPrimaryTint : p.muted)),
        ],
      ),
    );
  }

  Widget _deltaCard(BuildContext context,
      {required Color accent,
      required String label,
      required String value,
      required String unit,
      required String detail,
      required String chip,
      required ClinicalStatus chipStatus}) {
    final p = AppPalette.of(context);
    return SectionCard(
      leftAccent: accent,
      padding: const EdgeInsets.all(13),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionLabel(label),
          const SizedBox(height: 6),
          Text.rich(
            TextSpan(
              style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  height: 1,
                  letterSpacing: -0.8,
                  fontFeatures: kTabular,
                  color: p.onSurface),
              children: [
                TextSpan(text: value),
                TextSpan(
                    text: ' $unit',
                    style: TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w500, color: p.muted, letterSpacing: 0)),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Text(detail,
              style: TextStyle(fontSize: 11, height: 1.3, fontFamily: 'monospace', color: p.muted)),
          const SizedBox(height: 8),
          StatusChip(chip, chipStatus),
        ],
      ),
    );
  }

  Widget _incRow(BuildContext context, String title, String detail, String rate, Color rateColor,
      {bool last = false}) {
    final p = AppPalette.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: TextStyle(
                      fontSize: 12.5, fontWeight: FontWeight.w500, color: p.onSurface)),
              const SizedBox(height: 2),
              Text(detail,
                  style: TextStyle(fontSize: 11, fontFeatures: kTabular, color: p.muted)),
            ],
          ),
          Text(rate,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  fontFeatures: kTabular,
                  color: rateColor)),
        ],
      ),
    );
  }
}
