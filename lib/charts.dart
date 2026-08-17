import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'theme.dart';
import 'anthro/growth_curve.dart';

/// Un punto del paciente sobre la curva: `key` en el eje X (día de vida),
/// `value` en el eje Y, coloreado por `status`. `isCurrent` resalta la medición
/// activa con anillo, línea de caída y callout.
class GrowthPoint {
  const GrowthPoint({
    required this.key,
    required this.value,
    required this.status,
    this.isCurrent = false,
    this.callout,
    this.subCallout,
  });

  final double key;
  final double value;
  final ClinicalStatus status;
  final bool isCurrent;

  /// Texto principal del callout del punto actual (p. ej. `'27.0 m · 12.4 kg'`).
  final String? callout;

  /// Segunda línea del callout (p. ej. `'Z −0.42 · p34'`).
  final String? subCallout;
}

/// Eje X de la curva: edad (rotulada en meses, con la clave en días de vida) o
/// talla (rotulada y con la clave en cm). Determina la rejilla, los rótulos y el
/// título del eje horizontal.
enum ChartXAxis { ageMonths, statureCm }

/// Curva de crecimiento LMS: bandas ±3…±3 DS reales alrededor de la mediana y la
/// trayectoria del paciente (controles históricos conectados + punto actual
/// resaltado). Los datos vienen precalculados desde `growth_curve.dart`; este
/// widget solo pinta.
class LmsChart extends StatelessWidget {
  const LmsChart({
    super.key,
    required this.bands,
    required this.points,
    required this.xMinKey,
    required this.xMaxKey,
    required this.yMin,
    required this.yMax,
    this.xAxis = ChartXAxis.ageMonths,
  });

  final List<CurveBand> bands;
  final List<GrowthPoint> points;
  final double xMinKey;
  final double xMaxKey;
  final double yMin;
  final double yMax;
  final ChartXAxis xAxis;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return AspectRatio(
      aspectRatio: 344 / 236,
      child: CustomPaint(
        painter:
            _LmsPainter(p, bands, points, xMinKey, xMaxKey, yMin, yMax, xAxis),
      ),
    );
  }
}

/// Días por mes medio (365.25 / 12) para rotular el eje X en meses.
const double _daysPerMonth = 30.4375;

/// Color del trazo del paciente (línea de trayectoria y caída del punto actual).
const Color _patientLine = Color(0xFFC0392B);

class _LmsPainter extends CustomPainter {
  _LmsPainter(this.p, this.bands, this.points, this.xMinKey, this.xMaxKey,
      this.yMin, this.yMax, this.xAxis);

  final AppPalette p;
  final List<CurveBand> bands;
  final List<GrowthPoint> points;
  final double xMinKey, xMaxKey, yMin, yMax;
  final ChartXAxis xAxis;

  static const double vw = 344, vh = 236, pl = 30, pr = 8, pt = 8, pb = 22;

