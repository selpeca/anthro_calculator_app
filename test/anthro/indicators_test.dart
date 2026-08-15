import 'package:anthro_calculator_app/anthro/indicators.dart';
import 'package:anthro_calculator_app/anthro/reference.dart';
import 'package:anthro_calculator_app/data.dart';
import 'package:anthro_calculator_app/reference/store.dart';
import 'package:anthro_calculator_app/theme.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late GrowthReference oms;
  setUpAll(() async {
    final store = await ReferenceStore.load();
    oms = store.reference('oms-2006')!;
  });

  AnthroResult sofia({
    MeasurePosition position = MeasurePosition.standing,
    double? hc = 44.1,
    DateTime? birth,
    DateTime? meas,
    double weight = 12.4,
    double stature = 86.5,
  }) {
    return computeAnthro(
      AnthroInput(
        birthDate: birth ?? DateTime(2024, 5, 14),
        measurementDate: meas ?? DateTime(2026, 8, 15),
        sex: Sex.female,
        weightKg: weight,
        statureCm: stature,
        position: position,
        headCircumferenceCm: hc,
        standardId: 'oms-2006',
      ),
      oms,
    );
  }

  Indicator byName(AnthroResult r, String name) =>
      r.indicators.firstWhere((i) => i.name == name);

  group('caso del diseño (Sofía)', () {
    test('edad e IMC', () {
      final r = sofia();
      expect(r.age.days, 823);
      expect(r.age.label, '2 a 3 m 1 d');
      expect(r.bmi!.toStringAsFixed(1), '16.6');
    });

    test('cinco indicadores con Z reales de la OMS (±0.02)', () {
      final r = sofia();
      expect(r.indicators.length, 5);
      expect(byName(r, 'Peso / Edad').z!, closeTo(0.19, 0.02));
      expect(byName(r, 'Talla / Edad').z!, closeTo(-0.54, 0.02));
      expect(byName(r, 'Peso / Talla').z!, closeTo(0.58, 0.02));
      expect(byName(r, 'IMC / Edad').z!, closeTo(0.70, 0.02));
      expect(byName(r, 'Perímetro cefálico / Edad').z!, closeTo(-2.49, 0.02));
    });

    test('PC en −2.49 es rojo (bad), no severo — coherente con la leyenda', () {
      final r = sofia();
      expect(byName(r, 'Perímetro cefálico / Edad').status, ClinicalStatus.bad);
      expect(r.overall, ClinicalStatus.bad);
    });
  });

  group('ajuste de posición 0.7 cm', () {
    test('la talla mostrada nunca cambia, solo la curva', () {
      final standing = sofia(position: MeasurePosition.standing);
      final lying = sofia(position: MeasurePosition.lying);
      expect(standing.statureCm, 86.5);
      expect(lying.statureCm, 86.5);
      // ≥24 meses acostada: se restan 0.7 cm para la curva ⇒ Z de talla menor.
      expect(byName(lying, 'Talla / Edad').z!,
          lessThan(byName(standing, 'Talla / Edad').z!));
    });

    test('<24 meses de pie suma 0.7 cm en la curva', () {
      // Bebé de ~18 meses (548 d), 80 cm.
      AnthroResult baby(MeasurePosition pos) => computeAnthro(
            AnthroInput(
              birthDate: DateTime(2025, 1, 1),
              measurementDate: DateTime(2026, 7, 3), // 548 días
              sex: Sex.male,
              weightKg: 11.0,
              statureCm: 80.0,
              position: pos,
              standardId: 'oms-2006',
            ),
            oms,
          );
      final standing = baby(MeasurePosition.standing);
      final lying = baby(MeasurePosition.lying);
      expect(standing.age.days, 548);
      // De pie <24m: +0.7 ⇒ mayor talla ⇒ mayor Z que acostado (sin ajuste).
      expect(byName(standing, 'Talla / Edad').z!,
          greaterThan(byName(lying, 'Talla / Edad').z!));
    });
  });

  group('rangos de validez', () {
    test('PC nulo omite el indicador (4 tarjetas)', () {
      final r = sofia(hc: null);
      expect(r.indicators.length, 4);
      expect(r.indicators.any((i) => i.name.startsWith('Perímetro')), isFalse);
    });

    test('6 años: peso/talla y PC no interpretables', () {
      final r = sofia(
        birth: DateTime(2020, 1, 1),
        meas: DateTime(2026, 1, 1), // ~2192 días
      );
      expect(byName(r, 'Peso / Talla').status, ClinicalStatus.none);
      expect(byName(r, 'Perímetro cefálico / Edad').status, ClinicalStatus.none);
      expect(byName(r, 'Peso / Edad').status, ClinicalStatus.none);
    });

    test('30 meses a 62 cm: peso/talla fuera del rango de la curva', () {
      final r = computeAnthro(
        AnthroInput(
          birthDate: DateTime(2024, 1, 1),
          measurementDate: DateTime(2026, 7, 1), // ~912 días, ≥24m → talla 65–120
          sex: Sex.female,
          weightKg: 7.0,
          statureCm: 62.0,
          position: MeasurePosition.standing,
          standardId: 'oms-2006',
        ),
        oms,
      );
      expect(byName(r, 'Peso / Talla').status, ClinicalStatus.none);
    });
  });

  group('fronteras de color (statusFromZ)', () {
    test('|Z|==1 verde, justo por encima ámbar', () {
      expect(statusFromZ(1.0), ClinicalStatus.ok);
      expect(statusFromZ(1.0001), ClinicalStatus.warn);
      expect(statusFromZ(-1.0), ClinicalStatus.ok);
    });
    test('|Z|==2 ámbar, por encima rojo; |Z|==3 rojo, por encima severo', () {
      expect(statusFromZ(2.0), ClinicalStatus.warn);
      expect(statusFromZ(2.0001), ClinicalStatus.bad);
      expect(statusFromZ(3.0), ClinicalStatus.bad);
      expect(statusFromZ(3.0001), ClinicalStatus.severe);
    });
  });

  group('estándar Colombia', () {
    test('cambia la redacción pero no el Z', () async {
      final store = await ReferenceStore.load();
      final col = store.reference('col-2465')!;
      final rOms = sofia();
      final rCol = computeAnthro(
        AnthroInput(
          birthDate: DateTime(2024, 5, 14),
          measurementDate: DateTime(2026, 8, 15),
          sex: Sex.female,
          weightKg: 12.4,
          statureCm: 86.5,
          position: MeasurePosition.standing,
          headCircumferenceCm: 44.1,
          standardId: 'col-2465',
        ),
        col,
      );
      expect(byName(rCol, 'Talla / Edad').z,
          closeTo(byName(rOms, 'Talla / Edad').z!, 1e-9));
    });
  });
}
