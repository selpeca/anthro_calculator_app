/// Exporta las curvas de crecimiento del paciente a un PDF y lo entrega por la
/// hoja de compartir nativa (share_plus), igual que el CSV.
///
/// El reporte incluye la ficha de la medición, el resumen de indicadores y, por
/// cada curva disponible (Peso/Edad, Talla/Edad, IMC/Edad y PC/Edad si se
/// midió), la gráfica LMS con la trayectoria del paciente más su análisis
/// cuantitativo frente a cada corte de DS.
///
/// El armado del documento ([buildChartsPdf]) es independiente de plataforma
/// salvo el rasterizado de las gráficas (necesita el motor gráfico); la capa de
/// IO + UI ([sharePdf] y [exportChartsPdf]) se mantiene separada, igual que en
/// `measurement_export.dart`.
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import '../anthro/growth_curve.dart';
import '../anthro/indicators.dart';
import '../anthro/reference.dart';
import '../charts.dart';
import '../data.dart';
import '../db/models.dart';
import '../reference/reference_repository.dart';
import '../screens/growth_curve_view.dart';
import '../screens/patient_format.dart' show ageLabel, sexLabel;
import '../theme.dart';

/// Indicadores que se grafican, en el mismo orden que la pantalla de curvas.
/// PC/Edad solo se incluye si se midió el perímetro cefálico.
const List<({IndicatorKind kind, String label})> _curves = [
  (kind: IndicatorKind.weightForAge, label: 'Peso / Edad'),
  (kind: IndicatorKind.statureForAge, label: 'Talla / Edad'),
  (kind: IndicatorKind.bmiForAge, label: 'IMC / Edad'),
  (kind: IndicatorKind.headCircumferenceForAge, label: 'Perímetro cefálico / Edad'),
];

/// Formato de página del reporte (A4 con márgenes fijos). Se comparte con el
/// cálculo del ancho de las gráficas para que encajen sin desbordar.
final _pageFormat = PdfPageFormat.a4.copyWith(
  marginTop: 36,
  marginBottom: 40,
  marginLeft: 36,
  marginRight: 36,
);

/// Ancho de las gráficas dentro del área útil (menos el borde del marco).
final _chartWidth = _pageFormat.availableWidth - 1;

// Colores del reporte (paleta clara, para que el PDF se lea igual en cualquier
// tema y al imprimir en papel).
final _primary = PdfColor.fromInt(0xFF1E5F8C);
final _onSurface = PdfColor.fromInt(0xFF0F1B24);
final _muted = PdfColor.fromInt(0xFF5C6B77);
final _faint = PdfColor.fromInt(0xFF8A97A3);
final _border = PdfColor.fromInt(0xFFE2E8EE);
final _borderSoft = PdfColor.fromInt(0xFFEEF2F5);
final _tint = PdfColor.fromInt(0xFFE8F1F8);

// ---------------------------------------------------------------------------
// Fuentes
// ---------------------------------------------------------------------------

// Roboto (Apache-2.0) incrustado: las fuentes estándar del PDF (Helvetica) no
// soportan Unicode y descuadran los acentos del español. Se cargan una sola vez.
pw.Font? _regular;
pw.Font? _bold;

Future<pw.ThemeData> _theme() async {
  _regular ??= pw.Font.ttf(await rootBundle.load('assets/fonts/Roboto-Regular.ttf'));
  _bold ??= pw.Font.ttf(await rootBundle.load('assets/fonts/Roboto-Bold.ttf'));
  return pw.ThemeData.withFont(base: _regular!, bold: _bold!);
}

// ---------------------------------------------------------------------------
// Armado del PDF
// ---------------------------------------------------------------------------

/// Datos ya calculados de una curva para pintarla en el PDF.
class _CurveSection {
  const _CurveSection({
    required this.label,
    required this.png,
    required this.unit,
    required this.indicator,
    required this.rows,
  });

  final String label;
  final Uint8List png;
  final String unit;

  /// Indicador de la medición actual (Z / percentil / clasificación) o `null`.
  final Indicator? indicator;

  /// Filas del análisis cuantitativo (déficit/exceso frente a cada corte).
  final List<DeficitRow> rows;
}

