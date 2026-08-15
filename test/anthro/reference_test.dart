import 'dart:typed_data';

import 'package:anthro_calculator_app/anthro/reference.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  ReferenceTable build(List<List<double>> rows, [ReferenceAxis axis = ReferenceAxis.ageDays]) {
    final flat = <double>[];
    for (final r in rows) {
      flat.addAll(r);
    }
    return ReferenceTable(axis, Float64List.fromList(flat));
  }

  group('ReferenceTable.lmsAt', () {
    final t = build([
      [0, 1.0, 10.0, 0.10],
      [10, 1.0, 20.0, 0.20],
    ]);

    test('fuera de rango devuelve null', () {
      expect(t.lmsAt(-1), isNull);
      expect(t.lmsAt(11), isNull);
    });

    test('acierto exacto devuelve la fila', () {
      final lms = t.lmsAt(0)!;
      expect(lms.m, 10.0);
      final lms2 = t.lmsAt(10)!;
      expect(lms2.m, 20.0);
    });

    test('punto medio interpola L, M y S linealmente', () {
      final lms = t.lmsAt(5)!;
      expect(lms.l, closeTo(1.0, 1e-12));
      expect(lms.m, closeTo(15.0, 1e-12));
      expect(lms.s, closeTo(0.15, 1e-12));
    });

    test('límites min/max', () {
      expect(t.minKey, 0);
      expect(t.maxKey, 10);
      expect(t.length, 2);
    });
  });
}
