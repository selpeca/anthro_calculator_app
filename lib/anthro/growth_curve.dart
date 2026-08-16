/// Muestreo de curvas de crecimiento y análisis cuantitativo de déficit/exceso.
///
/// Módulo puro (sin Flutter): recibe tablas/LMS ya cargadas y produce las
/// polilíneas de las bandas ±3…±3 DS y las filas de déficit frente a cada
/// corte. La capa de dibujo (`lib/charts.dart`) y la pantalla
/// (`lib/screens/charts_screen.dart`) solo consumen estos datos.
///
/// Ver `test/anthro/growth_curve_test.dart`.
library;

import 'lms.dart';
import 'reference.dart';

/// Un punto muestreado de una curva: clave del eje (día de vida o cm de talla)
/// y valor de la medida (kg, cm, kg/m²…).
class CurveSample {
  const CurveSample(this.key, this.value);
  final double key;
  final double value;
}

/// Una banda de desviación estándar (p. ej. `z = -2`) como polilínea.
class CurveBand {
  const CurveBand(this.z, this.samples);
  final double z;
  final List<CurveSample> samples;
}

/// Niveles de DS que se dibujan, de arriba (+3) a abajo (−3).
const List<double> kBandZ = [3, 2, 1, 0, -1, -2, -3];

/// Muestrea las 7 bandas ±3…±3 DS de [table] en [samples] claves equiespaciadas
/// entre `minKey` y `maxKey`. Omite los puntos fuera del dominio de la curva
/// (donde `lmsAt` o `valueFromLms` no están definidos).
List<CurveBand> sampleBands(ReferenceTable table, {int samples = 61}) {
  final n = samples < 2 ? 2 : samples;
  final lo = table.minKey;
  final hi = table.maxKey;
  final step = (hi - lo) / (n - 1);
  final bands = <CurveBand>[];
  for (final z in kBandZ) {
    final pts = <CurveSample>[];
    for (var i = 0; i < n; i++) {
      final key = i == n - 1 ? hi : lo + step * i;
      final lms = table.lmsAt(key);
      if (lms == null) continue;
      final v = valueFromLms(z, lms);
      if (v.isNaN) continue;
      pts.add(CurveSample(key, v));
    }
    bands.add(CurveBand(z, pts));
  }
  return bands;
}

/// Una fila del análisis cuantitativo: valor de la medida en un corte de DS y
/// el delta firmado que hay que sumar a la medida del paciente para alcanzarlo.
class DeficitRow {
  const DeficitRow({required this.z, required this.value, required this.delta});

  final double z;

  /// Valor de la medida (kg, cm…) en `z` DS a la edad del paciente.
  final double value;

  /// `patientValue − value`: positivo = el paciente está por encima del corte;
  /// negativo = por debajo. Para el corte donde cae el paciente, es 0.
  final double delta;
}

/// Cortes de DS que muestra la tabla de análisis, de +3 a −3 (la mediana en
/// medio, sin ±1 para no recargar la tabla).
const List<double> kDeficitZ = [3, 2, 0, -2, -3];

/// Filas de déficit/exceso frente a +3/+2/mediana/−2/−3 DS para [lms] a la edad
/// del paciente, comparando con [patientValue].
List<DeficitRow> deficitRows(Lms lms, double patientValue) => [
      for (final z in kDeficitZ)
        DeficitRow(
          z: z,
          value: valueFromLms(z, lms),
          delta: patientValue - valueFromLms(z, lms),
        ),
    ];

/// Rango `(min, max)` del eje de valores que cubre las bandas y los puntos del
/// paciente ([extraValues]), con un margen relativo [pad]. Sirve para escalar
/// el eje Y de forma dinámica en lugar de cablearlo por indicador.
(double, double) valueRange(
  List<CurveBand> bands,
  Iterable<double> extraValues, {
  double pad = 0.08,
}) {
  var lo = double.infinity;
  var hi = double.negativeInfinity;
  for (final b in bands) {
    for (final s in b.samples) {
      if (s.value < lo) lo = s.value;
      if (s.value > hi) hi = s.value;
    }
  }
  for (final v in extraValues) {
    if (v.isNaN) continue;
    if (v < lo) lo = v;
    if (v > hi) hi = v;
  }
  if (!lo.isFinite || !hi.isFinite) return (0, 1);
  final span = (hi - lo).abs();
  final margin = span == 0 ? (hi.abs() * 0.1 + 1) : span * pad;
  return (lo - margin, hi + margin);
}
