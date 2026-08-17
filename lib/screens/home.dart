import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../theme.dart';
import '../db/database.dart';
import '../db/models.dart';
import '../widgets.dart';
import 'common.dart';
import 'calculator.dart';
import 'patients.dart';
import 'patient_detail.dart';
import 'patient_format.dart';
import 'reference_status.dart';

import '../settings.dart';
import 'app_drawer.dart';
import 'about_dialog.dart';
import 'feedback_dialog.dart';

/// Home / dashboard (design 1b): branded header, quick action, module grid and
/// a preview of the patient database (leída de la base local).
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<SavedPatient>? _patients;

  /// Fechas de medición guardadas (para la gráfica de mediciones por período).
  List<DateTime> _measurementDates = const [];

  @override
  void initState() {
    super.initState();
    _load();
    // Refresca los agregados (lista y tendencia) ante cualquier cambio en la
    // base hecho desde otras pantallas: guardar/actualizar mediciones o la
    // limpieza/borrado de datos de la pantalla de base de datos.
    AnthroDatabase.instance.revision.addListener(_load);
  }

  @override
  void dispose() {
    AnthroDatabase.instance.revision.removeListener(_load);
    super.dispose();
  }

  Future<void> _load() async {
    final patients = await AnthroDatabase.instance.listPatients();
    final dates = await AnthroDatabase.instance.measurementDates();
    if (!mounted) return;
    setState(() {
      _patients = patients;
      _measurementDates = dates;
    });
  }

  /// Abre una pantalla y recarga el home al volver, para que refleje
  /// mediciones guardadas o editadas durante la navegación.
  Future<void> _open(BuildContext context, Widget screen) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
    if (mounted) await _load();
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final patients = _patients ?? const <SavedPatient>[];
    return Scaffold(
      backgroundColor: p.background,
      drawer: const AppDrawer(),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _open(context, const CalculatorScreen()),
        backgroundColor: p.primary,
        foregroundColor: p.isDark ? p.background : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
        tooltip: 'Nueva medición · paciente → medidas → resultados',
        child: const Icon(Icons.add_rounded, size: 26),
      ),
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          _Header(),
          _MedicionesTrendSection(measurementDates: _measurementDates),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: SectionCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Base de datos de pacientes',
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: p.onSurface)),
                        Text(
                            '${patients.length} registro${patients.length == 1 ? '' : 's'}',
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: p.primary)),
                      ],
                    ),
                  ),
                  const ThinDivider(),
                  if (patients.isEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 14, 14, 4),
                      child: Text('Aún no hay mediciones guardadas.',
                          style: TextStyle(fontSize: 12, height: 1.35, color: p.muted)),
                    )
                  else
                    for (final patient in patients.take(2)) ...[
                      _PatientRow(
                          patient: patient,
                          onTap: () => _open(
                              context, PatientDetailScreen(patient: patient))),
                      const ThinDivider(),
                    ],
                  InkWell(
                    onTap: () => _open(context, const PatientsScreen()),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Center(
                        child: Text(
                            patients.isEmpty
                                ? 'Ir a la base de pacientes'
                                : 'Ver todos los registros',
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: p.primary)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Footer(),
          // Espacio para que el FAB no tape el final del contenido.
          const SizedBox(height: 88),
        ],
      ),
    );
  }
}

/// Acciones disponibles en el menú de opciones del encabezado.
enum _HeaderMenuAction { about, report, suggest }

