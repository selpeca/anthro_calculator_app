import 'package:flutter_test/flutter_test.dart';

import 'package:anthro_calculator_app/anthro/indicators.dart';
import 'package:anthro_calculator_app/anthro/reference.dart';
import 'package:anthro_calculator_app/data.dart';
import 'package:anthro_calculator_app/export/measurement_pdf.dart';
import 'package:anthro_calculator_app/reference/reference_repository.dart';

AnthroInput _input({double? headCircumferenceCm}) => AnthroInput(
      birthDate: DateTime(2024, 5, 14),
      measurementDate: DateTime(2026, 8, 15),
      sex: Sex.female,
      weightKg: 12.4,
      statureCm: 86.5,
      position: MeasurePosition.standing,
      headCircumferenceCm: headCircumferenceCm,
      standardId: 'oms-2006',
    );

/// El primer byte de un PDF es siempre la firma `%PDF-`.
bool _isPdf(List<int> bytes) =>
    bytes.length > 5 &&
    bytes[0] == 0x25 && // %
    bytes[1] == 0x50 && // P
    bytes[2] == 0x44 && // D
    bytes[3] == 0x46 && // F
    bytes[4] == 0x2D; //  -

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await ReferenceRepository.ensureLoaded();
  });

  testWidgets('genera un PDF válido con las curvas del paciente',
      (tester) async {
    final ref = ReferenceRepository.reference('oms-2006')!;
    final input = _input(headCircumferenceCm: 44.1);
    final result = computeAnthro(input, ref);

    // El rasterizado de las gráficas usa `Picture.toImage`, que necesita el
    // pipeline real de imágenes: `runAsync` lo saca de la zona de tiempo falso.
    final bytes = await tester.runAsync(
      () => buildChartsPdf(input: input, result: result, patientName: 'Sofía'),
    );

    expect(bytes, isNotNull);
    expect(_isPdf(bytes!), isTrue);
    // Cuatro curvas (con PC) + fichas: el documento no es trivialmente pequeño.
    expect(bytes.length, greaterThan(10000));
  });

  testWidgets('genera el PDF aunque no se haya guardado el paciente ni el PC',
      (tester) async {
    final ref = ReferenceRepository.reference('oms-2006')!;
    final input = _input(); // sin PC, sin historial
    final result = computeAnthro(input, ref);

    final bytes = await tester.runAsync(
      () => buildChartsPdf(input: input, result: result),
    );

    expect(bytes, isNotNull);
    expect(_isPdf(bytes!), isTrue);
  });
}
