/// Acceso global al [ReferenceStore] cargado (semilla + almacén local).
///
/// Se carga una vez en el splash y luego las pantallas lo consultan de forma
/// síncrona, igual que `themeModeNotifier` en `main.dart`.
library;

import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../anthro/reference.dart';
import 'store.dart';

class ReferenceRepository {
  ReferenceRepository._();

  static ReferenceStore? _store;
  static Object? _error;

  static bool get isLoaded => _store != null;

  /// Error de carga (o `null`). Para mostrarlo en el splash / ajustes.
  static Object? get error => _error;

  static ReferenceStore get store {
    final s = _store;
    if (s == null) {
      throw StateError('ReferenceRepository.ensureLoaded() no se ha completado');
    }
    return s;
  }

  static GrowthReference? reference(String standardId) =>
      _store?.reference(standardId);

  /// Directorio del almacén local (`<appDocs>/reference`), o `null` si no se
  /// pudo resolver (p. ej. en un entorno de pruebas sin path_provider).
  static Future<Directory?> localDir() async {
    try {
      final docs = await getApplicationDocumentsDirectory();
      return Directory('${docs.path}/reference');
    } catch (_) {
      return null;
    }
  }

  /// Carga la referencia si aún no está. La semilla de assets siempre debe
  /// cargar; si falla del todo, se deja `error` y `isLoaded` en false.
  static Future<void> ensureLoaded() async {
    if (_store != null) return;
    try {
      final local = await localDir();
      _store = await ReferenceStore.load(localDir: local);
      _error = null;
    } catch (e) {
      _error = e;
    }
  }
}
