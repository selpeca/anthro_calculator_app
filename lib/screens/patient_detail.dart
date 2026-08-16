import 'package:flutter/material.dart';
import '../theme.dart';
import '../anthro/age.dart';
import '../db/database.dart';
import '../db/models.dart';
import '../widgets.dart';
import '../charts.dart';
import 'common.dart';
import 'calculator.dart';
import 'patient_format.dart';

/// Patient file with measurement history (design 1j). El historial se lee de
/// la base SQLite local del paciente.
class PatientDetailScreen extends StatefulWidget {
  const PatientDetailScreen({super.key, required this.patient});
  final SavedPatient patient;

  @override
  State<PatientDetailScreen> createState() => _PatientDetailScreenState();
}

class _PatientDetailScreenState extends State<PatientDetailScreen> {
  List<SavedMeasurement>? _history;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final history =
        await AnthroDatabase.instance.measurementsForPatient(widget.patient.id);
    if (!mounted) return;
    setState(() => _history = history);
  }

  /// Abre la calculadora con este paciente ya asociado: precarga su última
  /// medición y guarda en su historial. Al volver se recarga el historial.
  Future<void> _openCalculator() async {
    await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => CalculatorScreen(patient: widget.patient)));
    if (mounted) await _load();
  }

  /// Abre la calculadora en modo edición con una medición del historial
  /// precargada. Al calcular se actualiza ese registro en lugar de duplicarlo.
  Future<void> _editMeasurement(SavedMeasurement m) async {
    await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) =>
            CalculatorScreen(patient: widget.patient, measurement: m)));
    if (mounted) await _load();
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final history = _history ?? const <SavedMeasurement>[];
    final latest = history.isNotEmpty ? history.first : widget.patient.latest;
    final zTiles = latest == null ? const <Widget>[] : _zTiles(latest);

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
                    ],
                  ),
                  const SizedBox(height: 4),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Row(
                      children: [
                        InitialsAvatar(initialsOf(widget.patient.name),
                            size: 48,
                            bg: p.isDark ? const Color(0xFF2A2036) : const Color(0xFFF0E6F3),
                            fg: p.isDark ? const Color(0xFFC79BD6) : const Color(0xFF7B4A8A)),
                        const SizedBox(width: 13),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(widget.patient.name,
                                  style: TextStyle(
                                      fontSize: 18, fontWeight: FontWeight.w700, color: p.onSurface)),
                              const SizedBox(height: 3),
                              Text(_headerSubtitle(latest),
                                  style: TextStyle(fontSize: 11.5, height: 1.4, color: p.muted)),
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
          if (latest == null)
            _emptyHistory(context)
          else ...[
            // Z summary tiles.
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              child: Row(
                children: [
                  for (int i = 0; i < zTiles.length; i++) ...[
                    if (i > 0) const SizedBox(width: 9),
                    Expanded(child: zTiles[i]),
                  ],
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
                          Text('${history.length} mediciones',
                              style: TextStyle(fontSize: 10.5, color: p.muted)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    ZScoreChart(dark: true, points: _zChartPoints(history)),
                  ],
                ),
              ),
            ),
          ],
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
                        InkWell(
                          onTap: _openCalculator,
                          borderRadius: BorderRadius.circular(6),
                          child: Padding(
                            padding: const EdgeInsets.all(4),
                            child: Text('+ Añadir',
                                style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                    color: p.primary)),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (history.isEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 4, 14, 16),
                      child: Text('Sin mediciones todavía',
                          style: TextStyle(fontSize: 12, color: p.muted)),
                    )
                  else ...[
                    const ThinDivider(),
                    for (final m in history) _historyRow(context, m),
                  ],
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(
              children: [
                Expanded(
                  child: PrimaryButton('Nueva medición', onTap: _openCalculator),
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

  String _headerSubtitle(SavedMeasurement? latest) {
    if (latest == null) return 'Sin mediciones guardadas';
    final parts = [
      sexLabel(latest.sex),
      formatDmy(latest.birthDate),
      ageLabel(latest.ageYears, latest.ageMonths, latest.ageRemDays),
    ];
    return parts.join(' · ');
  }

  /// Puntos de trayectoria Peso/Edad · Talla/Edad desde el historial real,
  /// en orden cronológico para que la línea corra de izquierda a derecha.
  List<List<Object?>> _zChartPoints(List<SavedMeasurement> history) {
    final points = <List<Object?>>[];
    for (final m in history.reversed) {
      final byName = {for (final i in m.indicators) i.name: i};
      final weightZ = byName['Peso / Edad']?.z;
      final heightZ = byName['Talla / Edad']?.z;
      if (weightZ == null && heightZ == null) continue;
      points.add([monthChartLabel(m.measurementDate), weightZ, heightZ]);
    }
    return points;
  }

  List<Widget> _zTiles(SavedMeasurement latest) {
    final tiles = <Widget>[];
    final byName = {for (final i in latest.indicators) i.name: i};
    final ordered = <SavedIndicator>[
      if (byName.containsKey('Peso / Edad')) byName['Peso / Edad']!,
      if (byName.containsKey('Talla / Edad')) byName['Talla / Edad']!,
      if (byName.containsKey('Perímetro cefálico / Edad'))
        byName['Perímetro cefálico / Edad']!,
    ];
    final selection = ordered.isNotEmpty
        ? ordered
        : latest.indicators.take(3).toList();
    for (final ind in selection) {
      tiles.add(_zTile(context, shortIndicatorName(ind.name), zLabelOf(ind.z),
          ind.status));
    }
    return tiles;
  }

  Widget _emptyHistory(BuildContext context) {
    final p = AppPalette.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
      child: Column(
        children: [
          Icon(Icons.monitor_heart_outlined, color: p.faint, size: 34),
          const SizedBox(height: 10),
          Text('Sin mediciones para este paciente',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: p.onSurface)),
          const SizedBox(height: 4),
          Text('Use "Nueva medición" para agregar la primera.',
              style: TextStyle(fontSize: 12, color: p.muted)),
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

  Widget _zTile(BuildContext context, String label, String z, ClinicalStatus status) {
    final p = AppPalette.of(context);
    final color = p.statusColor(status);
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

  Widget _historyRow(BuildContext context, SavedMeasurement m) {
    final p = AppPalette.of(context);
    final worst = worstIndicator(m);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _editMeasurement(m),
        child: Container(
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: p.borderSoft)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              SizedBox(
                width: 52,
                child: Text(historyDateLabel(m.measurementDate),
                    style: TextStyle(
                        fontSize: 10,
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
                    Text(measurementSummary(m),
                        style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w500,
                            fontFeatures: kTabular,
                            color: p.onSurface)),
                    const SizedBox(height: 2),
                    Text(measurementAgeLabel(m),
                        style:
                            TextStyle(fontSize: 10.5, height: 1.3, color: p.muted)),
                  ],
                ),
              ),
              StatusChip(zLabelOf(worst.z), worst.status),
              const SizedBox(width: 6),
              Icon(Icons.edit_outlined, size: 15, color: p.faint),
            ],
          ),
        ),
      ),
    );
  }
}
