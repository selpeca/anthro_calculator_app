import 'package:flutter/material.dart';

import '../db/database.dart';
import '../db/models.dart';
import '../theme.dart';
import '../widgets.dart';
import 'common.dart';
import 'patient_format.dart';

/// Monitoreo y mantenimiento de la base local (SQLite / sqflite).
///
/// Muestra indicadores del estado —conteos por tabla, integridad, tamaño en
/// disco y registros a depurar— y ofrece acciones de limpieza: eliminar fichas
/// vacías, depurar registros huérfanos, compactar (VACUUM) y borrar todos los
/// datos. Se abre desde el menú lateral (`app_drawer.dart`).
class DatabaseStatusScreen extends StatefulWidget {
  const DatabaseStatusScreen({super.key});

  @override
  State<DatabaseStatusScreen> createState() => _DatabaseStatusScreenState();
}

class _DatabaseStatusScreenState extends State<DatabaseStatusScreen> {
  DatabaseStats? _stats;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final stats = await AnthroDatabase.instance.stats();
    if (!mounted) return;
    setState(() => _stats = stats);
  }

  /// Corre una acción de mantenimiento, refresca los indicadores y avisa el
  /// resultado. Bloquea la interfaz mientras trabaja para evitar toques dobles.
  Future<void> _run(Future<String> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final message = await action();
      final stats = await AnthroDatabase.instance.stats();
      if (!mounted) return;
      setState(() {
        _stats = stats;
        _busy = false;
      });
      _snack(message);
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      _snack('No se pudo completar la operación: $e');
    }
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _deleteEmptyPatients() => _run(() async {
        final n = await AnthroDatabase.instance.deleteEmptyPatients();
        return n == 0
            ? 'No había fichas vacías'
            : 'Eliminadas $n ficha${n == 1 ? '' : 's'} sin mediciones';
      });

  Future<void> _purgeOrphans() => _run(() async {
        final n = await AnthroDatabase.instance.purgeOrphans();
        return n == 0
            ? 'No había registros huérfanos'
            : 'Depurados $n registro${n == 1 ? '' : 's'} huérfano${n == 1 ? '' : 's'}';
      });

  Future<void> _vacuum() => _run(() async {
        await AnthroDatabase.instance.vacuum();
        return 'Base de datos compactada';
      });

  Future<void> _confirmDeleteAll(DatabaseStats s) async {
    final p = AppPalette.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: p.surface,
        title: const Text('Borrar todos los datos'),
        content: Text(
          'Se eliminarán ${s.patientCount} paciente${s.patientCount == 1 ? '' : 's'} '
          'y ${s.measurementCount} medición${s.measurementCount == 1 ? '' : 'es'}. '
          'Esta acción no se puede deshacer.',
          style: TextStyle(fontSize: 13, height: 1.4, color: p.onSurface),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: p.bad),
            child: const Text('Borrar todo'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _run(() async {
      await AnthroDatabase.instance.deleteAllData();
      return 'Se borraron todos los datos';
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final s = _stats;

    return Scaffold(
      backgroundColor: p.background,
      appBar: ScreenHeader(
        title: 'Base de datos local',
        subtitle: 'Monitoreo y mantenimiento · offline',
        statusDot: s == null ? p.faint : _healthColor(p, s),
        trailing: _busy
            ? Padding(
                padding: const EdgeInsets.only(right: 6),
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: p.primary),
                ),
              )
            : IconButton(
                onPressed: _load,
                icon: Icon(Icons.refresh_rounded, color: p.primary, size: 22),
                splashRadius: 20,
                tooltip: 'Actualizar',
              ),
      ),
      body: s == null
          ? Center(child: CircularProgressIndicator(color: p.primary))
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
              children: [
                _StateCard(stats: s),
                const SizedBox(height: 16),
                const SectionLabel('Indicadores'),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                        child: _StatTile(
                            label: 'Pacientes', value: '${s.patientCount}')),
                    const SizedBox(width: 10),
                    Expanded(
                        child: _StatTile(
                            label: 'Mediciones',
                            value: '${s.measurementCount}')),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                        child: _StatTile(
                            label: 'Indicadores',
                            value: '${s.indicatorCount}')),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _StatTile(
                        label: 'Fichas vacías',
                        value: '${s.emptyPatientCount}',
                        valueColor: s.emptyPatientCount > 0 ? p.warn : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                _PeriodTile(stats: s),
                const SizedBox(height: 16),
                const SectionLabel('Mantenimiento'),
                const SizedBox(height: 10),
                _ActionTile(
                  icon: Icons.cleaning_services_outlined,
                  title: 'Eliminar fichas vacías',
                  subtitle: s.emptyPatientCount == 0
                      ? 'No hay fichas sin mediciones'
                      : '${s.emptyPatientCount} ficha${s.emptyPatientCount == 1 ? '' : 's'} sin mediciones',
                  enabled: !_busy && s.emptyPatientCount > 0,
                  onTap: _deleteEmptyPatients,
                ),
                const SizedBox(height: 8),
                _ActionTile(
                  icon: Icons.link_off_rounded,
                  title: 'Depurar registros huérfanos',
                  subtitle: s.orphanCount == 0
                      ? 'Sin registros inconsistentes'
                      : '${s.orphanCount} registro${s.orphanCount == 1 ? '' : 's'} sin relación',
                  enabled: !_busy && s.orphanCount > 0,
                  onTap: _purgeOrphans,
                ),
                const SizedBox(height: 8),
                _ActionTile(
                  icon: Icons.compress_rounded,
                  title: 'Compactar base (VACUUM)',
                  subtitle: 'Recupera el espacio liberado por borrados',
                  enabled: !_busy,
                  onTap: _vacuum,
                ),
                const SizedBox(height: 8),
                _ActionTile(
                  icon: Icons.delete_forever_outlined,
                  title: 'Borrar todos los datos',
                  subtitle: 'Elimina todos los pacientes y mediciones',
                  danger: true,
                  enabled: !_busy && (s.patientCount + s.measurementCount) > 0,
                  onTap: () => _confirmDeleteAll(s),
                ),
                const Footer(),
              ],
            ),
    );
  }

  static Color _healthColor(AppPalette p, DatabaseStats s) => !s.integrityOk
      ? p.bad
      : (s.orphanCount > 0 ? p.warn : p.ok);
}

