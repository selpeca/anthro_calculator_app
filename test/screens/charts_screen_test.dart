import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:anthro_calculator_app/anthro/indicators.dart';
import 'package:anthro_calculator_app/anthro/reference.dart';
import 'package:anthro_calculator_app/charts.dart';
import 'package:anthro_calculator_app/data.dart';
import 'package:anthro_calculator_app/db/database.dart';
import 'package:anthro_calculator_app/reference/reference_repository.dart';
import 'package:anthro_calculator_app/screens/charts_screen.dart';
import 'package:anthro_calculator_app/theme.dart';

Widget _wrap(Widget child) => MaterialApp(
      locale: const Locale('es'),
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      supportedLocales: const [Locale('es'), Locale('en')],
      theme: buildTheme(AppPalette.light),
      home: child,
    );

AnthroInput _input(DateTime measurement, {double? headCircumferenceCm}) =>
    AnthroInput(
      birthDate: DateTime(2024, 5, 14),
      measurementDate: measurement,
      sex: Sex.female,
      weightKg: 12.4,
      statureCm: 86.5,
      position: MeasurePosition.standing,
      headCircumferenceCm: headCircumferenceCm,
      standardId: 'oms-2006',
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await ReferenceRepository.ensureLoaded();
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfiNoIsolate;
    AnthroDatabase.overridePath = inMemoryDatabasePath;
  });

  tearDown(() async {
    await AnthroDatabase.instance.close();
  });

  testWidgets('dibuja las curvas reales con la trayectoria del paciente',
      (tester) async {
    final ref = ReferenceRepository.reference('oms-2006')!;

    // Dos controles del mismo paciente: uno antiguo y el actual.
    final oldInput = _input(DateTime(2026, 2, 15), headCircumferenceCm: 43.0);
    await AnthroDatabase.instance.saveMeasurement(
        patientName: 'Sofía', input: oldInput, result: computeAnthro(oldInput, ref));

    final input = _input(DateTime(2026, 8, 15), headCircumferenceCm: 44.1);
    final result = computeAnthro(input, ref);
    final currentId = await AnthroDatabase.instance
        .saveMeasurement(patientName: 'Sofía', input: input, result: result);

    final patients = await AnthroDatabase.instance.listPatients();

    // Superficie alta para que la lista perezosa construya la tarjeta de
    // análisis sin depender de scroll (ancho amplio para no comprimir el header).
    await tester.binding.setSurfaceSize(const Size(800, 2000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_wrap(ChartsScreen(
      input: input,
      result: result,
      patientId: patients.first.id,
      currentMeasurementId: currentId,
    )));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byType(LmsChart), findsOneWidget);
    expect(find.textContaining('niñas'), findsOneWidget);
    for (final label in ['Peso/Edad', 'Talla/Edad', 'IMC/Edad', 'PC/Edad']) {
      expect(find.text(label), findsOneWidget);
    }

    // El análisis cuantitativo real se computa desde el LMS: la fila de mediana
    // es la única con porcentaje, y no aparece el aviso de "sin análisis".
    expect(find.text('Análisis cuantitativo'), findsOneWidget);
    expect(find.textContaining('Sin análisis'), findsNothing);
    expect(find.textContaining('%'), findsWidgets);

    // Cambiar de indicador re-renderiza la curva y el análisis sin errores.
    await tester.tap(find.text('Talla/Edad'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byType(LmsChart), findsOneWidget);
    expect(find.textContaining('%'), findsWidgets);
  });

  testWidgets('oculta la pestaña PC/Edad cuando no se midió perímetro cefálico',
      (tester) async {
    final ref = ReferenceRepository.reference('oms-2006')!;
    final input = _input(DateTime(2026, 8, 15)); // sin PC
    final result = computeAnthro(input, ref);

    await tester.pumpWidget(_wrap(ChartsScreen(input: input, result: result)));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Peso/Edad'), findsOneWidget);
    expect(find.text('PC/Edad'), findsNothing);
    expect(find.byType(LmsChart), findsOneWidget);
  });
}
