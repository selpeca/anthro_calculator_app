import 'package:flutter/material.dart';
import '../theme.dart';
import '../widgets.dart';
import '../reference/reference_repository.dart';
import '../reference/store.dart';
import 'common.dart';

/// Vista de solo lectura del estado de las tablas de referencia instaladas.
///
/// Muestra, por estándar, su nombre, versión, fecha de generación, origen y
/// número de filas. La importación/actualización de paquetes es trabajo de una
/// entrega posterior (el almacén ya soporta `ReferenceStore.install`).
class ReferenceStatusScreen extends StatelessWidget {
  const ReferenceStatusScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final loaded = ReferenceRepository.isLoaded;
    final standards = loaded
        ? (ReferenceRepository.store.standards.values.toList()
          ..sort((a, b) => a.standardId.compareTo(b.standardId)))
        : <LoadedStandard>[];

    return Scaffold(
      backgroundColor: p.background,
      appBar: ScreenHeader(
        title: 'Datos de referencia',
        subtitle: 'Tablas OMS / Colombia · sin conexión',
        statusDot: loaded ? p.ok : p.bad,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
        children: [
          if (!loaded)
            SectionCard(
              leftAccent: p.bad,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('No se pudieron cargar las tablas',
                      style: TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w600, color: p.badText)),
                  const SizedBox(height: 6),
                  Text('${ReferenceRepository.error ?? 'Error desconocido'}',
                      style: TextStyle(fontSize: 11.5, height: 1.4, color: p.muted)),
                ],
              ),
            )
          else ...[
            Text(
              'Los cálculos usan estas tablas de forma local, sin conexión. '
              'Cada estándar puede actualizarse importando un paquete verificado.',
              style: TextStyle(fontSize: 11.5, height: 1.4, color: p.muted),
            ),
            const SizedBox(height: 12),
            for (final std in standards) ...[
              _StandardCard(std: std),
              const SizedBox(height: 10),
            ],
          ],
          const Footer(),
        ],
      ),
    );
  }
}

class _StandardCard extends StatelessWidget {
  const _StandardCard({required this.std});
  final LoadedStandard std;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final delegated = std.tablesFrom != null;
    return SectionCard(
      leftAccent: p.primary,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(std.displayName,
                    style: TextStyle(
                        fontSize: 13.5, fontWeight: FontWeight.w700, color: p.onSurface)),
              ),
              StatusChip(
                std.origin == 'local' ? 'Actualizado' : 'De fábrica',
                std.origin == 'local' ? ClinicalStatus.ok : ClinicalStatus.none,
              ),
            ],
          ),
          const SizedBox(height: 10),
          _row(p, 'Versión', std.version),
          _row(p, 'Generado', std.generatedAt),
          _row(p, 'Origen',
              delegated ? 'Curvas de ${std.tablesFrom}' : '${std.rowCount} filas LMS'),
          const SizedBox(height: 8),
          Text(std.source,
              style: TextStyle(fontSize: 10.5, height: 1.4, color: p.faint)),
        ],
      ),
    );
  }

  Widget _row(AppPalette p, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 78,
            child: Text(label,
                style: TextStyle(fontSize: 11.5, color: p.muted)),
          ),
          Expanded(
            child: Text(value,
                style: TextStyle(
                    fontSize: 11.5, fontWeight: FontWeight.w500, color: p.onSurface)),
          ),
        ],
      ),
    );
  }
}
