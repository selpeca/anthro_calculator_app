import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'theme.dart';
import 'data.dart';

/// LMS-style growth chart (weight-for-age) reproducing the design's `lmsChart`.
/// Draws ±3/±2/±1 DS bands around the median and plots the patient point.
class LmsChart extends StatelessWidget {
  const LmsChart({super.key});

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return AspectRatio(
      aspectRatio: 344 / 236,
      child: CustomPaint(painter: _LmsPainter(p)),
    );
  }
}

class _LmsPainter extends CustomPainter {
  _LmsPainter(this.p);
  final AppPalette p;

  static const double vw = 344, vh = 236;
  static const double pl = 30, pr = 8, pt = 8, pb = 22;

  @override
  void paint(Canvas canvas, Size size) {
    final sx = size.width / vw, sy = size.height / vh;
    double xs(double m) => (pl + (m / 60) * (vw - pl - pr)) * sx;
    const ymin = 2.0, ymax = 22.0;
    double ys(double v) => (pt + (1 - (v - ymin) / (ymax - ymin)) * (vh - pt - pb)) * sy;

    final gridColor = p.isDark ? const Color(0xFF24313F) : const Color(0xFFEEF2F5);
    final vGridColor = p.isDark ? const Color(0xFF1D2833) : const Color(0xFFF2F5F7);
    final axisText = p.faint;

    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    final vGridPaint = Paint()
      ..color = vGridColor
      ..strokeWidth = 1;

    // Horizontal grid + y labels.
    for (double v = 4; v <= 22; v += 4) {
      final y = ys(v);
      canvas.drawLine(Offset(pl * sx, y), Offset((vw - pr) * sx, y), gridPaint);
      _text(canvas, v.toStringAsFixed(0), Offset((pl - 6) * sx, y),
          axisText, 9, align: TextAlign.right, mono: true, vCenter: true);
    }
    // Vertical grid + x labels.
    for (double m = 0; m <= 60; m += 12) {
      canvas.drawLine(Offset(xs(m), pt * sy), Offset(xs(m), (vh - pb) * sy), vGridPaint);
      _text(canvas, m.toStringAsFixed(0), Offset(xs(m), (vh - pb + 4) * sy),
          axisText, 9, align: TextAlign.center, mono: true);
    }

    // DS bands.
    final bands = <List<Object>>[
      [3.0, const Color(0xFFE3A2A2), 1.2],
      [2.0, const Color(0xFF7FB2D4), 1.2],
      [1.0, const Color(0xFFB9D5E8), 1.0],
      [0.0, p.isDark ? const Color(0xFF4FA3D9) : const Color(0xFF1E5F8C), 2.0],
      [-1.0, const Color(0xFFB9D5E8), 1.0],
      [-2.0, const Color(0xFF7FB2D4), 1.2],
      [-3.0, const Color(0xFFE3A2A2), 1.2],
    ];
    for (final b in bands) {
      final k = b[0] as double;
      final col = b[1] as Color;
      final w = b[2] as double;
      final path = Path();
      bool first = true;
      for (double m = 0; m <= 60; m += 1.5) {
        final v = Anthro.medianWeight(m) * (1 + k * 0.115);
        final pt0 = Offset(xs(m), ys(v));
        if (first) {
          path.moveTo(pt0.dx, pt0.dy);
          first = false;
        } else {
          path.lineTo(pt0.dx, pt0.dy);
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
      final label = k == 0 ? 'M' : (k > 0 ? '+${k.toStringAsFixed(0)}' : k.toStringAsFixed(0)) + (k == 0 ? '' : 'DS');
      _text(canvas, k == 0 ? 'M' : label, Offset((vw - pr - 2) * sx, ys(Anthro.medianWeight(60) * (1 + k * 0.115)) - 10),
          col, 8.5, align: TextAlign.right, weight: FontWeight.w600);
    }

    // Patient point (27 m, 12.4 kg).
    final px = xs(27), py = ys(12.4);
    canvas.drawLine(
      Offset(px, py),
      Offset(px, (vh - pb) * sy),
      Paint()
        ..color = const Color(0xFFC0392B).withValues(alpha: 0.5)
        ..strokeWidth = 1,
    );
    canvas.drawCircle(Offset(px, py), 5.5, Paint()..color = const Color(0xFFC0392B));
    canvas.drawCircle(
        Offset(px, py), 5.5, Paint()
          ..color = p.surface
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2);

    // Callout label.
    final rect = Rect.fromLTWH(px + 9, py - 26, 104, 30);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(6)),
      Paint()..color = const Color(0xFF0F1B24).withValues(alpha: 0.92),
    );
    _text(canvas, '27.0 m · 12.4 kg', Offset(px + 15, py - 22), Colors.white, 9.5,
        weight: FontWeight.w600);
    _text(canvas, 'Z −0.42 · p34', Offset(px + 15, py - 11), const Color(0xFF9FC6DE), 9,
        mono: true);

    // Axis titles.
    _text(canvas, 'Edad (meses)', Offset(((vw + pl) / 2) * sx, (vh - 10) * sy),
        axisText, 9, align: TextAlign.center, weight: FontWeight.w500);
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
    double dy = at.dy;
    if (vCenter) dy = at.dy - tp.height / 2;
    tp.paint(canvas, Offset(dx, dy));
  }

  @override
  bool shouldRepaint(covariant _LmsPainter old) => old.p != p;
}

/// Z-score progression line chart (design `zChart`). Two series: weight-for-age
/// and height-for-age across four evaluations.
class ZScoreChart extends StatelessWidget {
  const ZScoreChart({super.key, this.dark});
  final bool? dark;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return AspectRatio(
      aspectRatio: 344 / 150,
      child: CustomPaint(painter: _ZPainter(p, dark ?? p.isDark)),
    );
  }
}

class _ZPainter extends CustomPainter {
  _ZPainter(this.p, this.dark);
  final AppPalette p;
  final bool dark;

  static const double vw = 344, vh = 150, pl = 26, pr = 10, pt = 12, pb = 22;

  // [label, weightZ, heightZ]
  static const pts = <List<Object>>[
    ['Feb', -0.75, -0.42],
    ['Abr', -0.58, -0.72],
    ['Jun', -0.5, -0.95],
    ['Ago', -0.42, -1.15],
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final sx = size.width / vw, sy = size.height / vh;
    double xs(int i) => (pl + (i / (pts.length - 1)) * (vw - pl - pr)) * sx;
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
      for (int i = 0; i < pts.length; i++) {
        final z = pts[i][idx] as double;
        final o = Offset(xs(i), ys(z));
        if (i == 0) {
          path.moveTo(o.dx, o.dy);
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
        final z = pts[i][idx] as double;
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
  bool shouldRepaint(covariant _ZPainter old) => old.dark != dark || old.p != p;
}