  @override
  void paint(Canvas canvas, Size size) {
    final sx = size.width / vw, sy = size.height / vh;
    final xSpan = (xMaxKey - xMinKey).abs() < 1e-9 ? 1.0 : xMaxKey - xMinKey;
    final ySpan = (yMax - yMin).abs() < 1e-9 ? 1.0 : yMax - yMin;
    double xs(double key) =>
        (pl + ((key - xMinKey) / xSpan) * (vw - pl - pr)) * sx;
    double ys(double v) =>
        (pt + (1 - (v - yMin) / ySpan) * (vh - pt - pb)) * sy;

    final gridColor = p.isDark ? const Color(0xFF24313F) : const Color(0xFFEEF2F5);
    final vGridColor = p.isDark ? const Color(0xFF1D2833) : const Color(0xFFF2F5F7);
    final axisText = p.faint;
    final gridPaint = Paint()..color = gridColor..strokeWidth = 1;
    final vGridPaint = Paint()..color = vGridColor..strokeWidth = 1;

    // Rejilla horizontal + rótulos Y en pasos redondos.
    final yStep = _niceStep(ySpan, 5);
    for (var v = (yMin / yStep).ceil() * yStep; v <= yMax + 1e-9; v += yStep) {
      final y = ys(v);
      canvas.drawLine(Offset(pl * sx, y), Offset((vw - pr) * sx, y), gridPaint);
      _text(canvas, _fmtTick(v), Offset((pl - 6) * sx, y), axisText, 9,
          align: TextAlign.right, mono: true, vCenter: true);
    }

    // Rejilla vertical + rótulos X (meses de edad o cm de talla según el eje).
    if (xAxis == ChartXAxis.statureCm) {
      final cmStep = _niceStep(xMaxKey - xMinKey, 6);
      for (var c = (xMinKey / cmStep).ceil() * cmStep;
          c <= xMaxKey + 1e-9;
          c += cmStep) {
        final x = xs(c);
        canvas.drawLine(
            Offset(x, pt * sy), Offset(x, (vh - pb) * sy), vGridPaint);
        _text(canvas, c.toStringAsFixed(0), Offset(x, (vh - pb + 4) * sy),
            axisText, 9, align: TextAlign.center, mono: true);
      }
    } else {
      final minMonth = xMinKey / _daysPerMonth;
      final maxMonth = xMaxKey / _daysPerMonth;
      final monthStep = _monthTickStep(maxMonth - minMonth);
      for (var m = (minMonth / monthStep).ceil() * monthStep;
          m <= maxMonth + 1e-9;
          m += monthStep) {
        final x = xs(m * _daysPerMonth);
        canvas.drawLine(
            Offset(x, pt * sy), Offset(x, (vh - pb) * sy), vGridPaint);
        _text(canvas, m.toStringAsFixed(0), Offset(x, (vh - pb + 4) * sy),
            axisText, 9, align: TextAlign.center, mono: true);
      }
    }

    // Bandas DS.
    for (final band in bands) {
      if (band.samples.isEmpty) continue;
      final (col, w) = _bandStyle(band.z);
      final path = Path();
      var first = true;
      for (final s in band.samples) {
        final o = Offset(xs(s.key), ys(s.value));
        if (first) {
          path.moveTo(o.dx, o.dy);
          first = false;
        } else {
          path.lineTo(o.dx, o.dy);
        }
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = col
          ..style = PaintingStyle.stroke
          ..strokeWidth = w
          ..strokeJoin = StrokeJoin.round
          ..strokeCap = StrokeCap.round,
      );
      final last = band.samples.last;
      final label = band.z == 0
          ? 'M'
          : '${band.z > 0 ? '+' : '−'}${band.z.abs().toStringAsFixed(0)}DS';
      _text(canvas, label, Offset((vw - pr - 2) * sx, ys(last.value) - 10),
          col, 8.5, align: TextAlign.right, weight: FontWeight.w600);
    }

    // Trayectoria del paciente: conector tenue entre controles.
    final ordered = [...points]..sort((a, b) => a.key.compareTo(b.key));
    if (ordered.length > 1) {
      final path = Path();
      for (var i = 0; i < ordered.length; i++) {
        final o = Offset(xs(ordered[i].key), ys(ordered[i].value));
        if (i == 0) {
          path.moveTo(o.dx, o.dy);
        } else {
          path.lineTo(o.dx, o.dy);
        }
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = _patientLine.withValues(alpha: 0.85)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.8
          ..strokeJoin = StrokeJoin.round
          ..strokeCap = StrokeCap.round,
      );
    }

    // Puntos históricos primero; el actual encima, resaltado.
    GrowthPoint? current;
    for (final gp in ordered) {
      if (gp.isCurrent) {
        current = gp;
        continue;
      }
      _dot(canvas, Offset(xs(gp.key), ys(gp.value)), p.statusColor(gp.status), 3.6);
    }
    if (current != null) {
      final px = xs(current.key), py = ys(current.value);
      canvas.drawLine(
        Offset(px, py),
        Offset(px, (vh - pb) * sy),
        Paint()
          ..color = _patientLine.withValues(alpha: 0.5)
          ..strokeWidth = 1,
      );
      _dot(canvas, Offset(px, py), p.statusColor(current.status), 5.5);
      _callout(canvas, px, py, current.callout, current.subCallout, size.width);
    } else if (ordered.length == 1) {
      final only = ordered.first;
      _dot(canvas, Offset(xs(only.key), ys(only.value)),
          p.statusColor(only.status), 5.5);
    }

    final xTitle =
        xAxis == ChartXAxis.statureCm ? 'Talla (cm)' : 'Edad (meses)';
    _text(canvas, xTitle, Offset(((vw + pl) / 2) * sx, (vh - 10) * sy),
        axisText, 9, align: TextAlign.center, weight: FontWeight.w500);
  }

