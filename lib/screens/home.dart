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
                IconButton(
                  onPressed: () => showAboutAppDialog(context),
                  icon: const Icon(Icons.info_outline_rounded, color: Colors.white, size: 24),
                  tooltip: 'Acerca de Anthro Calculator',
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

/// Unidad de agrupación temporal de la gráfica de pacientes con medición.
enum _ChartPeriod { week, month }

/// Dato de una barra: inicio del período (semana o mes) y cantidad de
/// pacientes cuya primera medición cayó en él.
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

/// Techo "bonito" (1·10^n, 2·10^n, 5·10^n…) para escalar el eje Y.
double _niceCeil(double v) {
  if (v <= 1) return 1;
  final exp = math.pow(10, (math.log(v) / math.ln10).floor()).toDouble();
  final frac = v / exp;
  final nice = frac <= 1 ? 1 : (frac <= 2 ? 2 : (frac <= 5 ? 5 : 10));
  return nice * exp;
}

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

/// Tarjeta con la consolidación temporal de mediciones registradas:
/// total general + gráfica de barras conmutable entre semana y mes.
class _MedicionesTrendSection extends StatefulWidget {
  const _MedicionesTrendSection({required this.measurementDates});

  final List<DateTime> measurementDates;

  @override
  State<_MedicionesTrendSection> createState() =>
      _MedicionesTrendSectionState();
}

class _MedicionesTrendSectionState extends State<_MedicionesTrendSection> {
  /// Semanas cargadas por página en la vista semanal (lazy).
  static const _weekPageSize = 5;

  _ChartPeriod _period = _ChartPeriod.month;

  /// Semanas cargadas; índice 0 = semana actual (la más reciente).
  final List<_BarDatum> _weeks = [];
  final ScrollController _weekController = ScrollController();
  bool _loadingWeeks = true;
  bool _loadingOlder = false;
  bool _noMoreWeeks = false;
  DateTime? _earliestDate;

  @override
  void initState() {
    super.initState();
    _initWeeks();
  }

  @override
  void didUpdateWidget(covariant _MedicionesTrendSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.measurementDates != oldWidget.measurementDates) {
      _weeks.clear();
      _noMoreWeeks = false;
      _loadingOlder = false;
      _initWeeks();
    }
  }

  @override
  void dispose() {
    _weekController.dispose();
    super.dispose();
  }

  /// Carga las primeras 5 semanas (actual + 4 anteriores) desde la BD.
  Future<void> _initWeeks() async {
    final now = _weekStart(DateTime.now());
    final earliest = await AnthroDatabase.instance.earliestMeasurementDate();
    if (!mounted) return;
    final list = <_BarDatum>[];
    var cursor = now;
    var stop = earliest == null;
    for (var i = 0; i < _weekPageSize && !stop; i++) {
      final count = await AnthroDatabase.instance.countMeasurementsBetween(
          cursor, cursor.add(const Duration(days: 6)));
      list.add(_BarDatum(start: cursor, count: count));
      cursor = cursor.subtract(const Duration(days: 7));
      stop = earliest != null && cursor.isBefore(_weekStart(earliest));
    }
    if (!mounted) return;
    setState(() {
      _weeks.addAll(list);
      _earliestDate = earliest;
      _loadingWeeks = false;
      _noMoreWeeks = stop;
    });
    _maybeFillViewport();
  }

  /// Carga la siguiente página de semanas anteriores (hacia el pasado).
  Future<void> _loadOlder() async {
    if (_loadingOlder || _noMoreWeeks || _loadingWeeks) return;
    if (_earliestDate == null) {
      setState(() => _noMoreWeeks = true);
      return;
    }
    _loadingOlder = true;
    final last = _weeks.last.start;
    var cursor = last.subtract(const Duration(days: 7));
    final add = <_BarDatum>[];
    var stop = false;
    for (var i = 0; i < _weekPageSize; i++) {
      if (cursor.isBefore(_weekStart(_earliestDate!))) {
        stop = true;
        break;
      }
      final count = await AnthroDatabase.instance.countMeasurementsBetween(
          cursor, cursor.add(const Duration(days: 6)));
      add.add(_BarDatum(start: cursor, count: count));
      cursor = cursor.subtract(const Duration(days: 7));
    }
    if (!mounted) return;
    setState(() {
      _weeks.addAll(add);
      _loadingOlder = false;
      if (stop) _noMoreWeeks = true;
    });
    _maybeFillViewport();
  }

  /// Si el contenido aún no llena el ancho (y hay más historia), carga la
  /// siguiente página para que el scroll tenga espacio hacia el pasado.
  void _maybeFillViewport() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _loadingOlder || _noMoreWeeks) return;
      if (!_weekController.hasClients) return;
      if (_weekController.position.maxScrollExtent <= 0) _loadOlder();
    });
  }

  int get _weekMax =>
      _weeks.fold(0, (m, d) => d.count > m ? d.count : m);

  Widget _buildChart(AppPalette p) {
    if (_period == _ChartPeriod.week) {
      if (_loadingWeeks) {
        return const SizedBox(
          height: 170,
          child: Center(
            child: SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        );
      }
      return _WeeklyTrendChart(
        weeks: _weeks,
        maxCount: _weekMax,
        palette: p,
        loading: _loadingOlder,
        controller: _weekController,
        onLoadOlder: _loadOlder,
      );
    }
    return _TrendChart(
      data: _buildBuckets(widget.measurementDates, _ChartPeriod.month, DateTime.now()),
      period: _ChartPeriod.month,
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final total = widget.measurementDates.length;
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
                        Text('Cantidad por semana o mes',
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
                padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
                child: SegmentedControl(
                  options: const ['Semana', 'Mes'],
                  selectedIndex: _period == _ChartPeriod.week ? 0 : 1,
                  onChanged: (i) => setState(() =>
                      _period = i == 0 ? _ChartPeriod.week : _ChartPeriod.month),
                ),
              ),
              const SizedBox(height: 14),
              _buildChart(p),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
                child: Text(
                  _period == _ChartPeriod.week
                      ? 'Desliza hacia la izquierda para ver más semanas '
                          'anteriores (se cargan bajo demanda).'
                      : 'Mediciones registradas en cada mes.',
                  style: TextStyle(fontSize: 10.5, height: 1.4, color: p.faint),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Gráfica de barras del número de mediciones por período (vista mensual). Si
/// los períodos no caben en el ancho disponible, la zona se vuelve desplazable.
class _TrendChart extends StatelessWidget {
  const _TrendChart({required this.data, required this.period});

  final List<_BarDatum> data;
  final _ChartPeriod period;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    const chartHeight = 170.0;
    const minSlot = 30.0;
    if (data.isEmpty) {
      return SizedBox(
        height: chartHeight,
        child: Center(
          child: Text('Sin datos',
              style: TextStyle(fontSize: 11, color: p.faint)),
        ),
      );
    }
    final needsYear = data.first.start.year != data.last.start.year;
    final labels = [
      for (final d in data) _labelFor(d.start, needsYear),
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: LayoutBuilder(builder: (context, c) {
        final n = data.length;
        final slot = math.max(c.maxWidth / n, minSlot);
        final chart = SizedBox(
          width: slot * n,
          height: chartHeight,
          child: CustomPaint(
            painter: _BarChartPainter(
              counts: [for (final d in data) d.count],
              labels: labels,
              slotWidth: slot,
              palette: p,
            ),
          ),
        );
        if (slot * n <= c.maxWidth) return chart;
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: chart,
        );
      }),
    );
  }

  String _labelFor(DateTime start, bool needsYear) {
    final base = period == _ChartPeriod.week
        ? '${start.day} ${_monthNames[start.month - 1]}'
        : _monthNames[start.month - 1];
    return needsYear ? '$base ${start.year % 100}' : base;
  }
}

class _BarChartPainter extends CustomPainter {
  const _BarChartPainter({
    required this.counts,
    required this.labels,
    required this.slotWidth,
    required this.palette,
  });

  final List<int> counts;
  final List<String> labels;
  final double slotWidth;
  final AppPalette palette;

  @override
  void paint(Canvas canvas, Size size) {
    const topPad = 24.0;
    const bottomPad = 22.0;
    const leftPad = 28.0;
    const rightPad = 8.0;
    final plotLeft = leftPad;
    final plotRight = size.width - rightPad;
    final plotTop = topPad;
    final plotBottom = size.height - bottomPad;
    final plotH = plotBottom - plotTop;

    final maxVal = counts.reduce((a, b) => a > b ? a : b);
    final niceMax = _niceCeil(maxVal <= 0 ? 1 : maxVal.toDouble());

    const grid = 4;
    for (var i = 0; i <= grid; i++) {
      final val = niceMax * i / grid;
      final y = plotBottom - plotH * val / niceMax;
      canvas.drawLine(
        Offset(plotLeft, y),
        Offset(plotRight, y),
        Paint()
          ..color = palette.borderSoft
          ..strokeWidth = 1,
      );
      if (val != 0) {
        _drawText(canvas, '${val.round()}',
            anchor: Offset(plotLeft - 6, y),
            align: TextAlign.right,
            color: palette.faint,
            fontSize: 9);
      }
    }

    final barW = math.min(slotWidth * 0.48, 20.0);
    for (var i = 0; i < counts.length; i++) {
      final cx = plotLeft + slotWidth * i + slotWidth / 2;
      final count = counts[i];
      final barH =
          count == 0 ? 2.5 : math.max(3.0, plotH * count / niceMax);
      final rect = RRect.fromRectAndCorners(
        Rect.fromLTWH(cx - barW / 2, plotBottom - barH, barW, barH),
        topLeft: const Radius.circular(4),
        topRight: const Radius.circular(4),
      );
      canvas.drawRRect(
        rect,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [palette.primaryDark, palette.primary],
          ).createShader(rect.outerRect),
      );

      if (count > 0) {
        _drawText(canvas, '$count',
            anchor: Offset(cx, plotBottom - barH - 8),
            align: TextAlign.center,
            color: palette.primary,
            fontSize: 10,
            bold: true);
      }
    }

    final sampling = slotWidth < 30;
    final step = sampling ? math.max(1, (counts.length / 6).ceil()) : 1;
    for (var i = 0; i < counts.length; i++) {
      if (sampling && i % step != 0 && i != counts.length - 1) continue;
      final cx = plotLeft + slotWidth * i + slotWidth / 2;
      _drawText(canvas, labels[i],
          anchor: Offset(cx, plotBottom + 10),
          align: TextAlign.center,
          color: palette.muted,
          fontSize: 9);
    }
  }

  void _drawText(Canvas canvas, String text,
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
  bool shouldRepaint(covariant _BarChartPainter old) =>
      old.counts != counts ||
      old.labels != labels ||
      old.slotWidth != slotWidth ||
      old.palette != palette;
}

/// Vista semanal desplazable. El índice 0 (`weeks[0]`) es la semana actual,
/// así que con `reverse: true` el scroll inicia mostrando la fecha actual y
/// avanza hacia la izquierda (el pasado) cargando más semanas bajo demanda.
class _WeeklyTrendChart extends StatelessWidget {
  const _WeeklyTrendChart({
    required this.weeks,
    required this.maxCount,
    required this.palette,
    required this.loading,
    required this.controller,
    required this.onLoadOlder,
  });

  final List<_BarDatum> weeks;
  final int maxCount;
  final AppPalette palette;
  final bool loading;
  final ScrollController controller;
  final VoidCallback onLoadOlder;

  static const _pageSize = 5;
  static const _gutterLeft = 28.0;
  static const _chartHeight = 170.0;

  String _weekLabel(DateTime start) {
    final now = DateTime.now();
    final base = '${start.day} ${_monthNames[start.month - 1]}';
    return start.year == now.year ? base : '$base ${start.year % 100}';
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final viewport = math.max(0.0, c.maxWidth - _gutterLeft - 12);
      final slot = viewport / _pageSize;
      return SizedBox(
        height: _chartHeight,
        child: Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: _WeekGridPainter(
                    maxCount: maxCount, palette: palette),
              ),
            ),
            Positioned.fill(
              child: NotificationListener<ScrollNotification>(
                onNotification: (n) {
                  final m = n.metrics;
                  final atEnd = m.maxScrollExtent > 0 &&
                      m.pixels >= m.maxScrollExtent - 24;
                  if (atEnd) onLoadOlder();
                  return false;
                },
                child: Padding(
                  padding: const EdgeInsets.only(
                      left: _gutterLeft, right: 12),
                  child: ListView.builder(
                    controller: controller,
                    scrollDirection: Axis.horizontal,
                    reverse: true,
                    itemCount: weeks.length,
                    itemBuilder: (context, index) {
                      final d = weeks[index];
                      return _WeekBar(
                        count: d.count,
                        maxCount: maxCount,
                        slotWidth: slot,
                        label: _weekLabel(d.start),
                        isCurrent: index == 0,
                        palette: palette,
                      );
                    },
                  ),
                ),
              ),
            ),
            if (loading)
              const Positioned(
                left: 8,
                top: 0,
                bottom: 0,
                child: Center(
                  child: SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              ),
          ],
        ),
      );
    });
  }
}