/// Construye el PDF de las curvas del paciente y devuelve sus bytes.
Future<Uint8List> buildChartsPdf({
  required AnthroInput input,
  required AnthroResult result,
  List<SavedMeasurement> history = const [],
  int? currentMeasurementId,
  String? patientName,
}) async {
  final sections = await _buildSections(
    input: input,
    result: result,
    history: history,
    currentMeasurementId: currentMeasurementId,
  );

  final doc = pw.Document(
    title: 'Curvas de crecimiento',
    author: 'Anthro Calculator',
  );

  final theme = await _theme();
  final name = _cleanName(patientName);
  final sexWord = result.sex == Sex.female ? 'niñas' : 'niños';
  final generated = DateTime.now();

  doc.addPage(
    pw.MultiPage(
      pageFormat: _pageFormat,
      theme: theme,
      footer: (ctx) => _footer(ctx),
      build: (ctx) => [
        _titleBlock(name, result.standardLabel, sexWord, generated),
        pw.SizedBox(height: 14),
        _fichaBlock(input, result, name),
        pw.SizedBox(height: 14),
        _indicatorsBlock(result),
        pw.SizedBox(height: 6),
        for (final s in sections) ...[
          pw.SizedBox(height: 12),
          _curveBlock(s),
        ],
      ],
    ),
  );

  return doc.save();
}

/// Calcula y rasteriza cada curva disponible (usa la paleta clara para el PDF).
Future<List<_CurveSection>> _buildSections({
  required AnthroInput input,
  required AnthroResult result,
  required List<SavedMeasurement> history,
  required int? currentMeasurementId,
}) async {
  final ref = ReferenceRepository.reference(result.standardId);
  final sections = <_CurveSection>[];
  if (ref == null) return sections;

  for (final c in _curves) {
    if (c.kind == IndicatorKind.headCircumferenceForAge &&
        result.headCircumferenceCm == null) {
      continue;
    }
    final table = ref.tableFor(c.kind, result.sex, ageDays: result.age.days);
    if (table == null) continue;

    final bands = sampleBands(table);
    final points = buildGrowthPoints(
      kind: c.kind,
      input: input,
      result: result,
      table: table,
      history: history,
      currentMeasurementId: currentMeasurementId,
    );
    final (yMin, yMax) = valueRange(bands, points.map((e) => e.value));

    final png = await rasterizeLmsChart(
      palette: AppPalette.light,
      bands: bands,
      points: points,
      xMinKey: table.minKey,
      xMaxKey: table.maxKey,
      yMin: yMin,
      yMax: yMax,
      logicalWidth: 344,
      pixelRatio: 3.0,
    );

    final lms = table.lmsAt(result.age.days.toDouble());
    final cv = _currentValue(c.kind, input, result);
    final rows = (lms != null && cv != null && !cv.isNaN)
        ? deficitRows(lms, cv)
        : const <DeficitRow>[];

    sections.add(_CurveSection(
      label: c.label,
      png: png,
      unit: unitForIndicator(c.kind),
      indicator: _indicatorFor(result, c.kind),
      rows: rows,
    ));
  }
  return sections;
}

double? _currentValue(IndicatorKind kind, AnthroInput input, AnthroResult result) =>
    growthValue(kind,
        weightKg: result.weightKg,
        statureCm: input.statureCm,
        position: input.position,
        ageDays: result.age.days,
        bmi: result.bmi,
        headCircumferenceCm: result.headCircumferenceCm);

Indicator? _indicatorFor(AnthroResult result, IndicatorKind kind) {
  final name = nameForIndicator(kind);
  for (final i in result.indicators) {
    if (i.name == name) return i;
  }
  return null;
}

// ── Bloques del documento ──────────────────────────────────────────────────

pw.Widget _titleBlock(
    String name, String standardLabel, String sexWord, DateTime generated) {
  return pw.Row(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
    children: [
      pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('Curvas de crecimiento',
              style: pw.TextStyle(
                  fontSize: 18, fontWeight: pw.FontWeight.bold, color: _primary)),
          pw.SizedBox(height: 2),
          pw.Text(_wa('$name  ·  $standardLabel  ·  $sexWord'),
              style: pw.TextStyle(fontSize: 9.5, color: _muted)),
        ],
      ),
      pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.end,
        children: [
          _tag('REPORTE'),
          pw.SizedBox(height: 4),
          pw.Text('Generado ${_isoDateTime(generated)}',
              style: pw.TextStyle(fontSize: 8, color: _faint)),
        ],
      ),
    ],
  );
}

