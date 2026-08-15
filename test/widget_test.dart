import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:anthro_calculator_app/anthro/age.dart';
import 'package:anthro_calculator_app/anthro/indicators.dart';
import 'package:anthro_calculator_app/anthro/reference.dart';
import 'package:anthro_calculator_app/data.dart';
import 'package:anthro_calculator_app/db/database.dart';
import 'package:anthro_calculator_app/main.dart';
import 'package:anthro_calculator_app/reference/reference_repository.dart';
import 'package:anthro_calculator_app/screens/calculator.dart';
import 'package:anthro_calculator_app/screens/patient_detail.dart';
import 'package:anthro_calculator_app/screens/patients.dart';
import 'package:anthro_calculator_app/theme.dart';
import 'package:anthro_calculator_app/widgets.dart';

/// Envuelve una pantalla con el mismo MaterialApp/locale de la app real,
/// necesario para que `showDatePicker` y los widgets Material funcionen.
Widget _wrap(Widget child) => MaterialApp(
      locale: const Locale('es'),
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      supportedLocales: const [Locale('es'), Locale('en')],
      theme: buildTheme(AppPalette.light),
      home: child,
    );

AnthroResult _sampleResult() => AnthroResult(
      age: const Age(days: 823, years: 2, months: 3, remDays: 1),
      sex: Sex.female,
      standardId: 'oms-2006',
      standardLabel: 'OMS 2006',
      weightKg: 12.4,
      statureCm: 86.5,
      headCircumferenceCm: 44.1,
      bmi: 16.6,
      indicators: const [
        Indicator(
          name: 'Peso / Edad',
          z: -0.42,
          percentile: 33.7,
          percentileLabel: '33',
          classification: 'Adecuado',
          status: ClinicalStatus.ok,
        ),
        Indicator(
          name: 'Talla / Edad',
          z: -1.15,
          percentile: 12.5,
          percentileLabel: '12',
          classification: 'Riesgo',
          status: ClinicalStatus.warn,
        ),
        Indicator(
          name: 'Perímetro cefálico / Edad',
          z: -2.3,
          percentile: 1.1,
          percentileLabel: '1',
          classification: 'Alteración',
          status: ClinicalStatus.bad,
          deficitNote: 'Déficit frente a −2 DS: 1.20 cm.',
        ),
      ],
      overall: ClinicalStatus.bad,
      overallLabel: 'Alteración',
    );