/// Tarjeta de cabecera con el estado general: salud, integridad, tamaño y ruta.
class _StateCard extends StatelessWidget {
  const _StateCard({required this.stats});
  final DatabaseStats stats;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final status = !stats.integrityOk
        ? ClinicalStatus.bad
        : (stats.orphanCount > 0 ? ClinicalStatus.warn : ClinicalStatus.ok);
    final label = !stats.integrityOk
        ? 'Requiere atención'
        : (stats.orphanCount > 0 ? 'Con avisos' : 'Saludable');

    return SectionCard(
      leftAccent: p.statusColor(status),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Estado de la base',
                        style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            color: p.onSurface)),
                    const SizedBox(height: 2),
                    Text('Esquema v${stats.schemaVersion} · SQLite local',
                        style: TextStyle(fontSize: 11, color: p.muted)),
                  ],
                ),
              ),
              StatusChip(label, status),
            ],
          ),
          const SizedBox(height: 12),
          _KvRow(
            label: 'Integridad',
            value: stats.integrityOk ? 'Correcta' : stats.integrityDetail,
            valueColor: stats.integrityOk ? null : p.badText,
          ),
          _KvRow(
            label: 'Huérfanos',
            value: stats.orphanCount == 0 ? 'Ninguno' : '${stats.orphanCount}',
            valueColor: stats.orphanCount == 0 ? null : p.warnText,
          ),
          _KvRow(label: 'Tamaño', value: _formatBytes(stats.sizeBytes)),
          const SizedBox(height: 8),
          Text(stats.path,
              style: TextStyle(fontSize: 10.5, height: 1.4, color: p.faint)),
        ],
      ),
    );
  }
}

class _KvRow extends StatelessWidget {
  const _KvRow({required this.label, required this.value, this.valueColor});
  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 88,
            child: Text(label, style: TextStyle(fontSize: 11.5, color: p.muted)),
          ),
          Expanded(
            child: Text(value,
                style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: valueColor ?? p.onSurface)),
          ),
        ],
      ),
    );
  }
}

/// Contador grande (una métrica de una tabla) dentro de una tarjeta compacta.
class _StatTile extends StatelessWidget {
  const _StatTile({required this.label, required this.value, this.valueColor});
  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(Radii.card),
        border: Border.all(color: p.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionLabel(label),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              fontFeatures: kTabular,
              color: valueColor ?? p.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}

/// Rango temporal cubierto por las mediciones guardadas.
class _PeriodTile extends StatelessWidget {
  const _PeriodTile({required this.stats});
  final DatabaseStats stats;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final hasData = stats.earliest != null && stats.latest != null;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(Radii.card),
        border: Border.all(color: p.border),
      ),
      child: Row(
        children: [
          Icon(Icons.date_range_outlined, size: 18, color: p.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Rango de mediciones',
                    style: TextStyle(fontSize: 11.5, color: p.muted)),
                const SizedBox(height: 3),
                Text(
                  hasData
                      ? '${historyDateLabel(stats.earliest!)}  —  ${historyDateLabel(stats.latest!)}'
                      : 'Sin mediciones registradas',
                  style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: p.onSurface),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Fila de acción de mantenimiento (icono + título + descripción). Se atenúa y
/// deja de responder cuando [enabled] es `false`; [danger] la pinta en rojo.
class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.enabled = true,
    this.danger = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool enabled;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final accent = danger ? p.bad : p.primary;
    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: Material(
        color: p.surface,
        borderRadius: BorderRadius.circular(Radii.card),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: enabled ? onTap : null,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(Radii.card),
              border: Border.all(
                  color: danger ? p.bad.withValues(alpha: 0.4) : p.border),
            ),
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: danger ? p.badBg : p.primaryTint,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, size: 18, color: accent),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: danger ? p.badText : p.onSurface)),
                      const SizedBox(height: 2),
                      Text(subtitle,
                          style: TextStyle(fontSize: 11, color: p.muted)),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, size: 18, color: p.faint),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Formatea bytes a una etiqueta legible (KB/MB…), sin decimales innecesarios.
String _formatBytes(int bytes) {
  if (bytes <= 0) return '0 KB';
  const units = ['B', 'KB', 'MB', 'GB'];
  var size = bytes.toDouble();
  var i = 0;
  while (size >= 1024 && i < units.length - 1) {
    size /= 1024;
    i++;
  }
  final text =
      (size >= 100 || i == 0) ? size.toStringAsFixed(0) : size.toStringAsFixed(1);
  return '$text ${units[i]}';
}
