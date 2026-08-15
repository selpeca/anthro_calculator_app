import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:anthro_calculator_app/data.dart';
import 'package:anthro_calculator_app/main.dart';
import 'package:anthro_calculator_app/reference/reference_repository.dart';
import 'package:anthro_calculator_app/screens/calculator.dart';
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // La E/S real de assets no se bombea dentro del cuerpo de un testWidgets
  // (tiempo simulado); se precarga aquí, fuera de él. Luego ensureLoaded()
  // devuelve al instante desde la caché.
  setUpAll(() async {
    await ReferenceRepository.ensureLoaded();
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
    final fixedClock = () => DateTime(2026, 8, 15);
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
