import 'package:flutter/material.dart';

/// System of units supported by the application.
enum UnitSystem {
  metric,
  imperial;

  String get displayName {
    switch (this) {
      case UnitSystem.metric:
        return 'Métrico (kg, cm)';
      case UnitSystem.imperial:
        return 'Imperial (lb, in)';
    }
  }

  String get weightUnit => this == UnitSystem.metric ? 'kg' : 'lb';
  String get heightUnit => this == UnitSystem.metric ? 'cm' : 'in';
  String get headCircUnit => this == UnitSystem.metric ? 'cm' : 'in';
  String get velocityWeightUnit => this == UnitSystem.metric ? 'kg/año' : 'lb/año';
  String get velocityHeightUnit => this == UnitSystem.metric ? 'cm/año' : 'in/año';
}

/// Clinical reference standards supported.
enum ReferenceStandard {
  who,
  colombia;

  String get displayName {
    switch (this) {
      case ReferenceStandard.who:
        return 'OMS 2006 (Internacional)';
      case ReferenceStandard.colombia:
        return 'Resolución 2465/2016 (Colombia)';
    }
  }

  String get shortCode {
    switch (this) {
      case ReferenceStandard.who:
        return 'OMS';
      case ReferenceStandard.colombia:
        return 'Colombia (2465)';
    }
  }
}

/// Global notifier for unit system preference across the app.
final ValueNotifier<UnitSystem> unitSystemNotifier =
    ValueNotifier(UnitSystem.metric);

/// Global notifier for anthropometric reference standard preference.
final ValueNotifier<ReferenceStandard> referenceStandardNotifier =
    ValueNotifier(ReferenceStandard.who);