  void _dot(Canvas canvas, Offset o, Color color, double r) {
    canvas.drawCircle(o, r, Paint()..color = color);
    canvas.drawCircle(
      o,
      r,
      Paint()
        ..color = p.surface
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  void _callout(
      Canvas canvas, double px, double py, String? title, String? sub, double maxX) {
    if (title == null && sub == null) return;
    const boxW = 104.0, boxH = 30.0;
    final toRight = px < maxX * 0.62;
    final left = toRight ? px + 9 : px - 9 - boxW;
    final rect = Rect.fromLTWH(left, py - 26, boxW, boxH);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(6)),
      Paint()..color = const Color(0xFF0F1B24).withValues(alpha: 0.92),
    );
    if (title != null) {
      _text(canvas, title, Offset(rect.left + 6, py - 22), Colors.white, 9.5,
          weight: FontWeight.w600);
    }
    if (sub != null) {
      _text(canvas, sub, Offset(rect.left + 6, py - 11), const Color(0xFF9FC6DE), 9,
          mono: true);
    }
  }

  /// Color y ancho del trazo según el nivel de DS de la banda.
  (Color, double) _bandStyle(double z) {
    final a = z.abs();
    if (a == 0) {
      return (p.isDark ? const Color(0xFF4FA3D9) : const Color(0xFF1E5F8C), 2.0);
    }
    if (a == 1) return (const Color(0xFFB9D5E8), 1.0);
    if (a == 2) return (const Color(0xFF7FB2D4), 1.2);
    return (const Color(0xFFE3A2A2), 1.2);
  }

  /// Paso "redondo" (1/2/5 · 10ⁿ) para ~[target] divisiones sobre [range].
  double _niceStep(double range, int target) {
    if (range <= 0) return 1;
    final raw = range / target;
    final mag = math.pow(10, (math.log(raw) / math.ln10).floor()).toDouble();
    final norm = raw / mag;
    final double step;
    if (norm < 1.5) {
      step = 1;
    } else if (norm < 3) {
      step = 2;
    } else if (norm < 7) {
      step = 5;
    } else {
      step = 10;
    }
    return step * mag;
  }

  /// Paso de rótulos del eje X (en meses) para no saturar la escala.
  double _monthTickStep(double spanMonths) {
    for (final s in const [3.0, 6.0, 12.0, 24.0, 60.0, 120.0]) {
      if (spanMonths / s <= 6) return s;
    }
    return 120;
  }

  String _fmtTick(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);

  void _text(Canvas canvas, String s, Offset at, Color color, double size,
      {TextAlign align = TextAlign.left,
      bool mono = false,
      bool vCenter = false,
      FontWeight weight = FontWeight.w400}) {
    final tp = TextPainter(
      text: TextSpan(
        text: s,
        style: TextStyle(
          color: color,
          fontSize: size,
          fontWeight: weight,
          fontFamily: mono ? 'monospace' : null,
        ),
      ),
      textDirection: ui.TextDirection.ltr,
    )..layout();
    double dx = at.dx;
    if (align == TextAlign.right) dx = at.dx - tp.width;
    if (align == TextAlign.center) dx = at.dx - tp.width / 2;
    double dy = at.dy;
    if (vCenter) dy = at.dy - tp.height / 2;
    tp.paint(canvas, Offset(dx, dy));
  }

