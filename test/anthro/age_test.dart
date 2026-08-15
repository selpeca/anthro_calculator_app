import 'package:anthro_calculator_app/anthro/age.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ageBetween', () {
    test('caso del diseño: 14/05/2024 → 15/08/2026', () {
      final age = ageBetween(DateTime(2024, 5, 14), DateTime(2026, 8, 15));
      expect(age.days, 823);
      expect(age.label, '2 a 3 m 1 d');
      expect(age.decimalMonths.toStringAsFixed(1), '27.0');
      expect(age.totalMonths, 27);
    });

    test('mismo día → 0 días', () {
      final age = ageBetween(DateTime(2025, 1, 1), DateTime(2025, 1, 1));
      expect(age.days, 0);
      expect(age.label, '0 d');
    });

    test('víspera del primer cumpleaños', () {
      // De 15/03/2024 a 14/03/2025: el mes anterior a la medición es febrero
      // 2025 (28 d), así que el desglose es 11 m 27 d.
      final age = ageBetween(DateTime(2024, 3, 15), DateTime(2025, 3, 14));
      expect(age.years, 0);
      expect(age.label, '11 m 27 d');
      expect(age.days, 364);
    });

    test('cumpleaños exacto → 1 a', () {
      final age = ageBetween(DateTime(2024, 3, 15), DateTime(2025, 3, 15));
      expect(age.years, 1);
      expect(age.months, 0);
      expect(age.remDays, 0);
      expect(age.label, '1 a');
    });

    test('nacido 29/02 medido en año no bisiesto (28/02 vs 01/03)', () {
      final before = ageBetween(DateTime(2024, 2, 29), DateTime(2025, 2, 28));
      expect(before.years, 0);
      expect(before.label, '11 m 30 d');

      final on = ageBetween(DateTime(2024, 2, 29), DateTime(2025, 3, 1));
      expect(on.years, 1);
      expect(on.months, 0);
      expect(on.remDays, 0);
      expect(on.days, 366);
    });

    test('acarreo de fin de mes: 31/01 → 29/02', () {
      final age = ageBetween(DateTime(2024, 1, 31), DateTime(2024, 2, 29));
      expect(age.years, 0);
      expect(age.months, 0);
      expect(age.remDays, 29);
    });
  });

  group('daysBetween', () {
    test('cuenta días de calendario', () {
      expect(daysBetween(DateTime(2026, 3, 8), DateTime(2026, 3, 10)), 2);
    });
  });

  group('parseDmy', () {
    test('acepta fechas válidas', () {
      expect(parseDmy('14/05/2024'), DateTime(2024, 5, 14));
      expect(parseDmy('5/6/2024'), DateTime(2024, 6, 5));
    });

    test('rechaza fecha imposible 31/02/2025', () {
      expect(parseDmy('31/02/2025'), isNull);
    });

    test('rechaza otros formatos y vacío', () {
      expect(parseDmy('2024-05-14'), isNull);
      expect(parseDmy(''), isNull);
      expect(parseDmy('14/13/2024'), isNull);
      expect(parseDmy('00/05/2024'), isNull);
    });
  });

  group('formatDmy', () {
    test('rellena con ceros y hace ida y vuelta', () {
      expect(formatDmy(DateTime(2024, 5, 4)), '04/05/2024');
      final d = DateTime(2026, 8, 15);
      expect(parseDmy(formatDmy(d)), d);
    });
  });
}