class _Header extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Container(
      color: p.primary,
      padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 14, 16, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Builder(
                        builder: (context) => IconButton(
                          onPressed: () => Scaffold.of(context).openDrawer(),
                          icon: const Icon(Icons.menu_rounded, color: Colors.white, size: 26),
                          tooltip: 'Abrir Menú Principal',
                        ),
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          'Anthro Calculator App',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            letterSpacing: -0.3,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<_HeaderMenuAction>(
                  icon: const Icon(Icons.more_vert_rounded, color: Colors.white, size: 26),
                  tooltip: 'Menú de opciones: acerca de la app, reportar un error o sugerir una función',
                  color: p.surface,
                  surfaceTintColor: Colors.transparent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(Radii.sheet),
                    side: BorderSide(color: p.border),
                  ),
                  onSelected: (action) {
                    switch (action) {
                      case _HeaderMenuAction.about:
                        showAboutAppDialog(context);
                        break;
                      case _HeaderMenuAction.report:
                        showFeedbackDialog(context, type: FeedbackType.bug);
                        break;
                      case _HeaderMenuAction.suggest:
                        showFeedbackDialog(context, type: FeedbackType.feature);
                        break;
                    }
                  },
                  itemBuilder: (context) => [
                    _headerMenuItem(context, _HeaderMenuAction.about,
                        Icons.info_outline_rounded, 'Acerca de la App'),
                    _headerMenuItem(context, _HeaderMenuAction.report,
                        Icons.bug_report_outlined, 'Reportar un error'),
                    _headerMenuItem(context, _HeaderMenuAction.suggest,
                        Icons.lightbulb_outline_rounded, 'Sugerir una función'),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                GestureDetector(
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => const ReferenceStatusScreen())),
                  child: HeaderPill(
                    text: 'Offline · datos locales',
                    dotColor: const Color(0xFF8CDEBA),
                    textColor: const Color(0xFFD5F2E5),
                    background: const Color(0xFF1F8A5B).withValues(alpha: 0.22),
                    borderColor: const Color(0xFF8CDEBA).withValues(alpha: 0.45),
                  ),
                ),
                const SizedBox(width: 8),
                ValueListenableBuilder<UnitSystem>(
                  valueListenable: unitSystemNotifier,
                  builder: (context, unit, _) {
                    return HeaderPill(
                      text: unit == UnitSystem.metric ? 'Métrico (kg, cm)' : 'Imperial (lb, in)',
                      textColor: Colors.white.withValues(alpha: 0.9),
                      background: Colors.white.withValues(alpha: 0.12),
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Elemento del menú desplegable del encabezado.
  PopupMenuItem<_HeaderMenuAction> _headerMenuItem(
      BuildContext context, _HeaderMenuAction action, IconData icon,
      String label) {
    final p = AppPalette.of(context);
    return PopupMenuItem<_HeaderMenuAction>(
      value: action,
      height: 48,
      child: Row(
        children: [
          Icon(icon, size: 19, color: p.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w500,
                color: p.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
class _PatientRow extends StatelessWidget {
  const _PatientRow({required this.patient, required this.onTap});
  final SavedPatient patient;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final latest = patient.latest;
    final meta = patientMeta(latest).split(' · ').take(3).join(' · ');
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        child: Row(
          children: [
            InitialsAvatar(initialsOf(patient.name), size: 32),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(patient.name,
                      style: TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w500, color: p.onSurface)),
                  const SizedBox(height: 2),
                  Text(meta,
                      style: TextStyle(fontSize: 11, color: p.muted)),
                ],
              ),
            ),
            StatusChip(patientTag(latest),
                latest?.overall ?? ClinicalStatus.none),
          ],
        ),
      ),
    );
  }
}

/// Unidad de agrupación temporal de la gráfica de mediciones.
enum _ChartPeriod { week, month }

/// Dato de una barra: inicio del período (semana o mes) y número de
/// mediciones registradas en él.
class _BarDatum {
  const _BarDatum({required this.start, required this.count});
  final DateTime start;
  final int count;
}

DateTime _weekStart(DateTime d) {
  final day = DateTime(d.year, d.month, d.day);
  return day.subtract(Duration(days: day.weekday - 1));
}

const List<String> _monthNames = [
  'ene', 'feb', 'mar', 'abr', 'may', 'jun',
  'jul', 'ago', 'sep', 'oct', 'nov', 'dic',
];

/// Eje Y para datos de conteo: escoge techo y paso **enteros** (1, 2, 5, 10…)
/// de modo que las líneas de la grilla nunca caigan en valores fraccionarios
/// (evita etiquetas tipo "3 / 5 / 8") y las barras aprovechen todo el alto.
({int max, int step}) _intAxis(int maxVal) {
  if (maxVal <= 0) return (max: 1, step: 1);
  const steps = [1, 2, 5, 10, 20, 25, 50, 100, 200, 250, 500, 1000];
  for (final s in steps) {
    final intervals = (maxVal / s).ceil();
    if (intervals <= 5) return (max: s * intervals, step: s);
  }
  final s = (maxVal / 5).ceil();
  return (max: s * 5, step: s);
}

/// Color de las barras de períodos anteriores (el actual va en primario sólido).
/// Un tinte claro del primario que funciona en claro y oscuro.
Color _barTint(AppPalette p) => p.isDark
    ? p.primary.withValues(alpha: 0.42)
    : Color.lerp(p.primary, p.surface, 0.62)!;

/// Agrupa las fechas de medición por semana o por mes, llenando los períodos
/// intermedios con ceros para que la serie sea continua.
List<_BarDatum> _buildBuckets(
    List<DateTime> measurementDates, _ChartPeriod period, DateTime now) {
  if (measurementDates.isEmpty) return const [];
  final starts = [
    for (final d in measurementDates)
      period == _ChartPeriod.week
          ? _weekStart(d)
          : DateTime(d.year, d.month),
  ];
  final counts = <DateTime, int>{};
  for (final s in starts) {
    counts[s] = (counts[s] ?? 0) + 1;
  }
  final keys = counts.keys.toList()..sort();
  final first = keys.first;
  final last = period == _ChartPeriod.week
      ? _weekStart(now)
      : DateTime(now.year, now.month);
  final out = <_BarDatum>[];
  var cursor = first;
  while (!cursor.isAfter(last)) {
    out.add(_BarDatum(start: cursor, count: counts[cursor] ?? 0));
    cursor = period == _ChartPeriod.week
        ? cursor.add(const Duration(days: 7))
        : DateTime(cursor.year, cursor.month + 1);
  }
  return out;
}

/// Tarjeta con la consolidación temporal de mediciones: total general, un
/// resumen (período actual · promedio · máximo) y una gráfica de barras
/// conmutable entre semana y mes. Muestra siempre los últimos 5 períodos.
class _MedicionesTrendSection extends StatefulWidget {
  const _MedicionesTrendSection({required this.measurementDates});

  final List<DateTime> measurementDates;

  @override
  State<_MedicionesTrendSection> createState() =>
      _MedicionesTrendSectionState();
}

class _MedicionesTrendSectionState extends State<_MedicionesTrendSection> {
  _ChartPeriod _period = _ChartPeriod.month;

  /// Últimos 5 períodos (semana o mes) hasta hoy, construidos a partir de las
  /// fechas ya cargadas en memoria (sin ir a la base de datos).
  List<_BarDatum> get _buckets {
    final all =
        _buildBuckets(widget.measurementDates, _period, DateTime.now());
    return all.length > 5 ? all.sublist(all.length - 5) : all;
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final total = widget.measurementDates.length;
    final buckets = _buckets;
    final isWeek = _period == _ChartPeriod.week;
    final current = buckets.isEmpty ? 0 : buckets.last.count;
    final peak = buckets.fold<int>(0, (m, d) => d.count > m ? d.count : m);
    final avg = buckets.isEmpty
        ? 0.0
        : buckets.fold<int>(0, (a, d) => a + d.count) / buckets.length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: SectionCard(
        padding: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 13, 14, 4),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Mediciones registradas',
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: p.onSurface)),
                        const SizedBox(height: 2),
                        Text(
                            total == 0
                                ? 'Cantidad por semana o mes'
                                : (isWeek
                                    ? 'Últimas 5 semanas'
                                    : 'Últimos 5 meses'),
                            style: TextStyle(fontSize: 11, color: p.muted)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('$total',
                          style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              fontFeatures: kTabular,
                              color: p.primary)),
                      Text('mediciones',
                          style: TextStyle(fontSize: 10, color: p.muted)),
                    ],
                  ),
                ],
              ),
            ),
            if (total == 0)
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 8, 14, 16),
                child: Row(
                  children: [
                    Icon(Icons.insights_rounded, size: 16, color: p.faint),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Aún no hay mediciones para graficar. Guarda la '
                        'primera medición y aquí verás la tendencia.',
                        style: TextStyle(fontSize: 12, height: 1.35, color: p.muted),
                      ),
                    ),
                  ],
                ),
              )
            else ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
                child: Row(
                  children: [
                    _StatTile(
                        label: isWeek ? 'Esta semana' : 'Este mes',
                        value: '$current'),
                    const SizedBox(width: 8),
                    _StatTile(
                        label: 'Promedio', value: avg.toStringAsFixed(1)),
                    const SizedBox(width: 8),
                    _StatTile(label: 'Máximo', value: '$peak'),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
                child: SegmentedControl(
                  options: const ['Semana', 'Mes'],
                  selectedIndex: isWeek ? 0 : 1,
                  onChanged: (i) => setState(() =>
                      _period = i == 0 ? _ChartPeriod.week : _ChartPeriod.month),
                ),
              ),
              const SizedBox(height: 16),
              _TrendBarChart(data: buckets, period: _period),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                child: Row(
                  children: [
                    _LegendDot(color: p.primary),
                    const SizedBox(width: 6),
                    Text(isWeek ? 'Semana actual' : 'Mes actual',
                        style: TextStyle(fontSize: 10.5, color: p.faint)),
                    const SizedBox(width: 14),
                    _LegendDot(color: _barTint(p)),
                    const SizedBox(width: 6),
                    Text('Períodos anteriores',
                        style: TextStyle(fontSize: 10.5, color: p.faint)),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Mini-tarjeta de estadística (etiqueta arriba + valor grande) usada en la
/// fila de resumen sobre la gráfica.
class _StatTile extends StatelessWidget {
  const _StatTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: p.isDark ? p.surfaceAlt : const Color(0xFFF7F9FB),
          borderRadius: BorderRadius.circular(Radii.chip),
          border: Border.all(color: p.borderSoft),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label.toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 9.5,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.3,
                color: p.muted,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                fontFeatures: kTabular,
                color: p.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Punto/cuadrito de color para la leyenda de la gráfica.
class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 9,
      height: 9,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
}

/// Gráfica de barras del número de mediciones por período (últimos 5). Eje Y
/// entero, barra del período actual resaltada en primario sólido y etiqueta de
/// valor sobre cada barra. Siempre caben 5 barras, así que no hay desplazamiento.
class _TrendBarChart extends StatelessWidget {
  const _TrendBarChart({required this.data, required this.period});

  final List<_BarDatum> data;
  final _ChartPeriod period;

  static const _chartHeight = 172.0;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    if (data.isEmpty) {
      return SizedBox(
        height: _chartHeight,
        child: Center(
          child: Text('Sin datos',
              style: TextStyle(fontSize: 11, color: p.faint)),
        ),
      );
    }
    final needsYear = data.first.start.year != data.last.start.year;
    final labels = [for (final d in data) _labelFor(d.start, needsYear)];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: SizedBox(
        height: _chartHeight,
        child: CustomPaint(
          painter: _TrendBarPainter(
            counts: [for (final d in data) d.count],
            labels: labels,
            currentIndex: data.length - 1,
            palette: p,
          ),
        ),
      ),
    );
  }

  String _labelFor(DateTime start, bool needsYear) {
    final base = period == _ChartPeriod.week
        ? '${start.day} ${_monthNames[start.month - 1]}'
        : _monthNames[start.month - 1];
    return needsYear ? '$base ${start.year % 100}' : base;
  }
}

class _TrendBarPainter extends CustomPainter {
  const _TrendBarPainter({
    required this.counts,
    required this.labels,
    required this.currentIndex,
    required this.palette,
  });

  final List<int> counts;
  final List<String> labels;
  final int currentIndex;
  final AppPalette palette;

  @override
  void paint(Canvas canvas, Size size) {
    const topPad = 26.0;
    const bottomPad = 24.0;
    const leftPad = 26.0;
    const rightPad = 6.0;
    final plotLeft = leftPad;
    final plotRight = size.width - rightPad;
    final plotTop = topPad;
    final plotBottom = size.height - bottomPad;
    final plotH = plotBottom - plotTop;
    final plotW = plotRight - plotLeft;

    final maxVal = counts.fold<int>(0, (m, c) => c > m ? c : m);
    final axis = _intAxis(maxVal);
    final niceMax = axis.max;

    final gridPaint = Paint()
      ..color = palette.borderSoft
      ..strokeWidth = 1;
    for (var v = 0; v <= niceMax; v += axis.step) {
      final y = plotBottom - plotH * v / niceMax;
      canvas.drawLine(Offset(plotLeft, y), Offset(plotRight, y), gridPaint);
      if (v != 0) {
        _text(canvas, '$v',
            anchor: Offset(plotLeft - 6, y),
            align: TextAlign.right,
            color: palette.faint,
            fontSize: 9);
      }
    }

    final n = counts.length;
    final slot = plotW / n;
    final barW = math.min(slot * 0.5, 34.0);
    final tint = _barTint(palette);
    for (var i = 0; i < n; i++) {
      final cx = plotLeft + slot * i + slot / 2;
      final count = counts[i];
      final isCurrent = i == currentIndex;
      final barH = count == 0 ? 3.0 : math.max(4.0, plotH * count / niceMax);
      final rect = RRect.fromRectAndCorners(
        Rect.fromLTWH(cx - barW / 2, plotBottom - barH, barW, barH),
        topLeft: const Radius.circular(5),
        topRight: const Radius.circular(5),
      );
      final paint = Paint();
      if (count == 0) {
        paint.color = palette.borderSoft;
      } else if (isCurrent) {
        paint.shader = LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [palette.primaryDark, palette.primary],
        ).createShader(rect.outerRect);
      } else {
        paint.color = tint;
      }
      canvas.drawRRect(rect, paint);

      if (count > 0) {
        _text(canvas, '$count',
            anchor: Offset(cx, plotBottom - barH - 9),
            align: TextAlign.center,
            color: isCurrent ? palette.primary : palette.muted,
            fontSize: 10,
            bold: true);
      }
    }

    for (var i = 0; i < n; i++) {
      final cx = plotLeft + slot * i + slot / 2;
      final isCurrent = i == currentIndex;
      _text(canvas, labels[i],
          anchor: Offset(cx, plotBottom + 11),
          align: TextAlign.center,
          color: isCurrent ? palette.primary : palette.muted,
          fontSize: 9.5,
          bold: isCurrent);
    }
  }

  void _text(Canvas canvas, String text,
      {required Offset anchor,
      required TextAlign align,
      required Color color,
      double fontSize = 9,
      bool bold = false}) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: fontSize,
          fontWeight: bold ? FontWeight.w600 : FontWeight.w400,
          fontFeatures: kTabular,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final dx = align == TextAlign.center
        ? anchor.dx - tp.width / 2
        : align == TextAlign.right
            ? anchor.dx - tp.width
            : anchor.dx;
    tp.paint(canvas, Offset(dx, anchor.dy - tp.height / 2));
  }

  @override
  bool shouldRepaint(covariant _TrendBarPainter old) =>
      old.counts != counts ||
      old.labels != labels ||
      old.currentIndex != currentIndex ||
      old.palette != palette;
}
