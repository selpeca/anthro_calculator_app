import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme.dart';
import '../data.dart';
import '../widgets.dart';
import '../anthro/age.dart';
import '../anthro/indicators.dart';
import '../anthro/plausibility.dart';
import '../anthro/reference.dart';
import '../reference/reference_repository.dart';
import '../db/database.dart';
import 'common.dart';
import 'results.dart';
import '../settings.dart';

/// Reloj por defecto (constante, para poder usarlo en el constructor const).
DateTime _systemNow() => DateTime.now();

class CalculatorScreen extends StatefulWidget {
  const CalculatorScreen({super.key, this.clock = _systemNow});

  /// Reloj inyectable para pruebas; por defecto la hora real.
  final DateTime Function() clock;

  @override
  State<CalculatorScreen> createState() => _CalculatorScreenState();
}

class _CalculatorScreenState extends State<CalculatorScreen> {
  final _peso = TextEditingController(text: '12.4');
  final _talla = TextEditingController(text: '86.5');
  final _pc = TextEditingController();
  final _birth = TextEditingController();
  final _meas = TextEditingController();
  final RefStandard _ref = RefStandard.oms;
  bool _female = true;
  MeasurePosition _pos = MeasurePosition.standing;
  bool _save = false;

  late final DateTime _today;

  @override
  void initState() {
    super.initState();
    _today = dateOnly(widget.clock());
    _meas.text = formatDmy(_today);
    for (final c in [_peso, _talla, _pc, _birth, _meas]) {
      c.addListener(() => setState(() {}));
    }
  }

  @override
  void dispose() {
    for (final c in [_peso, _talla, _pc, _birth, _meas]) {
      c.dispose();
    }
    super.dispose();
  }

  double? get _pesoVal => double.tryParse(_peso.text.replaceAll(',', '.'));
  double? get _tallaVal => double.tryParse(_talla.text.replaceAll(',', '.'));
  double? get _pcVal =>
      _pc.text.trim().isEmpty ? null : double.tryParse(_pc.text.replaceAll(',', '.'));

  DateTime? get _birthDate => parseDmy(_birth.text);
  DateTime? get _measDate => parseDmy(_meas.text);

  Age? get _age {
    final b = _birthDate;
    final m = _measDate;
    if (b == null || m == null || m.isBefore(b)) return null;
    return ageBetween(b, m);
  }

  Sex get _sex => _female ? Sex.female : Sex.male;

  String get _standardId =>
      _ref == RefStandard.oms ? 'oms-2006' : 'col-2465';

  GrowthReference? get _reference => ReferenceRepository.reference(_standardId);

  String? get _birthError {
    final t = _birth.text.trim();
    if (t.length < 10) return null; // no regañar mientras se escribe
    final b = parseDmy(t);
    if (b == null) return 'Formato dd/mm/aaaa';
    if (b.isAfter(_today)) return 'La fecha no puede ser futura';
    final m = _measDate;
    if (m != null && b.isAfter(m)) return 'Nacimiento posterior a la medición';
    return null;
  }

  String? get _measError {
    final t = _meas.text.trim();
    if (t.length < 10) return null;
    final m = parseDmy(t);
    if (m == null) return 'Formato dd/mm/aaaa';
    if (m.isAfter(_today)) return 'La medición no puede ser futura';
    return null;
  }

  bool get _datesValid {
    final b = _birthDate;
    final m = _measDate;
    return b != null &&
        m != null &&
        !b.isAfter(_today) &&
        !m.isAfter(_today) &&
        !b.isAfter(m);
  }

  bool get _canCalculate =>
      _datesValid && (_pesoVal ?? 0) > 0 && (_tallaVal ?? 0) > 0;

  ReferenceTable? _tableFor(IndicatorKind kind) {
    final ref = _reference;
    final age = _age;
    if (ref == null || age == null) return null;
    return ref.tableFor(kind, _sex, ageDays: age.days);
  }

  DateTime _clamp(DateTime d, DateTime first, DateTime last) =>
      d.isBefore(first) ? first : (d.isAfter(last) ? last : d);

  Future<void> _pickBirth() async {
    final first = DateTime(_today.year - 20);
    final last = _measDate ?? _today;
    final picked = await showDatePicker(
      context: context,
      initialDate: _clamp(_birthDate ?? last, first, last),
      firstDate: first,
      lastDate: last,
    );
    if (picked != null) _birth.text = formatDmy(picked);
  }

  Future<void> _pickMeas() async {
    final first = _birthDate ?? DateTime(_today.year - 20);
    final last = _today;
    final picked = await showDatePicker(
      context: context,
      initialDate: _clamp(_measDate ?? last, first, last),
      firstDate: first,
      lastDate: last,
    );
    if (picked != null) _meas.text = formatDmy(picked);
  }

