import 'package:flutter/material.dart';
import '../theme.dart';
import '../data.dart';
import '../widgets.dart';
import 'common.dart';
import 'results.dart';

import '../settings.dart';

class CalculatorScreen extends StatefulWidget {
  const CalculatorScreen({super.key});

  @override
  State<CalculatorScreen> createState() => _CalculatorScreenState();
}

class _CalculatorScreenState extends State<CalculatorScreen> {
  final _peso = TextEditingController(text: '12.4');
  final _talla = TextEditingController(text: '86.5');
  RefStandard _ref = RefStandard.oms;
  bool _female = true;
  MeasurePosition _pos = MeasurePosition.standing;
  bool _save = true;

  static const double _ageMonths = 27.0;

  @override
  void initState() {
    super.initState();
    _peso.addListener(() => setState(() {}));
    _talla.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _peso.dispose();
    _talla.dispose();
    super.dispose();
  }

  double? get _pesoVal => double.tryParse(_peso.text.replaceAll(',', '.'));
  double? get _tallaVal => double.tryParse(_talla.text.replaceAll(',', '.'));

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final pesoState = Anthro.weightState(_pesoVal);
    final tallaState = Anthro.heightState(_tallaVal);
    final imc = Anthro.imc(_pesoVal, _tallaVal);
    final (posNote, posWarn) = Anthro.positionNote(_pos, _ageMonths);