/// Una semana (barra + valor + etiqueta) en la vista semanal.
class _WeekBar extends StatelessWidget {
  const _WeekBar({
    required this.count,
    required this.maxCount,
    required this.slotWidth,
    required this.label,
    required this.isCurrent,
    required this.palette,
  });

  final int count;
  final int maxCount;
  final double slotWidth;
  final String label;
  final bool isCurrent;
  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    final p = palette;
    final frac = maxCount <= 0 ? 0.0 : count / maxCount;
    return SizedBox(
      width: slotWidth,
      child: Column(
        children: [
          const SizedBox(height: 6),
          SizedBox(
            height: 16,
            child: Center(
              child: Text(
                count > 0 ? '$count' : '',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  fontFeatures: kTabular,
                  color: count > 0 ? p.primary : p.faint,
                ),
              ),
            ),
          ),
          Expanded(
            child: LayoutBuilder(builder: (context, c) {
              final h = c.maxHeight;
              return Align(
                alignment: Alignment.bottomCenter,
                child: Container(
                  width: math.min(slotWidth * 0.5, 44.0),
                  height:
                      count == 0 ? 2.5 : math.max(3.0, h * frac),
                  decoration: BoxDecoration(
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(5)),
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: isCurrent
                          ? [p.primaryDark, p.primary]
                          : [
                              p.primaryDark.withValues(alpha: 0.45),
                              p.primary.withValues(alpha: 0.65),
                            ],
                    ),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 6),
          SizedBox(
            height: 16,
            child: Center(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 9,
                  fontWeight:
                      isCurrent ? FontWeight.w600 : FontWeight.w400,
                  color: isCurrent ? p.primary : p.muted,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Grilla de fondo (líneas horizontales + etiquetas del eje Y) para la vista
/// semanal. Alineada con las áreas de valor/etiqueta de [_WeekBar].
class _WeekGridPainter extends CustomPainter {
  const _WeekGridPainter({required this.maxCount, required this.palette});

  final int maxCount;
  final AppPalette palette;

  @override
  void paint(Canvas canvas, Size size) {
    const topPad = 22.0;
    const bottomPad = 22.0;
    final plotLeft = 28.0;
    final plotBottom = size.height - bottomPad;
    final plotH = plotBottom - topPad;
    final niceMax = _niceCeil(maxCount <= 0 ? 1 : maxCount.toDouble());

    const grid = 4;
    for (var i = 0; i <= grid; i++) {
      final val = niceMax * i / grid;
      final y = plotBottom - plotH * val / niceMax;
      canvas.drawLine(
        Offset(plotLeft, y),
        Offset(size.width, y),
        Paint()
          ..color = palette.borderSoft
          ..strokeWidth = 1,
      );
      if (val != 0) {
        final tp = TextPainter(
          text: TextSpan(
            text: '${val.round()}',
            style: TextStyle(
              fontSize: 9,
              color: palette.faint,
              fontFeatures: kTabular,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, Offset(plotLeft - 6 - tp.width, y - tp.height / 2));
      }
    }
  }

  @override
  bool shouldRepaint(covariant _WeekGridPainter old) =>
      old.maxCount != maxCount || old.palette != palette;
}
