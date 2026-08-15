import 'package:flutter_test/flutter_test.dart';

import 'package:anthro_calculator_app/main.dart';
import 'package:anthro_calculator_app/theme.dart';
import 'package:anthro_calculator_app/data.dart';

void main() {
  testWidgets('App boots on the splash screen', (tester) async {
    await tester.pumpWidget(const AnthroApp());
    expect(find.text('Antropometría pediátrica clínica\nOMS · Colombia'), findsOneWidget);
    expect(find.text('Listo para trabajar sin conexión'), findsOneWidget);

    // Let the splash's delayed navigation fire and settle on the dashboard.
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    expect(find.text('Anthro Calculator App'), findsOneWidget);
  });

  test('Anthro helpers compute IMC and plausibility', () {
    // IMC = kg / m^2
    expect(Anthro.imc(12.4, 86.5)!.toStringAsFixed(1), '16.6');
    expect(Anthro.imc(0, 86.5), isNull);

    // Plausibility bands from the design's renderVals.
    expect(Anthro.weightState(12.4), ClinicalStatus.ok);
    expect(Anthro.weightState(9.0), ClinicalStatus.warn);
    expect(Anthro.weightState(35.0), ClinicalStatus.bad);
    expect(Anthro.heightState(86.5), ClinicalStatus.ok);
    expect(Anthro.heightState(98.0), ClinicalStatus.warn);
  });
}
