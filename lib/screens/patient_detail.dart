import 'package:flutter/material.dart';
import '../theme.dart';
import '../data.dart';
import '../widgets.dart';
import '../charts.dart';
import 'common.dart';
import 'calculator.dart';

/// Patient file with measurement history (design 1j).
class PatientDetailScreen extends StatelessWidget {
  const PatientDetailScreen({super.key, required this.patient});
  final Patient patient;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Scaffold(
      backgroundColor: p.background,
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          // Header block.
          Container(
            color: p.surface,
            padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top),
            child: Container(
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: p.border)),
              ),
              padding: const EdgeInsets.fromLTRB(8, 8, 16, 14),
              child: Column(
                children: [
                  Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.of(context).maybePop(),
                        icon: Icon(Icons.arrow_back, color: p.primary, size: 22),
                        splashRadius: 22,
                      ),
                      Expanded(
                        child: Text('Ficha del paciente',
                            style: TextStyle(
                                fontSize: 15, fontWeight: FontWeight.w600, color: p.onSurface)),
                      ),
                      _pill(context, 'Editar'),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Row(
                      children: [
                        InitialsAvatar(patient.initials,
                            size: 48,
                            bg: p.isDark ? const Color(0xFF2A2036) : const Color(0xFFF0E6F3),
                            fg: p.isDark ? const Color(0xFFC79BD6) : const Color(0xFF7B4A8A)),
                        const SizedBox(width: 13),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(patient.name,
                                  style: TextStyle(
                                      fontSize: 18, fontWeight: FontWeight.w700, color: p.onSurface)),
                              const SizedBox(height: 3),
                              Text('F · 14/05/2024 · 2 a 3 m · TI 1.098.442.117',
                                  style: TextStyle(fontSize: 11.5, height: 1.4, color: p.muted)),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                          decoration: BoxDecoration(
                            color: p.okBg,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                  width: 5,
                                  height: 5,
                                  decoration: BoxDecoration(color: p.ok, shape: BoxShape.circle)),
                              const SizedBox(width: 5),
                              Text('Sinc. local',
                                  style: TextStyle(
                                      fontSize: 10.5, fontWeight: FontWeight.w500, color: p.okText)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Z summary tiles.
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Row(
              children: [
                Expanded(child: _zTile(context, 'Peso/Edad', '−0.42', p.onSurface)),
                const SizedBox(width: 9),
                Expanded(child: _zTile(context, 'Talla/Edad', '−1.15', p.warn)),
                const SizedBox(width: 9),
                Expanded(child: _zTile(context, 'PC/Edad', '−2.30', p.bad)),
              ],
            ),
          ),
          // Trend chart.
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: SectionCard(
              padding: const EdgeInsets.fromLTRB(12, 14, 12, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Trayectoria Peso/Edad',
                            style: TextStyle(
                                fontSize: 13, fontWeight: FontWeight.w600, color: p.onSurface)),
                        Text('4 mediciones',
                            style: TextStyle(fontSize: 10.5, color: p.muted)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  const ZScoreChart(dark: true),
                ],
              ),
            ),
          ),
          // History list.
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: SectionCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 11, 14, 11),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        SectionLabel('Historial de mediciones'),
                        Text('+ Añadir',
                            style: TextStyle(
                                fontSize: 11, fontWeight: FontWeight.w500, color: p.primary)),
                      ],
                    ),
                  ),
                  const ThinDivider(),
                  for (final m in kSampleHistory) _historyRow(context, m),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(
              children: [
                Expanded(
                  child: PrimaryButton('Nueva medición', onTap: () {
                    Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const CalculatorScreen()));
                  }),
                ),
                const SizedBox(width: 10),
                SecondaryButton('Exportar ficha', onTap: () {}),
              ],
            ),
          ),
          const Footer(),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _pill(BuildContext context, String label) {
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

  Widget _zTile(BuildContext context, String label, String z, Color color) {
    final p = AppPalette.of(context);
    return Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: p.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label.toUpperCase(),
              style: TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.5,
                  color: p.muted)),
          const SizedBox(height: 6),
          Text(z,
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  fontFeatures: kTabular,
                  color: color)),
        ],
      ),
    );
  }

  Widget _historyRow(BuildContext context, Measurement m) {
    final p = AppPalette.of(context);
    return Container(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: p.borderSoft)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          SizedBox(
            width: 46,
            child: Text(m.date,
                style: TextStyle(
                    fontSize: 11,
                    height: 1.2,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'monospace',
                    color: p.muted)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(m.summary,
                    style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                        fontFeatures: kTabular,
                        color: p.onSurface)),
                const SizedBox(height: 2),
                Text(m.age, style: TextStyle(fontSize: 10.5, height: 1.3, color: p.muted)),
              ],
            ),
          ),
          StatusChip(m.z, m.status),
        ],
      ),
    );
  }
}