pw.Widget _fichaBlock(AnthroInput input, AnthroResult result, String name) {
  final age = ageLabel(result.age.years, result.age.months, result.age.remDays);
  final entries = <(String, String)>[
    ('Paciente', name),
    ('Sexo', sexLabel(result.sex)),
    ('Nacimiento', _isoDate(input.birthDate)),
    ('Medición', _isoDate(input.measurementDate)),
    ('Edad', '$age · ${result.age.days} d'),
    ('Posición', _positionLabel(input.position)),
    ('Peso', '${_num(result.weightKg)} kg'),
    ('Talla', '${_num(result.statureCm)} cm'),
    if (result.headCircumferenceCm != null)
      ('PC', '${_num(result.headCircumferenceCm!)} cm'),
    if (result.bmi != null) ('IMC', '${result.bmi!.toStringAsFixed(1)} kg/m²'),
    ('Estado', result.overallLabel),
  ];

  return _panel(
    pw.Wrap(
      spacing: 22,
      runSpacing: 10,
      children: [for (final e in entries) _kv(e.$1, e.$2)],
    ),
  );
}

pw.Widget _indicatorsBlock(AnthroResult result) {
  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      _sectionTitle('Indicadores'),
      pw.SizedBox(height: 6),
      pw.Table(
        border: pw.TableBorder(
          horizontalInside: pw.BorderSide(color: _borderSoft, width: .5),
        ),
        columnWidths: const {
          0: pw.FlexColumnWidth(3),
          1: pw.FlexColumnWidth(1.3),
          2: pw.FlexColumnWidth(1.3),
          3: pw.FlexColumnWidth(3.4),
        },
        children: [
          pw.TableRow(
            decoration: pw.BoxDecoration(color: _tint),
            children: [
              _cell('Indicador', header: true),
              _cell('Z', header: true, align: pw.TextAlign.right),
              _cell('Percentil', header: true, align: pw.TextAlign.right),
              _cell('Clasificación', header: true),
            ],
          ),
          for (final i in result.indicators)
            pw.TableRow(children: [
              _cell(i.name),
              _cell(_z(i.z), align: pw.TextAlign.right),
              _cell(_percentile(i.percentile),
                  align: pw.TextAlign.right),
              _cell(i.classification, color: _statusColor(i.status)),
            ]),
        ],
      ),
    ],
  );
}

pw.Widget _curveBlock(_CurveSection s) {
  final ind = s.indicator;
  final z = ind?.z;
  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      // El encabezado y la gráfica van dentro de un Container: MultiPage no
      // parte un Container, así que se mueven juntos a la página siguiente en
      // lugar de dejar el título huérfano al pie de una página.
      pw.Container(
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                _sectionTitle(s.label),
                if (ind != null)
                  pw.Text(
                    _wa('Z ${_z(z)}'
                        '${ind.percentile == null ? '' : ' · ${_percentile(ind.percentile)}'}'
                        ' · ${ind.classification}'),
                    style: pw.TextStyle(
                        fontSize: 8.5, color: _statusColor(ind.status)),
                  ),
              ],
            ),
            pw.SizedBox(height: 6),
            pw.Container(
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: _border, width: .5),
              ),
              child: pw.Image(
                pw.MemoryImage(s.png),
                width: _chartWidth,
                height: _chartWidth * (236 / 344),
              ),
            ),
          ],
        ),
      ),
      if (s.rows.isNotEmpty) ...[
        pw.SizedBox(height: 8),
        _deficitTable(s),
      ],
    ],
  );
}

