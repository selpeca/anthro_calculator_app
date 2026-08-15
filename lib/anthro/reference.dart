/// Tipos de referencia y tabla LMS consultable (síncrona una vez cargada).
///
/// Sin dependencias de Flutter. La carga desde assets/disco vive en
/// `lib/reference/store.dart`; aquí solo está la estructura en memoria.
library;

import 'dart:typed_data';

import 'lms.dart';

/// Sexo biológico usado para elegir la curva.
enum Sex { female, male }

/// Los cinco indicadores antropométricos calculados.
enum IndicatorKind {
  weightForAge,
  statureForAge,
  weightForStature,
  bmiForAge,
  headCircumferenceForAge,
}

/// Eje sobre el que se indexa una curva.
enum ReferenceAxis { ageDays, statureCm }

/// Corte en la escala de talla que separa peso/longitud de peso/talla.
/// 731 días = 24 meses (coincide con la regla de posición del diseño).
const int kLengthHeightCutDays = 731;

IndicatorKind? indicatorKindFromId(String id) {
  for (final k in IndicatorKind.values) {
    if (k.name == id) return k;
  }
  return null;
}

Sex sexFromId(String id) => id == 'boys' || id == 'male' ? Sex.male : Sex.female;

/// Una curva LMS indexada por una clave (día de vida o cm de talla).
///
/// Los datos se guardan planos en un `Float64List` `[clave,L,M,S, …]` con
/// búsqueda binaria de paso 4: sin un objeto por fila.
class ReferenceTable {
  ReferenceTable(this.axis, this._data)
      : assert(_data.length >= 4 && _data.length % 4 == 0);

  final ReferenceAxis axis;
  final Float64List _data;

  int get length => _data.length ~/ 4;
  double get minKey => _data[0];
  double get maxKey => _data[_data.length - 4];

  double keyAt(int row) => _data[row * 4];
  Lms lmsAtRow(int row) =>
      Lms(_data[row * 4 + 1], _data[row * 4 + 2], _data[row * 4 + 3]);

  /// LMS en `key`, interpolando linealmente L, M y S entre filas.
  /// Devuelve `null` si `key` cae fuera de `[minKey, maxKey]`.
  Lms? lmsAt(double key) {
    if (key < minKey || key > maxKey) return null;
    // Búsqueda binaria del primer índice con clave >= key.
    var lo = 0;
    var hi = length - 1;
    while (lo < hi) {
      final mid = (lo + hi) >> 1;
      if (keyAt(mid) < key) {
        lo = mid + 1;
      } else {
        hi = mid;
      }
    }
    final k = keyAt(lo);
    if ((k - key).abs() < 1e-9) return lmsAtRow(lo);
    // key está entre lo-1 y lo.
    final a = lo - 1;
    final ka = keyAt(a);
    final f = (key - ka) / (k - ka);
    final la = lmsAtRow(a);
    final lb = lmsAtRow(lo);
    return Lms(
      la.l + f * (lb.l - la.l),
      la.m + f * (lb.m - la.m),
      la.s + f * (lb.s - la.s),
    );
  }
}

/// Banda de clasificación: aplica cuando `z < ltZ` (null = infinito).
class ClassificationBand {
  const ClassificationBand(this.ltZ, this.label);
  final double? ltZ;
  final String label;
}

/// Ventana de validez por edad (en días) de un indicador.
class AgeWindow {
  const AgeWindow(this.minDays, this.maxDays);
  final int minDays;
  final int maxDays;
  bool contains(int days) => days >= minDays && days <= maxDays;
}

/// Fuente de curvas y clasificación de un estándar ya cargado en memoria.
///
/// El motor de indicadores depende solo de esta interfaz, no de cómo se cargó.
abstract class GrowthReference {
  String get standardId;
  String get displayName;
  String get version;
  String get generatedAt;
  String get source;

  /// Curva para el indicador y sexo. Para peso/talla elige longitud (<731 d)
  /// o talla (≥731 d) según `ageDays`. `null` si el estándar no la trae.
  ReferenceTable? tableFor(IndicatorKind kind, Sex sex, {required int ageDays});

  /// Ventana de edad válida del indicador (para el estado "no interpretable").
  AgeWindow? ageWindow(IndicatorKind kind);

  /// Texto de clasificación (Res. 2465 / OMS) para el Z del indicador.
  String classify(IndicatorKind kind, double z);
}
