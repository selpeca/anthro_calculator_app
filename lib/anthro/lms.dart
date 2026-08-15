/// Motor LMS: conversión valor ⇄ Z-score contra una curva OMS y utilidades
/// estadísticas. Sin dependencias de Flutter. Ver `test/anthro/lms_test.dart`.
library;

import 'dart:math' as math;

/// Un punto LMS de una curva de referencia (parámetros de Box-Cox de la OMS).
class Lms {
  const Lms(this.l, this.m, this.s);

  /// Lambda (potencia de la transformación).
  final double l;

  /// Mu (mediana).
  final double m;

  /// Sigma (coeficiente de variación).
  final double s;
}

const double _lZero = 1e-7;

/// Valor de la medida en el Z-score `z` para el punto LMS `p`.
///
/// `M·(1 + L·S·z)^(1/L)`, con el caso límite `L≈0` → `M·exp(S·z)`.
/// Devuelve `NaN` si `1 + L·S·z <= 0` (fuera del dominio de la curva).
double valueFromLms(double z, Lms p) {
  if (p.l.abs() < _lZero) return p.m * math.exp(p.s * z);
  final base = 1 + p.l * p.s * z;
  if (base <= 0) return double.nan;
  return p.m * math.pow(base, 1.0 / p.l);
}

/// Z-score crudo de la medida `x` para el punto LMS `p`.
///
/// `((x/M)^L − 1) / (L·S)`, con el caso límite `L≈0` → `ln(x/M)/S`.
/// Devuelve `NaN` si `x <= 0`.
double rawZFromLms(double x, Lms p) {
  if (x <= 0) return double.nan;
  if (p.l.abs() < _lZero) return math.log(x / p.m) / p.s;
  return (math.pow(x / p.m, p.l) - 1) / (p.l * p.s);
}

/// Z-score con el ajuste de la OMS para |Z| > 3.
///
/// Fuera de ±3 DS la distribución LMS se aleja de lo observado, así que la OMS
/// aplana la cola linealmente respecto de la distancia entre los cortes SD2 y
/// SD3. Debe usarse **solo en indicadores basados en peso** (P/E, P/T, IMC/E);
/// talla/edad y PC/edad usan `rawZFromLms` directamente.
double restrictedZ(double x, Lms p) {
  final z = rawZFromLms(x, p);
  if (z.isNaN) return z;
  if (z > 3) {
    final sd3 = valueFromLms(3, p);
    final sd2 = valueFromLms(2, p);
    return 3 + (x - sd3) / (sd3 - sd2);
  }
  if (z < -3) {
    final sd3 = valueFromLms(-3, p);
    final sd2 = valueFromLms(-2, p);
    return -3 + (x - sd3) / (sd2 - sd3);
  }
  return z;
}

/// Función de distribución acumulada normal estándar Φ(z).
///
/// Aproximación de Abramowitz & Stegun 7.1.26 para erf (error < 1.5e−7),
/// tres órdenes de magnitud por debajo de la resolución del 1 % que se muestra.
double normalCdf(double z) => 0.5 * (1 + _erf(z / math.sqrt2));

double _erf(double x) {
  final sign = x < 0 ? -1.0 : 1.0;
  final ax = x.abs();
  const a1 = 0.254829592;
  const a2 = -0.284496736;
  const a3 = 1.421413741;
  const a4 = -1.453152027;
  const a5 = 1.061405429;
  const pp = 0.3275911;
  final t = 1.0 / (1.0 + pp * ax);
  final y = 1.0 -
      (((((a5 * t + a4) * t) + a3) * t + a2) * t + a1) * t * math.exp(-ax * ax);
  return sign * y;
}

/// Porcentaje (0–100) correspondiente al Z-score `z`.
double percentFromZ(double z) => normalCdf(z) * 100;

/// Percentil (0–100) del Z-score `z`.
double percentileFromZ(double z) => percentFromZ(z).clamp(0, 100);

/// Etiqueta de percentil con 2 decimales y los extremos `<0.01` y `>99.99`.
String percentileLabel(double z) {
  final pct = percentFromZ(z);
  if (pct < 0.01) return '<0.01';
  if (pct > 99.99) return '>99.99';
  return pct.toStringAsFixed(2);
}