  @override
  bool shouldRepaint(covariant _LmsPainter old) =>
      old.p != p ||
      old.bands != bands ||
      old.points != points ||
      old.xMinKey != xMinKey ||
      old.xMaxKey != xMaxKey ||
      old.yMin != yMin ||
      old.yMax != yMax ||
      old.xAxis != xAxis;
}

/// Rasteriza una curva LMS a PNG con el mismo pintor que usa la pantalla
/// (`_LmsPainter`), para incrustarla en el reporte PDF sin duplicar el dibujo.
///
/// Se pinta directamente sobre un `PictureRecorder` (sin árbol de widgets ni
/// `RepaintBoundary`), por lo que sirve para cualquier indicador aunque su
/// pestaña no esté visible. Pásale normalmente `AppPalette.light` para que el
/// reporte impreso sea legible sin importar el tema activo de la app.
/// [logicalWidth] es el ancho en px lógicos (relación 344:236 como en pantalla)
/// y [pixelRatio] la supermuestra para que el trazo salga nítido en el PDF.
Future<Uint8List> rasterizeLmsChart({
  required AppPalette palette,
  required List<CurveBand> bands,
  required List<GrowthPoint> points,
  required double xMinKey,
  required double xMaxKey,
  required double yMin,
  required double yMax,
  ChartXAxis xAxis = ChartXAxis.ageMonths,
  double logicalWidth = 344,
  double pixelRatio = 3.0,
}) async {
  final logicalHeight = logicalWidth * (236 / 344);
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.scale(pixelRatio);
  // Fondo opaco: el PNG iría transparente y en el PDF se vería el papel a través
  // de la rejilla.
  canvas.drawRect(Rect.fromLTWH(0, 0, logicalWidth, logicalHeight),
      Paint()..color = palette.surface);
  _LmsPainter(palette, bands, points, xMinKey, xMaxKey, yMin, yMax, xAxis)
      .paint(canvas, Size(logicalWidth, logicalHeight));
  final picture = recorder.endRecording();
  final image = await picture.toImage(
      (logicalWidth * pixelRatio).round(), (logicalHeight * pixelRatio).round());
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  picture.dispose();
  return data!.buffer.asUint8List();
}

/// Z-score progression line chart (design `zChart`). Two series: weight-for-age
/// and height-for-age. With [points] (puntos cronológicos `[label, pesoZ,
/// tallaZ]`) dibuja la trayectoria real; sin él usa los datos de muestra.
class ZScoreChart extends StatelessWidget {
  const ZScoreChart({super.key, this.dark, this.points});
  final bool? dark;

  /// Puntos en orden cronológico (el más antiguo primero). `z` nulo se omite
  /// de su serie; si todos son `null` el punto se descarta.
  final List<List<Object?>>? points;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return AspectRatio(
      aspectRatio: 344 / 150,
      child: CustomPaint(painter: _ZPainter(p, dark ?? p.isDark, points)),
    );
  }
}

class _ZPainter extends CustomPainter {
  _ZPainter(this.p, this.dark, this.points);
  final AppPalette p;
  final bool dark;
  final List<List<Object?>>? points;

  static const double vw = 344, vh = 150, pl = 26, pr = 10, pt = 12, pb = 22;

