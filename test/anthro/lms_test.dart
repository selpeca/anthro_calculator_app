import 'dart:math' as math;

import 'package:anthro_calculator_app/anthro/lms.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fixtures/who_spot_checks.dart';

void main() {
  group('valueFromLms / rawZFromLms', () {
    const p = Lms(0.3809, 3.2322, 0.14171); // wfa_girls día 0
    test('el valor en z=0 es la mediana M', () {
      expect(valueFromLms(0, p), closeTo(p.m, 1e-9));
      expect(rawZFromLms(p.m, p), closeTo(0, 1e-9));
    });

    test('ida y vuelta rawZ(valueFromLms(z)) ≈ z', () {
      for (final z in [-3.0, -2.0, -1.0, -0.5, 0.5, 1.0, 2.0, 3.0]) {
        final x = valueFromLms(z, p);
        expect(rawZFromLms(x, p), closeTo(z, 1e-9));
      }
    });

    test('rama L≈0 usa la forma logarítmica', () {
      const q = Lms(0, 10, 0.1);
      expect(valueFromLms(1, q), closeTo(10 * math.exp(0.1), 1e-9));
      expect(rawZFromLms(10 * math.exp(0.1), q), closeTo(1, 1e-9));
    });

    test('x<=0 y dominio inválido dan NaN', () {
      expect(rawZFromLms(0, p).isNaN, isTrue);
      // Con L=-0.5, S=0.2: 1 + L·S·z <= 0 cuando z >= 10.
      expect(valueFromLms(15, const Lms(-0.5, 10, 0.2)).isNaN, isTrue);
    });
  });

  group('restrictedZ (ajuste OMS |Z|>3)', () {
    const p = Lms(-0.2, 12.0, 0.09);
    test('en el corte SD3 vale exactamente 3', () {
      final sd3 = valueFromLms(3, p);
      expect(restrictedZ(sd3, p), closeTo(3, 1e-9));
    });

    test('más allá de SD3 sigue la fórmula lineal de la OMS', () {
      final sd3 = valueFromLms(3, p);
      final sd2 = valueFromLms(2, p);
      final x = sd3 * 1.1;
      final expected = 3 + (x - sd3) / (sd3 - sd2);
      final r = restrictedZ(x, p);
      expect(r, greaterThan(3));
      expect(r, closeTo(expected, 1e-9));
    });

    test('por debajo de −SD3 sigue la fórmula lineal de la OMS', () {
      final sd3 = valueFromLms(-3, p);
      final sd2 = valueFromLms(-2, p);
      final x = sd3 * 0.9;
      final expected = -3 + (x - sd3) / (sd2 - sd3);
      final r = restrictedZ(x, p);
      expect(r, lessThan(-3));
      expect(r, closeTo(expected, 1e-9));
    });

    test('dentro de ±3 coincide con el Z crudo', () {
      final x = valueFromLms(1.5, p);
      expect(restrictedZ(x, p), closeTo(rawZFromLms(x, p), 1e-9));
    });
  });

  group('normalCdf / percentiles', () {
    test('valores conocidos', () {
      expect(normalCdf(0), closeTo(0.5, 1e-6));
      expect(normalCdf(1.96), closeTo(0.975, 1e-4));
      expect(normalCdf(-1.96), closeTo(0.025, 1e-4));
    });

    test('percentileFromZ reproduce los pares del diseño', () {
      expect(percentileFromZ(-0.42), 34);
      expect(percentileFromZ(-1.15), 13);
      expect(percentileFromZ(0.31), 62);
      expect(percentileFromZ(0.28), 61);
      expect(percentileFromZ(-2.30), 1);
    });

    test('etiquetas de percentil en los extremos', () {
      expect(percentileLabel(-3.0), '<1');
      expect(percentileLabel(3.0), '>99');
      expect(percentileLabel(0), '50');
    });
  });

  group('spot-checks contra cortes SD publicados por la OMS', () {
    test('valueFromLms reproduce SD3neg/SD2neg/SD2/SD3 dentro de ±0.01', () {
      expect(kWhoSpotChecks, isNotEmpty);
      for (final c in kWhoSpotChecks) {
        final p = Lms(c.l, c.m, c.s);
        expect(valueFromLms(-3, p), closeTo(c.sd3neg, 0.01), reason: '${c.table} SD3neg');
        expect(valueFromLms(-2, p), closeTo(c.sd2neg, 0.01), reason: '${c.table} SD2neg');
        expect(valueFromLms(2, p), closeTo(c.sd2, 0.01), reason: '${c.table} SD2');
        expect(valueFromLms(3, p), closeTo(c.sd3, 0.01), reason: '${c.table} SD3');
      }
    });
  });
}
