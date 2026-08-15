import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'theme.dart';
import 'screens/splash.dart';

/// Global theme-mode switch, toggled from the home header.
final ValueNotifier<ThemeMode> themeModeNotifier = ValueNotifier(ThemeMode.light);

void main() {
  runApp(const AnthroApp());
}

class AnthroApp extends StatelessWidget {
  const AnthroApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeModeNotifier,
      builder: (context, mode, _) {
        // Keep the status bar icons legible against whichever theme is active.
        SystemChrome.setSystemUIOverlayStyle(
          mode == ThemeMode.dark
              ? SystemUiOverlayStyle.light
              : SystemUiOverlayStyle.dark,
        );
        return MaterialApp(
          title: 'Anthro Calculator App',
          debugShowCheckedModeBanner: false,
          themeMode: mode,
          theme: buildTheme(AppPalette.light),
          darkTheme: buildTheme(AppPalette.dark),
          home: const SplashScreen(),
        );
      },
    );
  }
}