  // [label, weightZ, heightZ] de muestra del diseño.
  static const defaults = <List<Object>>[
    ['Feb', -0.75, -0.42],
    ['Abr', -0.58, -0.72],
    ['Jun', -0.5, -0.95],
    ['Ago', -0.42, -1.15],
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final pts = points ?? defaults;
    final sx = size.width / vw, sy = size.height / vh;
    double xs(int i) {
      final n = pts.length - 1;
      final t = n == 0 ? 0.5 : i / n;
      return (pl + t * (vw - pl - pr)) * sx;
    }

    double ys(double z) => (pt + (1 - (z + 3) / 6) * (vh - pt - pb)) * sy;

    final grid = dark ? const Color(0xFF24313F) : const Color(0xFFEEF2F5);
    final zeroLine = dark ? const Color(0xFF37485A) : const Color(0xFFDDE4EA);
    final txt = dark ? const Color(0xFF93A3B1) : const Color(0xFF8A97A3);

    for (final z in [2.0, 0.0, -2.0]) {
      final paint = Paint()
        ..color = z == 0 ? zeroLine : grid
        ..strokeWidth = 1;
      _dashLine(canvas, Offset(pl * sx, ys(z)), Offset((vw - pr) * sx, ys(z)),
          paint, dashed: z != 0);
      _text(canvas, z > 0 ? '+${z.toStringAsFixed(0)}' : z.toStringAsFixed(0),
          Offset((pl - 5) * sx, ys(z)), txt, 9, align: TextAlign.right, mono: true, vCenter: true);
    }

    void series(int idx, Color col) {
      final path = Path();
      var hasPrev = false;
      for (int i = 0; i < pts.length; i++) {
        final z = pts[i][idx] as double?;
        if (z == null) continue;
        final o = Offset(xs(i), ys(z));
        if (!hasPrev) {
          path.moveTo(o.dx, o.dy);
          hasPrev = true;
        } else {
          path.lineTo(o.dx, o.dy);
        }
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = col
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.2
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
      for (int i = 0; i < pts.length; i++) {
        final z = pts[i][idx] as double?;
        if (z == null) continue;
        final o = Offset(xs(i), ys(z));
        canvas.drawCircle(o, 3.6, Paint()..color = col);
        canvas.drawCircle(
            o, 3.6, Paint()
              ..color = dark ? p.surface : Colors.white
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.6);
      }
    }

    series(1, dark ? const Color(0xFF4FA3D9) : const Color(0xFF1E5F8C));
    series(2, const Color(0xFFC97A0B));

    for (int i = 0; i < pts.length; i++) {
      _text(canvas, pts[i][0] as String, Offset(xs(i), (vh - 5) * sy - 6), txt, 9,
          align: TextAlign.center, weight: FontWeight.w500);
    }
  }

  void _dashLine(Canvas canvas, Offset a, Offset b, Paint paint,
      {bool dashed = false}) {
    if (!dashed) {
      canvas.drawLine(a, b, paint);
      return;
    }
    const dash = 3.0, gap = 3.0;
    final total = (b - a).distance;
    final dir = (b - a) / total;
    double d = 0;
    while (d < total) {
      final start = a + dir * d;
      final end = a + dir * (d + dash).clamp(0, total).toDouble();
      canvas.drawLine(start, end, paint);
      d += dash + gap;
    }
  }

  void _text(Canvas canvas, String s, Offset at, Color color, double size,
      {TextAlign align = TextAlign.left,
      bool mono = false,
      bool vCenter = false,
      FontWeight weight = FontWeight.w400}) {
    final tp = TextPainter(
      text: TextSpan(
        text: s,
        style: TextStyle(
          color: color,
          fontSize: size,
          fontWeight: weight,
          fontFamily: mono ? 'monospace' : null,
        ),
      ),
      textDirection: ui.TextDirection.ltr,
    )..layout();
    double dx = at.dx;
    if (align == TextAlign.right) dx = at.dx - tp.width;
    if (align == TextAlign.center) dx = at.dx - tp.width / 2;
    double dy = vCenter ? at.dy - tp.height / 2 : at.dy;
    tp.paint(canvas, Offset(dx, dy));
  }

  @override
  bool shouldRepaint(covariant _ZPainter old) =>
      old.dark != dark || old.p != p || !_samePoints(old.points, points);

  static bool _samePoints(List<List<Object?>>? a, List<List<Object?>>? b) {
    if (identical(a, b)) return true;
    if (a == null || b == null || a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].length != b[i].length) return false;
      for (var j = 0; j < a[i].length; j++) {
        if (a[i][j] != b[i][j]) return false;
      }
    }
    return true;
  }
}