pw.Widget _deficitTable(_CurveSection s) {
  return pw.Table(
    border: pw.TableBorder(
      horizontalInside: pw.BorderSide(color: _borderSoft, width: .5),
    ),
    columnWidths: const {
      0: pw.FlexColumnWidth(2),
      1: pw.FlexColumnWidth(2),
      2: pw.FlexColumnWidth(3),
    },
    children: [
      pw.TableRow(
        decoration: pw.BoxDecoration(color: _tint),
        children: [
          _cell('Corte', header: true),
          _cell('Valor', header: true, align: pw.TextAlign.right),
          _cell('Δ paciente', header: true, align: pw.TextAlign.right),
        ],
      ),
      for (final r in s.rows)
        pw.TableRow(
          decoration: r.z == 0 ? pw.BoxDecoration(color: _borderSoft) : null,
          children: [
            _cell(_zCut(r.z), bold: r.z == 0),
            _cell('${r.value.toStringAsFixed(1)} ${s.unit}',
                align: pw.TextAlign.right),
            _cell(_delta(r.delta, s.unit),
                align: pw.TextAlign.right, bold: r.z == 0),
          ],
        ),
    ],
  );
}

pw.Widget _footer(pw.Context ctx) {
  return pw.Container(
    margin: const pw.EdgeInsets.only(top: 8),
    padding: const pw.EdgeInsets.only(top: 6),
    decoration: pw.BoxDecoration(
      border: pw.Border(top: pw.BorderSide(color: _borderSoft, width: .5)),
    ),
    child: pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(
          _wa('Anthro Calculator · Apoyo clínico; no reemplaza el juicio '
              'profesional.'),
          style: pw.TextStyle(fontSize: 7.5, color: _faint),
        ),
        pw.Text('${ctx.pageNumber} / ${ctx.pagesCount}',
            style: pw.TextStyle(fontSize: 7.5, color: _faint)),
      ],
    ),
  );
}

// ── Componentes reutilizables ──────────────────────────────────────────────

pw.Widget _panel(pw.Widget child) => pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: PdfColor.fromInt(0xFFFBFCFD),
        border: pw.Border.all(color: _border, width: .5),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: child,
    );

pw.Widget _kv(String label, String value) => pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      mainAxisSize: pw.MainAxisSize.min,
      children: [
        pw.Text(_wa(label.toUpperCase()),
            style: pw.TextStyle(
                fontSize: 7, color: _faint, letterSpacing: 0.4)),
        pw.SizedBox(height: 2),
        pw.Text(_wa(value),
            style: pw.TextStyle(
                fontSize: 10.5, fontWeight: pw.FontWeight.bold, color: _onSurface)),
      ],
    );

pw.Widget _sectionTitle(String s) => pw.Text(_wa(s),
    style: pw.TextStyle(
        fontSize: 12, fontWeight: pw.FontWeight.bold, color: _onSurface));

pw.Widget _tag(String s) => pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: pw.BoxDecoration(
        color: _tint,
        borderRadius: pw.BorderRadius.circular(4),
      ),
      child: pw.Text(_wa(s),
          style: pw.TextStyle(
              fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: _primary)),
    );

pw.Widget _cell(
  String s, {
  bool header = false,
  bool bold = false,
  PdfColor? color,
  pw.TextAlign align = pw.TextAlign.left,
}) {
  return pw.Padding(
    padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
    child: pw.Text(
      _wa(s),
      textAlign: align,
      style: pw.TextStyle(
        fontSize: header ? 8 : 9,
        fontWeight:
            (header || bold) ? pw.FontWeight.bold : pw.FontWeight.normal,
        color: color ?? (header ? _muted : _onSurface),
        letterSpacing: header ? 0.3 : 0,
      ),
    ),
  );
}

// ── Formato de textos ──────────────────────────────────────────────────────

String _z(double? z) => z == null
    ? '—'
    : '${z >= 0 ? '+' : '-'}${z.abs().toStringAsFixed(2)}';

String _percentile(double? p) => p == null ? '—' : 'p${p.round()}';

String _delta(double delta, String unit) =>
    '${delta >= 0 ? '+' : '-'}${delta.abs().toStringAsFixed(2)} $unit';

String _zCut(double z) =>
    z == 0 ? 'Mediana' : '${z > 0 ? '+' : '-'}${z.abs().toStringAsFixed(0)} DS';

