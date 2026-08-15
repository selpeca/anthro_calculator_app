/// Plausibilidad de un valor medido (coloreado del campo), consciente de la
/// edad cuando hay referencia disponible.
///
/// Reemplaza a los antiguos `Anthro.weightState`/`heightState`, que usaban
/// umbrales fijos calibrados para 27 meses.
library;

import '../theme.dart' show ClinicalStatus;
import 'lms.dart';
import 'reference.dart';

/// Rango de cordura estático por si aún no hay una edad válida.
class _Sanity {
  const _Sanity(this.min, this.max);
  final double min;
  final double max;
}

const _sanityWeight = _Sanity(0.5, 60);
const _sanityStature = _Sanity(20, 150);
const _sanityHead = _Sanity(20, 70);

/// Estado del campo de peso (kg).
ClinicalStatus weightPlausibility(double? kg, {ReferenceTable? table, int? ageDays}) =>
    _plausible(kg, table, ageDays?.toDouble(), _sanityWeight,
        warnSd: 3, badSd: 5);

/// Estado del campo de talla/longitud (cm).
ClinicalStatus staturePlausibility(double? cm, {ReferenceTable? table, int? ageDays}) =>
    _plausible(cm, table, ageDays?.toDouble(), _sanityStature,
        warnSd: 3, badSd: 6);

/// Estado del campo de perímetro cefálico (cm). Opcional: vacío → neutro.
ClinicalStatus headPlausibility(double? cm, {ReferenceTable? table, int? ageDays}) {
  if (cm == null) return ClinicalStatus.none;
  return _plausible(cm, table, ageDays?.toDouble(), _sanityHead,
      warnSd: 3, badSd: 5);
}

ClinicalStatus _plausible(
  double? value,
  ReferenceTable? table,
  double? key,
  _Sanity sanity, {
  required double warnSd,
  required double badSd,
}) {
  if (value == null || value <= 0) return ClinicalStatus.bad;

  // Sin referencia/edad válida: solo cordura. Dentro del rango → neutro, para
  // no pintar verde ni rojo antes de tener con qué comparar.
  if (table == null || key == null) {
    if (value < sanity.min || value > sanity.max) return ClinicalStatus.bad;
    return ClinicalStatus.none;
  }

  final lms = table.lmsAt(key);
  if (lms == null) {
    if (value < sanity.min || value > sanity.max) return ClinicalStatus.bad;
    return ClinicalStatus.none;
  }

  final z = rawZFromLms(value, lms).abs();
  if (z.isNaN || z > badSd) return ClinicalStatus.bad;
  if (z > warnSd) return ClinicalStatus.warn;
  return ClinicalStatus.ok;
}
