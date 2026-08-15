/// Almacén de datos de referencia: semilla de fábrica (assets) + paquetes
/// instalados localmente, con validación e instalación atómica.
///
/// Tres capas: semilla embebida en `assets/reference/` (siempre presente),
/// almacén local en `<appDocs>/reference/` (paquetes importados que ganan
/// sobre la semilla) y la copia en memoria que consultan los cálculos.
library;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart' show AssetBundle, rootBundle;

import '../anthro/lms.dart';
import '../anthro/reference.dart';

const int kSupportedSchemaVersion = 1;
const String _seedRoot = 'assets/reference';

/// Error de validación de un paquete de referencia.
class ReferenceValidationException implements Exception {
  ReferenceValidationException(this.message);
  final String message;
  @override
  String toString() => 'ReferenceValidationException: $message';
}

/// Origen de los archivos de un paquete (assets o directorio en disco).
abstract class _PackageSource {
  Future<String> readText(String relative);
}

class _AssetSource implements _PackageSource {
  _AssetSource(this.bundle, this.base);
  final AssetBundle bundle;
  final String base;
  @override
  Future<String> readText(String relative) =>
      bundle.loadString('$base/$relative');
}

class _DirSource implements _PackageSource {
  _DirSource(this.dir);
  final Directory dir;
  @override
  Future<String> readText(String relative) =>
      File('${dir.path}/$relative').readAsString();
}

/// Un estándar cargado en memoria; implementa [GrowthReference].
class LoadedStandard implements GrowthReference {
  LoadedStandard({
    required this.standardId,
    required this.displayName,
    required this.version,
    required this.generatedAt,
    required this.source,
    required this.origin,
    required this.tablesFrom,
    required Map<String, ReferenceTable> tables,
    required Map<IndicatorKind, List<ClassificationBand>> classification,
    required Map<IndicatorKind, AgeWindow> ageWindows,
    required this.rowCount,
    // Campos privados poblados vía named params (no admiten formal inicializador).
    // ignore_for_file: prefer_initializing_formals
  })  : _tables = tables,
        _classification = classification,
        _ageWindows = ageWindows;

  @override
  final String standardId;
  @override
  final String displayName;
  @override
  final String version;
  @override
  final String generatedAt;
  @override
  final String source;

  /// De dónde se cargó: `'semilla'` o `'local'`. Para la vista de estado.
  final String origin;

  /// Id del estándar base cuyas curvas reutiliza (p. ej. Colombia → OMS).
  final String? tablesFrom;

  /// Total de filas de datos cargadas (0 si delega en otro estándar).
  final int rowCount;

  final Map<String, ReferenceTable> _tables;
  final Map<IndicatorKind, List<ClassificationBand>> _classification;
  final Map<IndicatorKind, AgeWindow> _ageWindows;

  GrowthReference? _base;

  static String tableKey(IndicatorKind kind, Sex sex, {String? subtype}) =>
      '${kind.name}|${sex.name}|${subtype ?? ''}';

  @override
  ReferenceTable? tableFor(IndicatorKind kind, Sex sex, {required int ageDays}) {
    String? subtype;
    if (kind == IndicatorKind.weightForStature) {
      subtype = ageDays < kLengthHeightCutDays ? 'length' : 'height';
    }
    final own = _tables[tableKey(kind, sex, subtype: subtype)];
    if (own != null) return own;
    return _base?.tableFor(kind, sex, ageDays: ageDays);
  }

  @override
  AgeWindow? ageWindow(IndicatorKind kind) => _ageWindows[kind];

  @override
  String classify(IndicatorKind kind, double z) {
    final bands = _classification[kind];
    if (bands == null || bands.isEmpty) return '';
    for (final b in bands) {
      if (b.ltZ == null || z < b.ltZ!) return b.label;
    }
    return bands.last.label;
  }
}

/// Carga, resuelve y valida los paquetes de referencia.
class ReferenceStore {
  ReferenceStore._(this._standards);

  final Map<String, LoadedStandard> _standards;

  /// Estándares cargados (semilla + local), por id.
  Map<String, LoadedStandard> get standards => Map.unmodifiable(_standards);

  GrowthReference? reference(String standardId) => _standards[standardId];