PdfColor _statusColor(ClinicalStatus s) => switch (s) {
      ClinicalStatus.ok => PdfColor.fromInt(0xFF1F8A5B),
      ClinicalStatus.warn => PdfColor.fromInt(0xFFC97A0B),
      ClinicalStatus.bad => PdfColor.fromInt(0xFFC0392B),
      ClinicalStatus.severe => PdfColor.fromInt(0xFF8E2A1F),
      ClinicalStatus.none => _muted,
    };

String _positionLabel(MeasurePosition p) =>
    p == MeasurePosition.lying ? 'Acostado' : 'De pie';

/// Entero sin decimales, en caso contrario un decimal (mismo criterio que la
/// presentación de la app).
String _num(double v) =>
    v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);

String _cleanName(String? name) {
  final trimmed = name?.trim() ?? '';
  return trimmed.isEmpty ? 'Paciente' : trimmed;
}

String _isoDate(DateTime d) => '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

String _isoDateTime(DateTime d) =>
    '${_isoDate(d)} ${_pad2(d.hour)}:${_pad2(d.minute)}';

/// Guardia ligero del texto que va al PDF. Roboto (incrustado) cubre el español,
/// los signos tipográficos (−, —, ≥), `·`, `±`, `²` y la Δ, así que se dejan
/// pasar tal cual; solo se retiran los caracteres de control y los "checkmarks"
/// del app (✓/✕) que no aportan nada en el reporte impreso.
String _wa(String s) {
  final buf = StringBuffer();
  for (final rune in s.runes) {
    if (rune < 0x20 && rune != 0x09) continue; // control (salvo tab)
    switch (rune) {
      case 0x2713: // ✓
      case 0x2714:
        break;
      case 0x2715: // ✕
      case 0x2717:
        buf.write('x');
      default:
        buf.writeCharCode(rune);
    }
  }
  return buf.toString();
}

// ---------------------------------------------------------------------------
// IO + compartir
// ---------------------------------------------------------------------------

/// Escribe el PDF en un archivo temporal y abre la hoja de compartir nativa.
Future<void> sharePdf(
  BuildContext context, {
  required Uint8List bytes,
  required String fileBaseName,
}) async {
  final origin = _shareOrigin(context);
  final name = '${_sanitize(fileBaseName)}_${_stamp(DateTime.now())}.pdf';
  final dir = await getTemporaryDirectory();
  final file = File('${dir.path}/$name');
  await file.writeAsBytes(bytes);
  await SharePlus.instance.share(ShareParams(
    files: [XFile(file.path, mimeType: 'application/pdf', name: name)],
    subject: name,
    sharePositionOrigin: origin,
  ));
}

/// Exporta las curvas mostradas en la pantalla a PDF y las comparte.
Future<void> exportChartsPdf(
  BuildContext context, {
  required AnthroInput input,
  required AnthroResult result,
  List<SavedMeasurement> history = const [],
  int? currentMeasurementId,
  String? patientName,
}) async {
  try {
    final bytes = await buildChartsPdf(
      input: input,
      result: result,
      history: history,
      currentMeasurementId: currentMeasurementId,
      patientName: patientName,
    );
    if (!context.mounted) return;
    final trimmed = patientName?.trim() ?? '';
    final base = trimmed.isEmpty ? 'curvas' : 'curvas_$trimmed';
    await sharePdf(context, bytes: bytes, fileBaseName: base);
  } catch (e) {
    if (context.mounted) _snack(context, 'No se pudo exportar el PDF: $e');
  }
}

/// Origen del popover de compartir (necesario en iPad); `null` si no aplica.
Rect? _shareOrigin(BuildContext context) {
  final box = context.findRenderObject() as RenderBox?;
  if (box == null || !box.hasSize) return null;
  return box.localToGlobal(Offset.zero) & box.size;
}

String _stamp(DateTime d) =>
    '${d.year}${_pad2(d.month)}${_pad2(d.day)}_${_pad2(d.hour)}${_pad2(d.minute)}';

String _pad2(int v) => v.toString().padLeft(2, '0');

String _sanitize(String s) {
  final cleaned = s
      .trim()
      .replaceAll(RegExp(r'[^A-Za-z0-9]+'), '_')
      .replaceAll(RegExp(r'^_+|_+$'), '');
  return cleaned.isEmpty ? 'export' : cleaned;
}

void _snack(BuildContext context, String msg) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
}