AnthroInput _sampleInput() => AnthroInput(
      birthDate: DateTime(2024, 5, 14),
      measurementDate: DateTime(2026, 8, 15),
      sex: Sex.female,
      weightKg: 12.4,
      statureCm: 86.5,
      position: MeasurePosition.standing,
      headCircumferenceCm: 44.1,
      standardId: 'oms-2006',
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // La E/S real de assets no se bombea dentro del cuerpo de un testWidgets
  // (tiempo simulado); se precarga aquí, fuera de él. Luego ensureLoaded()
  // devuelve al instante desde la caché.
  setUpAll(() async {
    await ReferenceRepository.ensureLoaded();

    // SQLite en memoria para el flujo de guardado. Se usa la variante sin
    // isolate para que las operaciones resuelvan dentro del reloj simulado
    // de testWidgets (FakeAsync).
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfiNoIsolate;
    AnthroDatabase.overridePath = inMemoryDatabasePath;
  });

  tearDown(() async {
    await AnthroDatabase.instance.close();
  });

  testWidgets('App boots on the splash screen', (tester) async {
    await tester.pumpWidget(const AnthroApp());
    expect(find.text('Antropometría pediátrica clínica\nOMS · Colombia'), findsOneWidget);
    expect(find.text('Listo para trabajar sin conexión'), findsOneWidget);

    // El splash tiene un indicador de progreso infinito: no se puede usar
    // pumpAndSettle. Se avanza el tiempo para disparar la navegación diferida y
    // completar la transición de fade.
    await tester.pump(const Duration(seconds: 3));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Anthro Calculator App'), findsOneWidget);
  });

  test('Anthro.imc calcula el IMC', () {
    expect(Anthro.imc(12.4, 86.5)!.toStringAsFixed(1), '16.6');
    expect(Anthro.imc(0, 86.5), isNull);
  });

  testWidgets('la calculadora deriva la edad y navega a resultados', (tester) async {
    expect(ReferenceRepository.isLoaded, isTrue);

    await tester.pumpWidget(_wrap(
      CalculatorScreen(clock: () => DateTime(2026, 8, 15)),
    ));
    await tester.pump();

    // La fecha de medición se precarga con "hoy".
    expect(find.text('15/08/2026'), findsOneWidget);

    // Escribir la fecha de nacimiento dispara el cálculo de edad en vivo.
    await tester.enterText(find.byType(TextField).first, '14/05/2024');
    await tester.pumpAndSettle();
    expect(find.text('823 días de vida · 27.0 meses'), findsOneWidget);
    expect(find.text('2 a 3 m 1 d'), findsOneWidget);

    // Peso (12.4) y talla (86.5) vienen precargados; calcular.
    await tester.tap(find.widgetWithText(PrimaryButton, 'Calcular indicadores'));
    await tester.pumpAndSettle();

    expect(find.text('Resultados'), findsOneWidget);
    // Cinco indicadores reales (PC incluido, campo por defecto vacío → 4;
    // aquí no digitamos PC, así que son 4 tarjetas Z-score).
    expect(find.text('Peso / Edad'), findsOneWidget);
    expect(find.text('Talla / Edad'), findsOneWidget);
  });

  testWidgets('con _save activo pide el nombre y guarda antes de navegar', (tester) async {
    await tester.pumpWidget(_wrap(
      CalculatorScreen(clock: () => DateTime(2026, 8, 15)),
    ));
    await tester.pump();

    // F. nacimiento; peso/talla vienen precargados.
    await tester.enterText(find.byType(TextField).first, '14/05/2024');
    await tester.pumpAndSettle();

    // Activar "Guardar esta medición" (está al final de la lista).
    await tester.scrollUntilVisible(
        find.text('Guardar esta medición en el historial del paciente'), 200,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('Guardar esta medición en el historial del paciente'));
    await tester.pump();

    await tester.tap(find.widgetWithText(PrimaryButton, 'Calcular indicadores'));
    await tester.pumpAndSettle();

    // El diálogo solicita el nombre del paciente.
    expect(find.text('¿Con qué paciente se guarda esta medición?'), findsOneWidget);

    final nameField = find.descendant(
        of: find.byType(Dialog), matching: find.byType(TextField));
    await tester.enterText(nameField, 'Sofía Restrepo');
    await tester.pump();
    await tester.tap(find.widgetWithText(PrimaryButton, 'Guardar'));
    await tester.pumpAndSettle();

    // Navegó a resultados y confirmó el guardado.
    expect(find.text('Resultados'), findsOneWidget);
    expect(find.text('Medición guardada en el historial de Sofía Restrepo'),
        findsOneWidget);

    // La medición quedó persistida.
    final patients = await AnthroDatabase.instance.listPatients();
    expect(patients, hasLength(1));
    expect(patients.first.name, 'Sofía Restrepo');
    expect(patients.first.measurementCount, 1);
    final history =
        await AnthroDatabase.instance.measurementsForPatient(patients.first.id);
    expect(history, hasLength(1));
    expect(history.first.indicators, isNotEmpty);
  });

  testWidgets('PatientsScreen lista pacientes guardados desde la BD', (tester) async {
    await AnthroDatabase.instance
        .saveMeasurement(patientName: 'Sofía Restrepo', input: _sampleInput(), result: _sampleResult());

    await tester.pumpWidget(_wrap(const PatientsScreen()));
    await tester.pumpAndSettle();

    expect(find.text('1 registro · base local'), findsOneWidget);
    expect(find.text('Sofía Restrepo'), findsOneWidget);
    expect(find.textContaining('12.4 kg · 86.5 cm'), findsOneWidget);
    expect(find.textContaining('−2.300'), findsOneWidget);
  });

  testWidgets('PatientDetailScreen muestra el historial desde la BD', (tester) async {
    await AnthroDatabase.instance
        .saveMeasurement(patientName: 'Sofía Restrepo', input: _sampleInput(), result: _sampleResult());
    final patients = await AnthroDatabase.instance.listPatients();
    expect(patients, hasLength(1));

    await tester.pumpWidget(_wrap(PatientDetailScreen(patient: patients.first)));
    await tester.pumpAndSettle();

    expect(find.text('Sofía Restrepo'), findsOneWidget);
    expect(find.text('1 mediciones'), findsOneWidget);
    expect(find.textContaining('12.4 kg · 86.5 cm · PC 44.1'), findsOneWidget);
    expect(find.text('−2.300'), findsNWidgets(2));
  });

  testWidgets('ThemeTogglePill toggles theme state on tap', (tester) async {
    bool isDark = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              return ThemeTogglePill(
                isDark: isDark,
                onChanged: (val) {
                  setState(() {
                    isDark = val;
                  });
                },
              );
            },
          ),
        ),
      ),
    );

    expect(find.byType(ThemeTogglePill), findsOneWidget);
    await tester.tap(find.byType(ThemeTogglePill));
    await tester.pumpAndSettle();
    expect(isDark, isTrue);
  });

  testWidgets('el botón Limpiar vacía los textfield excepto f. medición que pone la fecha actual', (tester) async {
    DateTime fixedClock() => DateTime(2026, 8, 15);
    await tester.pumpWidget(_wrap(
      CalculatorScreen(clock: fixedClock),
    ));
    await tester.pump();

    // Modificamos F. medición y F. nacimiento y agregamos PC
    final textFields = find.byType(TextField);
    await tester.enterText(textFields.at(0), '14/05/2024'); // F. nacimiento
    await tester.enterText(textFields.at(1), '01/01/2025'); // F. medición
    await tester.enterText(textFields.at(4), '45.0');       // PC
    await tester.pumpAndSettle();

    // Pulsamos "Limpiar"
    await tester.tap(find.widgetWithText(SecondaryButton, 'Limpiar'));
    await tester.pumpAndSettle();

    // Verificamos que F. nacimiento, Peso, Talla y PC queden vacíos,
    // mientras F. medición vuelve a la fecha actual por defecto ("15/08/2026").
    final birthField = tester.widget<TextField>(textFields.at(0));
    final measField = tester.widget<TextField>(textFields.at(1));
    final pesoField = tester.widget<TextField>(textFields.at(2));
    final tallaField = tester.widget<TextField>(textFields.at(3));
    final pcField = tester.widget<TextField>(textFields.at(4));

    expect(birthField.controller?.text, '');
    expect(measField.controller?.text, '15/08/2026');
    expect(pesoField.controller?.text, '');
    expect(tallaField.controller?.text, '');
    expect(pcField.controller?.text, '');
  });
}