  /// Carga la semilla de assets y, encima, los paquetes del almacén local.
  ///
  /// Si un paquete local falla al cargar/validar, se ignora y queda la semilla:
  /// la app nunca se queda sin poder calcular.
  static Future<ReferenceStore> load({
    AssetBundle? bundle,
    Directory? localDir,
  }) async {
    final b = bundle ?? rootBundle;
    final result = <String, LoadedStandard>{};

    // 1) Semilla de fábrica.
    final seedIndex =
        jsonDecode(await b.loadString('$_seedRoot/seed_index.json'))
            as Map<String, dynamic>;
    for (final pkg in (seedIndex['packages'] as List)) {
      final dir = (pkg as Map)['dir'] as String;
      final std = await _loadPackage(_AssetSource(b, '$_seedRoot/$dir'),
          origin: 'semilla');
      result[std.standardId] = std;
    }

    // 2) Paquetes locales (ganan sobre la semilla).
    if (localDir != null && await localDir.exists()) {
      final installedFile = File('${localDir.path}/installed.json');
      if (await installedFile.exists()) {
        final installed = jsonDecode(await installedFile.readAsString())
            as Map<String, dynamic>;
        for (final entry in (installed['packages'] as List)) {
          final map = entry as Map;
          final path = '${localDir.path}/${map['dir']}';
          try {
            final std = await _loadPackage(_DirSource(Directory(path)),
                origin: 'local');
            result[std.standardId] = std;
          } catch (_) {
            // Se conserva la semilla ya cargada para este estándar.
          }
        }
      }
    }

    _linkBases(result);
    return ReferenceStore._(result);
  }

  static void _linkBases(Map<String, LoadedStandard> standards) {
    for (final std in standards.values) {
      if (std.tablesFrom != null) {
        std._base = standards[std.tablesFrom];
      }
    }
  }

  static Future<LoadedStandard> _loadPackage(_PackageSource src,
      {required String origin}) async {
    final manifest =
        jsonDecode(await src.readText('manifest.json')) as Map<String, dynamic>;
    final schema = manifest['schemaVersion'] as int;
    if (schema != kSupportedSchemaVersion) {
      throw ReferenceValidationException('schemaVersion $schema no soportado');
    }

    final classification = _parseClassification(
        manifest['classification'] as Map<String, dynamic>?);
    final ageWindows = _parseAgeWindows(manifest['validity'] as Map?);

    final tables = <String, ReferenceTable>{};
    var rowCount = 0;
    final tableList = (manifest['tables'] as List?) ?? const [];
    for (final t in tableList) {
      final map = t as Map<String, dynamic>;
      final kind = indicatorKindFromId(map['kind'] as String);
      if (kind == null) continue;
      final sex = sexFromId(map['sex'] as String);
      final subtype = map['subtype'] as String?;
      final axis = (map['axis'] as String) == 'statureCm'
          ? ReferenceAxis.statureCm
          : ReferenceAxis.ageDays;
      final csv = await src.readText(map['file'] as String);
      _verifyIntegrity(map, csv);
      final table = _parseCsv(axis, csv);
      _verifyClinical(map, table);
      tables[LoadedStandard.tableKey(kind, sex, subtype: subtype)] = table;
      rowCount += table.length;
    }

    return LoadedStandard(
      standardId: manifest['standardId'] as String,
      displayName: manifest['displayName'] as String,
      version: manifest['version'] as String,
      generatedAt: manifest['generatedAt'] as String? ?? '',
      source: manifest['source'] as String? ?? '',
      origin: origin,
      tablesFrom: manifest['tablesFrom'] as String?,
      tables: tables,
      classification: classification,
      ageWindows: ageWindows,
      rowCount: rowCount,
    );
  }

  // ---- Validaciones -------------------------------------------------------

  static void _verifyIntegrity(Map<String, dynamic> table, String csv) {
    final expectedSha = table['sha256'] as String?;
    if (expectedSha != null) {
      final actual = sha256.convert(utf8.encode(csv)).toString();
      if (actual != expectedSha) {
        throw ReferenceValidationException(
            'sha256 no coincide en ${table['file']}');
      }
    }
  }

  static ReferenceTable _parseCsv(ReferenceAxis axis, String csv) {
    final lines = const LineSplitter().convert(csv);
    final values = <double>[];
    var prevKey = double.negativeInfinity;
    var count = 0;
    for (final line in lines) {
      if (line.isEmpty || line.startsWith('key')) continue;
      final parts = line.split(',');
      final key = double.parse(parts[0]);
      if (key <= prevKey) {
        throw ReferenceValidationException('clave no creciente: $line');
      }
      prevKey = key;
      values
        ..add(key)
        ..add(double.parse(parts[1]))
        ..add(double.parse(parts[2]))
        ..add(double.parse(parts[3]));
      count++;
    }
    if (count < 2) {
      throw ReferenceValidationException('tabla con menos de 2 filas');
    }
    return ReferenceTable(axis, Float64List.fromList(values));
  }