  Future<void> _calculate() async {
    final ref = _reference;
    if (ref == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('No hay tablas de referencia cargadas'),
      ));
      return;
    }
    final input = AnthroInput(
      birthDate: _birthDate!,
      measurementDate: _measDate!,
      sex: _sex,
      weightKg: _pesoVal!,
      statureCm: _tallaVal!,
      position: _pos,
      headCircumferenceCm: _pcVal,
      standardId: ref.standardId,
    );
    final result = computeAnthro(input, ref);

    int? savedMeasurementId;
    String? savedPatientName;
    if (_save) {
      // Persistir el resultado completo, asociado a un paciente por nombre.
      final target = await promptPatientName(context);
      if (target == null || !mounted) return;
      savedMeasurementId = await AnthroDatabase.instance.saveMeasurement(
        patientName: target.name,
        patientId: target.patientId,
        input: input,
        result: result,
      );
      savedPatientName = target.name;
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Medición guardada en el historial de ${target.name}'),
      ));
    }

    if (!mounted) return;
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ResultsScreen(
        input: input,
        result: result,
        savedMeasurementId: savedMeasurementId,
        savedPatientName: savedPatientName,
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final age = _age;
    final pesoState = weightPlausibility(_pesoVal,
        table: _tableFor(IndicatorKind.weightForAge), ageDays: age?.days);
    final tallaState = staturePlausibility(_tallaVal,
        table: _tableFor(IndicatorKind.statureForAge), ageDays: age?.days);
    final pcState = headPlausibility(_pcVal,
        table: _tableFor(IndicatorKind.headCircumferenceForAge),
        ageDays: age?.days);
    final imc = Anthro.imc(_pesoVal, _tallaVal);
    final (posNote, posWarn) = Anthro.positionNote(_pos, age?.decimalMonths);

    return Scaffold(
      backgroundColor: p.background,
      appBar: ScreenHeader(
        title: 'Cálculo antropométrico',
        subtitle: age == null
            ? (_female ? 'F' : 'M')
            : '${_female ? 'F' : 'M'} · ${age.label}',
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
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: _dateField(
                              label: 'F. nacimiento',
                              controller: _birth,
                              onPick: _pickBirth,
                              error: _birthError,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _dateField(
                              label: 'F. medición',
                              controller: _meas,
                              onPick: _pickMeas,
                              error: _measError,
                            ),
                          ),
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
                                  Text(age?.label ?? '—',
                                      style: TextStyle(
                                          fontSize: 17,
                                          fontWeight: FontWeight.w700,
                                          fontFeatures: kTabular,
                                          color: p.onPrimaryTint)),
                                  const SizedBox(height: 2),
                                  Text(age?.detail ?? 'Ingrese las fechas',
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
                            child: _numberField(
                              label: 'Perímetro cefálico',
                              controller: _pc,
                              unit: 'cm',
                              state: pcState,
                              hint: _pcVal == null ? 'Opcional · 0–5 años' : null,
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
                    _pc.clear();
                    _birth.clear();
                    _meas.text = formatDmy(dateOnly(widget.clock()));
                  });
                }),
                const SizedBox(width: 10),
                Expanded(
                  child: PrimaryButton('Calcular indicadores',
                      enabled: _canCalculate,
                      onTap: _canCalculate ? _calculate : null),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _dateField({
    required String label,
    required TextEditingController controller,
    required VoidCallback onPick,
    String? error,
  }) {
    final p = AppPalette.of(context);
    final borderColor = error != null
        ? p.bad
        : (p.isDark ? p.border : const Color(0xFFDDE4EA));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
          decoration: BoxDecoration(
            color: p.surfaceAlt,
            borderRadius: BorderRadius.circular(Radii.control),
            border: Border.all(color: borderColor, width: error != null ? 1.5 : 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SectionLabel(label),
              const SizedBox(height: 5),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: controller,
                      keyboardType: TextInputType.datetime,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        _DateMaskFormatter(),
                      ],
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        fontFeatures: kTabular,
                        color: error != null ? p.badText : p.onSurface,
                      ),
                      cursorColor: p.primary,
                      decoration: const InputDecoration(
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                        border: InputBorder.none,
                        hintText: 'dd/mm/aaaa',
                      ),
                    ),
                  ),
                  InkWell(
                    onTap: onPick,
                    borderRadius: BorderRadius.circular(6),
                    child: Padding(
                      padding: const EdgeInsets.all(2),
                      child: Icon(Icons.calendar_today_outlined,
                          size: 15, color: p.primary),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 5),
        Text(error ?? '',
            style: TextStyle(
                fontSize: 10.5,
                height: 1.2,
                fontWeight: FontWeight.w500,
                color: p.badText)),
      ],
    );
  }

  Widget _numberField({
    required String label,
    required TextEditingController controller,
    required String unit,
    required ClinicalStatus state,
    String? hint,
  }) {
    final p = AppPalette.of(context);
    // El estado "ok" usa el borde azul primario sobre superficie plana; warn/bad
    // tiñen el fondo; "none" (campo opcional vacío) es neutro.
    final Color borderColor;
    final Color bg;
    final Color textColor;
    switch (state) {
      case ClinicalStatus.ok:
        borderColor = p.primary;
        bg = p.surface;
        textColor = p.onSurface;
      case ClinicalStatus.none:
        borderColor = p.isDark ? p.border : const Color(0xFFCFD8DF);
        bg = p.surface;
        textColor = p.onSurface;
      case ClinicalStatus.warn:
        borderColor = p.statusColor(state);
        bg = p.statusBg(state);
        textColor = p.warnText;
      default:
        borderColor = p.statusColor(state);
        bg = p.statusBg(state);
        textColor = p.badText;
    }
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
        Text(hint ?? Anthro.plausibilityHint(state),
            style: TextStyle(
                fontSize: 10.5,
                height: 1.3,
                fontWeight: FontWeight.w500,
                color: state == ClinicalStatus.none ? p.faint : p.statusText(state))),
      ],
    );
  }
}

/// Inserta las barras de `dd/MM/yyyy` a medida que se escribe (entrada ya
/// filtrada a dígitos). El cursor queda al final: aceptable para un campo corto.
class _DateMaskFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    final capped = digits.length > 8 ? digits.substring(0, 8) : digits;
    final b = StringBuffer();
    for (var i = 0; i < capped.length; i++) {
      if (i == 2 || i == 4) b.write('/');
      b.write(capped[i]);
    }
    final text = b.toString();
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}
