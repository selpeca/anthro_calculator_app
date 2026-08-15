import 'dart:ui' show FontFeature;
import 'package:flutter/material.dart';

/// Clinical status used across the app for "semaforización" (traffic-light
/// color coding of anthropometric results).
enum ClinicalStatus { ok, warn, bad, severe, none }

/// Resolved color palette. Two instances exist: [AppPalette.light] and
/// [AppPalette.dark]. Access the active one with `AppPalette.of(context)`.
///
/// Values mirror the design-system tokens from the Claude Design project
/// (turn 1a · "tokens traducibles a Flutter").
class AppPalette {
  const AppPalette({
    required this.brightness,
    required this.primary,
    required this.primaryDark,
    required this.primaryTint,
    required this.onPrimaryTint,
    required this.background,
    required this.surface,
    required this.surfaceAlt,
    required this.border,
    required this.borderSoft,
    required this.onSurface,
    required this.muted,
    required this.faint,
    required this.ok,
    required this.warn,
    required this.bad,
    required this.severe,
    required this.okBg,
    required this.warnBg,
    required this.badBg,
    required this.okText,
    required this.warnText,
    required this.badText,
    required this.segmentBg,
  });

  final Brightness brightness;
  final Color primary;
  final Color primaryDark;
  final Color primaryTint;
  final Color onPrimaryTint;
  final Color background;
  final Color surface;
  final Color surfaceAlt;
  final Color border;
  final Color borderSoft;
  final Color onSurface;
  final Color muted;
  final Color faint;
  final Color ok;
  final Color warn;
  final Color bad;
  final Color severe;
  final Color okBg;
  final Color warnBg;
  final Color badBg;
  final Color okText;
  final Color warnText;
  final Color badText;
  final Color segmentBg;

  bool get isDark => brightness == Brightness.dark;

  static const AppPalette light = AppPalette(
    brightness: Brightness.light,
    primary: Color(0xFF1E5F8C),
    primaryDark: Color(0xFF164A6E),
    primaryTint: Color(0xFFE8F1F8),
    onPrimaryTint: Color(0xFF164A6E),
    background: Color(0xFFF4F6F8),
    surface: Color(0xFFFFFFFF),
    surfaceAlt: Color(0xFFFBFCFD),
    border: Color(0xFFE2E8EE),
    borderSoft: Color(0xFFEEF2F5),
    onSurface: Color(0xFF0F1B24),
    muted: Color(0xFF5C6B77),
    faint: Color(0xFF8A97A3),
    ok: Color(0xFF1F8A5B),
    warn: Color(0xFFC97A0B),
    bad: Color(0xFFC0392B),
    severe: Color(0xFF8E2A1F),
    okBg: Color(0xFFE6F5EE),
    warnBg: Color(0xFFFDF1DE),
    badBg: Color(0xFFFBE9E7),
    okText: Color(0xFF1F8A5B),
    warnText: Color(0xFF8A5A0B),
    badText: Color(0xFF8E2A1F),
    segmentBg: Color(0xFFF0F3F6),
  );

  static const AppPalette dark = AppPalette(
    brightness: Brightness.dark,
    primary: Color(0xFF4FA3D9),
    primaryDark: Color(0xFF3F7EA8),
    primaryTint: Color(0xFF1E2B38),
    onPrimaryTint: Color(0xFFDCEBF5),
    background: Color(0xFF0E1620),
    surface: Color(0xFF16202B),
    surfaceAlt: Color(0xFF1B2732),
    border: Color(0xFF24313F),
    borderSoft: Color(0xFF1D2833),
    onSurface: Color(0xFFE8EEF4),
    muted: Color(0xFF93A3B1),
    faint: Color(0xFF5E6E7C),
    ok: Color(0xFF8CDEBA),
    warn: Color(0xFFF0B860),
    bad: Color(0xFFE8705F),
    severe: Color(0xFFE8705F),
    okBg: Color(0x2E1F8A5B),
    warnBg: Color(0x2EC97A0B),
    badBg: Color(0x2EC0392B),
    okText: Color(0xFF8CDEBA),
    warnText: Color(0xFFF0B860),
    badText: Color(0xFFE8705F),
    segmentBg: Color(0xFF1E2B38),
  );

  static AppPalette of(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark ? dark : light;
  }

  Color statusColor(ClinicalStatus s) {
    switch (s) {
      case ClinicalStatus.ok:
        return ok;
      case ClinicalStatus.warn:
        return warn;
      case ClinicalStatus.bad:
        return bad;
      case ClinicalStatus.severe:
        return severe;
      case ClinicalStatus.none:
        return faint;
    }
  }

  Color statusBg(ClinicalStatus s) {
    switch (s) {
      case ClinicalStatus.ok:
        return okBg;
      case ClinicalStatus.warn:
        return warnBg;
      case ClinicalStatus.bad:
      case ClinicalStatus.severe:
        return badBg;
      case ClinicalStatus.none:
        return segmentBg;
    }
  }

  Color statusText(ClinicalStatus s) {
    switch (s) {
      case ClinicalStatus.ok:
        return okText;
      case ClinicalStatus.warn:
        return warnText;
      case ClinicalStatus.bad:
      case ClinicalStatus.severe:
        return badText;
      case ClinicalStatus.none:
        return muted;
    }
  }
}

/// Tabular figures for aligned numeric readouts (the design uses
/// `font-variant-numeric: tabular-nums`).
const List<FontFeature> kTabular = [FontFeature.tabularFigures()];

/// Radii used by the design system: 8 chips · 10 inputs/buttons · 12 cards ·
/// 16/18 modal sheets.
class Radii {
  static const chip = 8.0;
  static const control = 10.0;
  static const card = 12.0;
  static const sheet = 18.0;
}

ThemeData buildTheme(AppPalette p) {
  final base = p.isDark ? ThemeData.dark() : ThemeData.light();
  final scheme = ColorScheme.fromSeed(
    seedColor: p.primary,
    brightness: p.brightness,
  ).copyWith(
    primary: p.primary,
    surface: p.surface,
    onSurface: p.onSurface,
  );

  return base.copyWith(
    colorScheme: scheme,
    scaffoldBackgroundColor: p.background,
    canvasColor: p.background,
    dividerColor: p.border,
    splashFactory: InkRipple.splashFactory,
    textTheme: base.textTheme.apply(
      bodyColor: p.onSurface,
      displayColor: p.onSurface,
      fontFamily: 'Inter',
    ),
    extensions: [_PaletteExt(p)],
  );
}

/// Lets widgets pull the palette straight from ThemeData if they prefer.
class _PaletteExt extends ThemeExtension<_PaletteExt> {
  const _PaletteExt(this.palette);
  final AppPalette palette;

  @override
  ThemeExtension<_PaletteExt> copyWith() => this;

  @override
  ThemeExtension<_PaletteExt> lerp(ThemeExtension<_PaletteExt>? other, double t) => this;
}
