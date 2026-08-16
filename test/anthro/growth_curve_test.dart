import 'dart:typed_data';

import 'package:anthro_calculator_app/anthro/growth_curve.dart';
import 'package:anthro_calculator_app/anthro/lms.dart';
import 'package:anthro_calculator_app/anthro/reference.dart';
import 'package:flutter_test/flutter_test.dart';

/// Tabla con LMS constante entre `lo` y `hi`: `lmsAt` devuelve siempre [lms].
ReferenceTable _flatTable(Lms lms, {double lo = 0, double hi = 100}) =>
    ReferenceTable(
      ReferenceAxis.ageDays,
      Float64List.fromList([lo, lms.l, lms.m, lms.s, hi, lms.l, lms.m, lms.s]),
    );

void main() {
  const lms = Lms(0.3, 10.0, 0.12);

  group('sampleBands', () {
    final table = _flatTable(lms);
    final bands = sampleBands(table, samples: 11);

    test('produce las 7 bandas de kBandZ', () {
      expect(bands.length, kBandZ.length);
      expect(bands.map((b) => b.z), containsAll(kBandZ));
    });

    test('la banda z=0 reproduce la mediana M en cada muestra', () {
      final median = bands.firstWhere((b) => b.z == 0);
      expect(median.samples, isNotEmpty);
      for (final s in median.samples) {
        expect(s.value, closeTo(lms.m, 1e-9));
      }
    });

    test('cada banda z reproduce valueFromLms(z) sobre la tabla plana', () {
      for (final b in bands) {
        for (final s in b.samples) {
          expect(s.value, closeTo(valueFromLms(b.z, lms), 1e-9));
        }
      }
    });

    test('las muestras cubren el rango de claves de la tabla', () {
      final median = bands.firstWhere((b) => b.z == 0);
      expect(median.samples.first.key, closeTo(0, 1e-9));
      expect(median.samples.last.key, closeTo(100, 1e-9));
    });
  });

  group('deficitRows', () {
    test('cubre +3/+2/mediana/−2/−3 y el delta es 0 en el corte del paciente', () {
      final atMinus2 = valueFromLms(-2, lms);
      final rows = deficitRows(lms, atMinus2);
      expect(rows.map((r) => r.z), kDeficitZ);
      final r = rows.firstWhere((r) => r.z == -2);
      expect(r.delta, closeTo(0, 1e-9));
      expect(r.value, closeTo(atMinus2, 1e-9));
    });

    test('delta = patientValue − value (positivo por encima de la mediana)', () {
      final median = valueFromLms(0, lms);
      final rows = deficitRows(lms, median + 1);
      final medRow = rows.firstWhere((r) => r.z == 0);
      expect(medRow.delta, closeTo(1, 1e-9));
    });
  });

  group('valueRange', () {
    test('cubre bandas y puntos con margen, con min < max', () {
      final bands = sampleBands(_flatTable(lms));
      final (lo, hi) =
          valueRange(bands, [valueFromLms(-3, lms), valueFromLms(3, lms)]);
      expect(lo, lessThan(valueFromLms(-3, lms)));
      expect(hi, greaterThan(valueFromLms(3, lms)));
    });

    test('sin datos finitos devuelve (0, 1)', () {
      final (lo, hi) = valueRange(const [], const []);
      expect(lo, 0);
      expect(hi, 1);
    });
  });
}