  /// Coherencia clínica: reconstruir ±2/±3 DS desde L,M,S debe reproducir los
  /// cortes publicados en `sdChecks` dentro de ±0.01.
  static void _verifyClinical(Map<String, dynamic> table, ReferenceTable ref) {
    final checks = table['sdChecks'] as List?;
    if (checks == null) return;
    for (final c in checks) {
      final map = c as Map;
      final key = (map['key'] as num).toDouble();
      final lms = ref.lmsAt(key);
      if (lms == null) {
        throw ReferenceValidationException('sdCheck fuera de rango: $key');
      }
      void near(double z, String field) {
        final expected = (map[field] as num).toDouble();
        final got = valueFromLms(z, lms);
        if ((got - expected).abs() > 0.01) {
          throw ReferenceValidationException(
              'sdCheck $field en $key: ${got.toStringAsFixed(3)} vs $expected');
        }
      }

      near(-3, 'sd3neg');
      near(-2, 'sd2neg');
      near(2, 'sd2');
      near(3, 'sd3');
    }
  }

  static Map<IndicatorKind, List<ClassificationBand>> _parseClassification(
      Map<String, dynamic>? raw) {
    final out = <IndicatorKind, List<ClassificationBand>>{};
    if (raw == null) return out;
    raw.forEach((key, value) {
      final kind = indicatorKindFromId(key);
      if (kind == null) return;
      out[kind] = [
        for (final b in (value as List))
          ClassificationBand(
            (b as Map)['ltZ'] == null ? null : (b['ltZ'] as num).toDouble(),
            b['label'] as String,
          ),
      ];
    });
    return out;
  }

  static Map<IndicatorKind, AgeWindow> _parseAgeWindows(Map? validity) {
    final out = <IndicatorKind, AgeWindow>{};
    if (validity == null) return out;
    var ageMax = 1856;
    validity.forEach((key, value) {
      final kind = indicatorKindFromId(key as String);
      if (kind == null) return;
      final map = value as Map;
      if (map['axis'] == 'ageDays') {
        final w = AgeWindow((map['min'] as num).toInt(), (map['max'] as num).toInt());
        out[kind] = w;
        if (w.maxDays > ageMax) ageMax = w.maxDays;
      }
    });
    // Peso/talla se valida por edad con la misma ventana 0–5 años; el rango de
    // talla lo impone la propia tabla (lmsAt devuelve null fuera de rango).
    out.putIfAbsent(
        IndicatorKind.weightForStature, () => AgeWindow(0, ageMax));
    return out;
  }

  // ---- Instalación --------------------------------------------------------

  /// Instala un paquete ya desempaquetado en `staged` dentro del almacén local
  /// `localDir`, de forma atómica: valida primero, luego mueve y actualiza el
  /// índice. Si algo falla, `localDir` queda intacto. Devuelve el estándar.
  ///
  /// Preparada para la entrega de importación; el flujo de UI la usará luego.
  static Future<LoadedStandard> install(
      Directory staged, Directory localDir) async {
    // 1) Validar cargando desde el directorio staged (lanza si algo falla).
    final std =
        await _loadPackage(_DirSource(staged), origin: 'local');

    // 2) Copiar a un destino temporal dentro del almacén y luego renombrar.
    await localDir.create(recursive: true);
    final destName = std.standardId;
    final tmp = Directory('${localDir.path}/.tmp_$destName');
    if (await tmp.exists()) await tmp.delete(recursive: true);
    await _copyDir(staged, tmp);
    final dest = Directory('${localDir.path}/$destName');
    if (await dest.exists()) await dest.delete(recursive: true);
    await tmp.rename(dest.path);

    // 3) Actualizar installed.json.
    final indexFile = File('${localDir.path}/installed.json');
    final index = <String, dynamic>{'schemaVersion': kSupportedSchemaVersion};
    final packages = <Map<String, dynamic>>[];
    if (await indexFile.exists()) {
      final prev =
          jsonDecode(await indexFile.readAsString()) as Map<String, dynamic>;
      for (final e in (prev['packages'] as List? ?? const [])) {
        final m = (e as Map).cast<String, dynamic>();
        if (m['standardId'] != std.standardId) packages.add(m);
      }
    }
    packages.add({
      'standardId': std.standardId,
      'dir': destName,
      'version': std.version,
    });
    index['packages'] = packages;
    await indexFile.writeAsString(jsonEncode(index));
    return std;
  }

  static Future<void> _copyDir(Directory from, Directory to) async {
    await to.create(recursive: true);
    await for (final entity in from.list(recursive: true)) {
      final rel = entity.path.substring(from.path.length + 1);
      if (entity is Directory) {
        await Directory('${to.path}/$rel').create(recursive: true);
      } else if (entity is File) {
        final target = File('${to.path}/$rel');
        await target.parent.create(recursive: true);
        await entity.copy(target.path);
      }
    }
  }
}
