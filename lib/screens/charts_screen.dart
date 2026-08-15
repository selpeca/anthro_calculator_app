import 'package:flutter/material.dart';
import '../theme.dart';
import '../widgets.dart';
import '../charts.dart';
import 'common.dart';

/// Growth curves (design 1e): indicator tabs, LMS chart legend, and an
/// expandable quantitative deficit/excess analysis.
class ChartsScreen extends StatefulWidget {
  const ChartsScreen({super.key});

  @override
  State<ChartsScreen> createState() => _ChartsScreenState();
}

class _ChartsScreenState extends State<ChartsScreen> {
  int _tab = 0;
  bool _deficit = true;

  static const _tabs = ['Peso/Edad', 'Talla/Edad', 'IMC/Edad', 'PC/Edad'];

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Scaffold(
      backgroundColor: p.background,
      appBar: ScreenHeader(
        title: 'Curvas de crecimiento',
        subtitle: 'OMS · niñas 0–60 meses',
        trailing: _pdfPill(context),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
        children: [
          SizedBox(
            height: 34,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _tabs.length,
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
                    child: Text(_tabs[i],
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: active ? (p.isDark ? p.background : Colors.white) : p.muted)),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          SectionCard(
            padding: const EdgeInsets.fromLTRB(12, 14, 12, 10),
            child: Column(
              children: [
                const LmsChart(),
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
            ),
          ),
          const SizedBox(height: 12),
          SectionCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                InkWell(
                  onTap: () => setState(() => _deficit = !_deficit),
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
                        Chevron(expanded: _deficit),
                      ],
                    ),
                  ),
                ),
                AnimatedCrossFade(
                  duration: const Duration(milliseconds: 200),
                  crossFadeState:
                      _deficit ? CrossFadeState.showFirst : CrossFadeState.showSecond,
                  firstChild: _deficitTable(context),
                  secondChild: const SizedBox(width: double.infinity),
                ),
              ],
            ),
          ),
          const Footer(),
        ],
      ),
    );
  }

  Widget _pdfPill(BuildContext context) {
    final p = AppPalette.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: p.isDark ? p.border : const Color(0xFFCFE2EF)),
      ),
      child: Text('PDF',
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: p.primary)),
    );
  }

  Widget _legend(BuildContext context, Color color, String label, {bool line = false}) {
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

  Widget _deficitTable(BuildContext context) {
    final p = AppPalette.of(context);
    return Container(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: p.borderSoft)),
      ),
      padding: const EdgeInsets.fromLTRB(14, 4, 14, 12),
      child: Column(
        children: [
          _row(context, '+3 DS', '18.4 kg', '−6.00 kg', p.primary),
          _row(context, '+2 DS', '16.3 kg', '−3.90 kg', p.primary),
          _row(context, 'Mediana', '12.9 kg', '−0.50 kg (−3.9 %)', p.onSurface, strong: true),
          _row(context, '−2 DS', '10.2 kg', '+2.20 kg', p.ok),
          _row(context, '−3 DS', '9.2 kg', '+3.20 kg', p.ok, last: true),
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
                children: const [
                  TextSpan(text: 'Para alcanzar la mediana de peso a esta edad se requieren '),
                  TextSpan(text: '+0.50 kg', style: TextStyle(fontWeight: FontWeight.w700)),
                  TextSpan(text: '. Para salir de la zona de riesgo (−1 DS) el peso mínimo es '),
                  TextSpan(text: '11.4 kg', style: TextStyle(fontWeight: FontWeight.w700)),
                  TextSpan(text: '.'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(BuildContext context, String label, String abs, String delta, Color deltaColor,
      {bool strong = false, bool last = false}) {
    final p = AppPalette.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        border: last ? null : Border(bottom: BorderSide(color: p.borderSoft)),
        color: strong ? (p.isDark ? p.surfaceAlt : const Color(0xFFF7FAFC)) : null,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text.rich(
            TextSpan(
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: strong ? FontWeight.w600 : FontWeight.w500,
                  color: strong ? p.onSurface : p.muted),
              children: [
                TextSpan(text: '$label  '),
                TextSpan(
                    text: abs,
                    style: TextStyle(fontSize: 11, fontFamily: 'monospace', color: p.faint)),
              ],
            ),
          ),
          Text(delta,
              style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  fontFeatures: kTabular,
                  color: deltaColor)),
        ],
      ),
    );
  }
}