    return Scaffold(
      backgroundColor: p.background,
      appBar: ScreenHeader(
        title: 'Cálculo antropométrico',
        subtitle: 'Sofía Restrepo M. · ${_female ? 'F' : 'M'}',
        statusDot: p.ok,
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
              children: [
                // ── Identity & age ─────────────────────────────
                SectionCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SectionLabel('Identificación y edad'),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(child: _dateField('F. nacimiento', '14/05/2024')),
                          const SizedBox(width: 10),
                          Expanded(child: _dateField('F. medición', '15/08/2026')),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              decoration: BoxDecoration(
                                color: p.primaryTint,
                                borderRadius: BorderRadius.circular(Radii.control),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  SectionLabel('Edad calculada', color: p.primary),
                                  const SizedBox(height: 3),
                                  Text('2 a 3 m 1 d',
                                      style: TextStyle(
                                          fontSize: 17,
                                          fontWeight: FontWeight.w700,
                                          fontFeatures: kTabular,
                                          color: p.onPrimaryTint)),
                                  const SizedBox(height: 2),
                                  Text('823 días de vida · 27.0 meses',
                                      style: TextStyle(
                                          fontSize: 11,
                                          fontFamily: 'monospace',
                                          color: p.isDark ? p.muted : const Color(0xFF3F7EA8))),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SectionLabel('Sexo'),
                              const SizedBox(height: 6),
                              SizedBox(
                                width: 96,
                                child: SegmentedControl(
                                  options: const ['F', 'M'],
                                  selectedIndex: _female ? 0 : 1,
                                  onChanged: (i) => setState(() => _female = i == 0),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                // ── Reference standard ─────────────────────────
                SectionCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          SectionLabel('Estándar de referencia'),
                          Text('Detalle',
                              style: TextStyle(
                                  fontSize: 11, fontWeight: FontWeight.w500, color: p.primary)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      SegmentedControl(
                        options: const ['OMS', 'Colombia'],
                        selectedIndex: _ref == RefStandard.oms ? 0 : 1,
                        onChanged: (i) => setState(
                            () => _ref = i == 0 ? RefStandard.oms : RefStandard.colombia),
                      ),
                      const SizedBox(height: 12),
                      Text(_ref.note,
                          style: TextStyle(fontSize: 11.5, height: 1.4, color: p.muted)),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                // ── Measurements ───────────────────────────────
                SectionCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          SectionLabel('Medidas'),
                          Text('Teclado numérico · decimal',
                              style: TextStyle(fontSize: 10, color: p.muted)),
                        ],
                      ),
                      const SizedBox(height: 11),
                      SectionLabel('Posición de la medición'),
                      const SizedBox(height: 7),
                      SegmentedControl(
                        options: const ['De pie · talla', 'Acostado · longitud'],
                        selectedIndex: _pos == MeasurePosition.standing ? 0 : 1,
                        onChanged: (i) => setState(() => _pos =
                            i == 0 ? MeasurePosition.standing : MeasurePosition.lying),
                      ),
                      const SizedBox(height: 7),
                      Text(posNote,
                          style: TextStyle(
                              fontSize: 10.5,
                              height: 1.35,
                              fontWeight: FontWeight.w500,
                              color: posWarn ? p.warnText : p.ok)),
                      const SizedBox(height: 11),
                      ValueListenableBuilder<UnitSystem>(
                        valueListenable: unitSystemNotifier,
                        builder: (context, activeUnit, _) {
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: _numberField(
                                  label: 'Peso',
                                  controller: _peso,
                                  unit: activeUnit.weightUnit,
                                  state: pesoState,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _numberField(
                                  label: _pos == MeasurePosition.standing
                                      ? 'Talla (de pie)'
                                      : 'Longitud (acostado)',
                                  controller: _talla,
                                  unit: activeUnit.heightUnit,
                                  state: tallaState,
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 11),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SectionLabel('Perímetro cefálico'),
                                const SizedBox(height: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                                  decoration: BoxDecoration(
                                    color: p.warnBg,
                                    borderRadius: BorderRadius.circular(Radii.control),
                                    border: Border.all(color: p.warn, width: 1.5),
                                  ),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.baseline,
                                    textBaseline: TextBaseline.alphabetic,
                                    children: [
                                      Expanded(
                                        child: Text('44.1',
                                            style: TextStyle(
                                                fontSize: 18,
                                                fontWeight: FontWeight.w600,
                                                fontFeatures: kTabular,
                                                color: p.warnText)),
                                      ),
                                      Text('cm',
                                          style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w500,
                                              color: p.warnText)),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    Container(
                                      width: 5,
                                      height: 5,
                                      decoration: BoxDecoration(color: p.warn, shape: BoxShape.circle),
                                    ),
                                    const SizedBox(width: 5),
                                    Expanded(
                                      child: Text('Alerta clínica: bajo −2 DS',
                                          style: TextStyle(
                                              fontSize: 10.5,
                                              height: 1.3,
                                              fontWeight: FontWeight.w500,
                                              color: p.warnText)),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SectionLabel('IMC (calculado)'),
                                const SizedBox(height: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                                  decoration: BoxDecoration(
                                    color: p.isDark ? p.surfaceAlt : const Color(0xFFF7F9FB),
                                    borderRadius: BorderRadius.circular(Radii.control),
                                    border: Border.all(
                                        color: p.isDark ? p.border : const Color(0xFFCFD8DF)),
                                  ),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.baseline,
                                    textBaseline: TextBaseline.alphabetic,
                                    children: [
                                      Expanded(
                                        child: Text(imc == null ? '—' : imc.toStringAsFixed(1),
                                            style: TextStyle(
                                                fontSize: 18,
                                                fontWeight: FontWeight.w700,
                                                fontFeatures: kTabular,
                                                color: p.onSurface)),
                                      ),
                                      Text('kg/m²',
                                          style: TextStyle(
                                              fontSize: 11, fontWeight: FontWeight.w500, color: p.muted)),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text('Automático desde peso y talla',
                                    style: TextStyle(fontSize: 10.5, height: 1.3, color: p.faint)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                // ── Save toggle ────────────────────────────────
                InkWell(
                  onTap: () => setState(() => _save = !_save),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
                    child: Row(
                      children: [
                        Container(
                          width: 16,
                          height: 16,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: _save ? p.primary : Colors.transparent,
                            borderRadius: BorderRadius.circular(5),
                            border: Border.all(color: p.primary, width: 1.5),
                          ),
                          child: _save
                              ? Icon(Icons.check, size: 11, color: p.isDark ? p.background : Colors.white)
                              : null,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                              'Guardar esta medición en el historial del paciente',
                              style: TextStyle(fontSize: 12, height: 1.3, color: p.muted)),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          // ── Sticky action bar ─────────────────────────────────
          Container(
            padding: EdgeInsets.fromLTRB(16, 14, 16, 16 + MediaQuery.of(context).padding.bottom),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [p.background, p.background.withValues(alpha: 0)],
                stops: const [0.62, 1.0],
              ),
            ),
            child: Row(
              children: [
                SecondaryButton('Limpiar', onTap: () {
                  setState(() {
                    _peso.clear();
                    _talla.clear();
                  });
                }),
                const SizedBox(width: 10),
                Expanded(
                  child: PrimaryButton('Calcular indicadores', onTap: () {
                    Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => const ResultsScreen(),
                    ));
                  }),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _dateField(String label, String value) {
    final p = AppPalette.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
      decoration: BoxDecoration(
        color: p.surfaceAlt,
        borderRadius: BorderRadius.circular(Radii.control),
        border: Border.all(color: p.isDark ? p.border : const Color(0xFFDDE4EA)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionLabel(label),
          const SizedBox(height: 5),
          Text(value,
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  fontFeatures: kTabular,
                  color: p.onSurface)),
        ],
      ),
    );
  }

  Widget _numberField({
    required String label,
    required TextEditingController controller,
    required String unit,
    required ClinicalStatus state,
  }) {
    final p = AppPalette.of(context);
    // In the design the plausible ("ok") field uses the primary-blue border on
    // a plain surface; only warn/bad tint the fill. The hint text below stays
    // green for ok.
    final borderColor = state == ClinicalStatus.ok ? p.primary : p.statusColor(state);
    final bg = state == ClinicalStatus.ok ? p.surface : p.statusBg(state);
    final textColor = state == ClinicalStatus.ok
        ? p.onSurface
        : state == ClinicalStatus.warn
            ? p.warnText
            : p.badText;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionLabel(label),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(Radii.control),
            border: Border.all(color: borderColor, width: 1.5),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    fontFeatures: kTabular,
                    color: textColor,
                  ),
                  cursorColor: p.primary,
                  decoration: const InputDecoration(
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                    border: InputBorder.none,
                    hintText: '—',
                  ),
                ),
              ),
              Text(unit,
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: p.muted)),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Text(Anthro.plausibilityHint(state),
            style: TextStyle(
                fontSize: 10.5,
                height: 1.3,
                fontWeight: FontWeight.w500,
                color: p.statusText(state))),
      ],
    );
  }
}
