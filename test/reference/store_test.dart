import 'dart:convert';
import 'dart:io';

import 'package:anthro_calculator_app/anthro/reference.dart';
import 'package:anthro_calculator_app/reference/store.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('carga de la semilla (assets)', () {
    late ReferenceStore store;
    setUpAll(() async {
      store = await ReferenceStore.load();
    });

    test('trae los dos estándares OMS y Colombia', () {
      expect(store.reference('oms-2006'), isNotNull);
      expect(store.reference('col-2465'), isNotNull);
      expect(store.standards.length, 2);
    });

    test('OMS resuelve las 12 curvas por sexo', () {
      final oms = store.reference('oms-2006')!;
      for (final sex in Sex.values) {
        expect(oms.tableFor(IndicatorKind.weightForAge, sex, ageDays: 823), isNotNull);
        expect(oms.tableFor(IndicatorKind.statureForAge, sex, ageDays: 823), isNotNull);
        expect(oms.tableFor(IndicatorKind.bmiForAge, sex, ageDays: 823), isNotNull);
        expect(oms.tableFor(IndicatorKind.headCircumferenceForAge, sex, ageDays: 823), isNotNull);
        // Peso/talla usa longitud (<731 d) o talla (≥731 d).
        expect(oms.tableFor(IndicatorKind.weightForStature, sex, ageDays: 300), isNotNull);
        expect(oms.tableFor(IndicatorKind.weightForStature, sex, ageDays: 900), isNotNull);
      }
    });

    test('peso/talla cambia de tabla en el corte de 731 días', () {
      final oms = store.reference('oms-2006')!;
      final length = oms.tableFor(IndicatorKind.weightForStature, Sex.female, ageDays: 300)!;
      final height = oms.tableFor(IndicatorKind.weightForStature, Sex.female, ageDays: 900)!;
      // La curva de longitud arranca en 45 cm; la de talla en 65 cm.
      expect(length.minKey, closeTo(45.0, 1e-9));
      expect(height.minKey, closeTo(65.0, 1e-9));
    });

    test('Colombia (tablesFrom) delega sus curvas en OMS', () {
      final col = store.reference('col-2465')!;
      expect(col.tableFor(IndicatorKind.weightForAge, Sex.female, ageDays: 823), isNotNull);
      final oms = store.reference('oms-2006')!;
      final cM = col.tableFor(IndicatorKind.weightForAge, Sex.female, ageDays: 823)!.lmsAt(823)!.m;
      final oM = oms.tableFor(IndicatorKind.weightForAge, Sex.female, ageDays: 823)!.lmsAt(823)!.m;
      expect(cM, oM); // mismas curvas
    });

    test('la redacción de clasificación difiere entre OMS y Colombia', () {
      final oms = store.reference('oms-2006')!;
      final col = store.reference('col-2465')!;
      // Alguna banda debe diferir para que el selector signifique algo.
      final differs = IndicatorKind.values.any((k) {
        for (final z in [-2.5, -1.5, 0.0, 1.5]) {
          if (oms.classify(k, z) != col.classify(k, z)) return true;
        }
        return false;
      });
      expect(differs, isTrue);
    });

    test('la ventana de edad marca 6 años como no interpretable', () {
      final oms = store.reference('oms-2006')!;
      final w = oms.ageWindow(IndicatorKind.weightForAge)!;
      expect(w.contains(823), isTrue);
      expect(w.contains(2200), isFalse); // ~6 años
    });
  });

  group('instalación y validación en disco', () {
    late Directory tmp;
    setUp(() async {
      tmp = await Directory.systemTemp.createTemp('ref_store_test');
    });
    tearDown(() async {
      if (await tmp.exists()) await tmp.delete(recursive: true);
    });

    Future<Directory> stagePackage({
      required String csv,
      String? sha,
      List<Map<String, dynamic>>? sdChecks,
      String standardId = 'test-std',
    }) async {
      final pkg = await Directory('${tmp.path}/staged').create(recursive: true);
      await Directory('${pkg.path}/tables').create();
      await File('${pkg.path}/tables/t.csv').writeAsString(csv);
      final table = <String, dynamic>{
        'kind': 'weightForAge',
        'sex': 'girls',
        'axis': 'ageDays',
        'file': 'tables/t.csv',
      };
      if (sha != null) table['sha256'] = sha;
      if (sdChecks != null) table['sdChecks'] = sdChecks;
      final manifest = {
        'schemaVersion': 1,
        'standardId': standardId,
        'displayName': 'Prueba',
        'version': '1.0',
        'generatedAt': '2026-08-15',
        'source': 'test',
        'validity': {
          'weightForAge': {'axis': 'ageDays', 'min': 0, 'max': 1856}
        },
        'tables': [table],
        'classification': {
          'weightForAge': [
            {'ltZ': -2, 'label': 'bajo'},
            {'ltZ': null, 'label': 'normal'}
          ]
        },
      };
      await File('${pkg.path}/manifest.json').writeAsString(jsonEncode(manifest));
      return pkg;
    }

    String shaOf(String s) => sha256.convert(utf8.encode(s)).toString();

    const goodCsv = 'key,L,M,S\n0,1,10,0.1\n100,1,12,0.1\n';

    test('instala un paquete válido y lo deja consultable', () async {
      final staged = await stagePackage(csv: goodCsv, sha: shaOf(goodCsv));
      final local = Directory('${tmp.path}/store');
      final std = await ReferenceStore.install(staged, local);
      expect(std.standardId, 'test-std');
      expect(await File('${local.path}/installed.json').exists(), isTrue);

      final store = await ReferenceStore.load(localDir: local);
      // La semilla (assets) sigue estando + el nuevo estándar local.
      expect(store.reference('test-std'), isNotNull);
      expect(store.reference('oms-2006'), isNotNull);
    });

    test('rechaza sha256 incorrecto sin dejar nada instalado', () async {
      final staged = await stagePackage(csv: goodCsv, sha: 'deadbeef');
      final local = Directory('${tmp.path}/store');
      await expectLater(
        ReferenceStore.install(staged, local),
        throwsA(isA<ReferenceValidationException>()),
      );
      expect(await File('${local.path}/installed.json').exists(), isFalse);
    });

    test('rechaza LMS que no reproducen sus cortes SD', () async {
      // sd2neg real de (L=1,M=10,S=0.1) en key 0 es 8.0; ponemos 99 → falla.
      final staged = await stagePackage(
        csv: goodCsv,
        sha: shaOf(goodCsv),
        sdChecks: [
          {'key': 0, 'sd3neg': 7.0, 'sd2neg': 99.0, 'sd2': 12.0, 'sd3': 13.0}
        ],
      );
      final local = Directory('${tmp.path}/store');
      await expectLater(
        ReferenceStore.install(staged, local),
        throwsA(isA<ReferenceValidationException>()),
      );
    });

    test('rechaza claves no crecientes', () async {
      const badCsv = 'key,L,M,S\n0,1,10,0.1\n0,1,12,0.1\n';
      final staged = await stagePackage(csv: badCsv, sha: shaOf(badCsv));
      final local = Directory('${tmp.path}/store');
      await expectLater(
        ReferenceStore.install(staged, local),
        throwsA(isA<ReferenceValidationException>()),
      );
    });
  });
}
