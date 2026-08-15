import 'package:flutter/material.dart';
import '../theme.dart';
import '../db/database.dart';
import '../db/models.dart';
import '../widgets.dart';
import 'patient_detail.dart';
import 'patient_format.dart';

/// Patient database (design 1i): search, filters, list, and local backup card.
/// La lista se lee de la base SQLite local.
class PatientsScreen extends StatefulWidget {
  const PatientsScreen({super.key});

  @override
  State<PatientsScreen> createState() => _PatientsScreenState();
}

class _PatientsScreenState extends State<PatientsScreen> {
  String _query = '';
  int _filter = 0;
  List<SavedPatient>? _patients;

  static const _filters = ['Todos', 'Con alerta', 'Prematuros', 'PC'];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final patients = await AnthroDatabase.instance.listPatients();
    if (!mounted) return;
    setState(() => _patients = patients);
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final patients = _patients ?? const <SavedPatient>[];
    final loading = _patients == null;

    final list = patients.where((pt) {
      final latest = pt.latest;
      if (_query.isNotEmpty &&
          !pt.name.toLowerCase().contains(_query.toLowerCase())) {
        return false;
      }
      if (_filter == 1 &&
          (latest == null ||
              (latest.overall != ClinicalStatus.warn &&
                  latest.overall != ClinicalStatus.bad &&
                  latest.overall != ClinicalStatus.severe))) {
        return false;
      }
      return true;
    }).toList();

    return Scaffold(
      backgroundColor: p.background,
      body: Column(
        children: [
          // Header.
          Container(
            color: p.surface,
            padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top),
            child: Container(
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: p.border)),
              ),
              padding: const EdgeInsets.fromLTRB(8, 8, 16, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.of(context).maybePop(),
                        icon: Icon(Icons.arrow_back, color: p.primary, size: 22),
                        splashRadius: 22,
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Pacientes',
                                style: TextStyle(
                                    fontSize: 18, fontWeight: FontWeight.w600, color: p.onSurface)),
                            const SizedBox(height: 2),
                            Text(
                                '${patients.length} registro${patients.length == 1 ? '' : 's'} · base local',
                                style: TextStyle(fontSize: 11, color: p.muted)),
                          ],
                        ),
                      ),
                      SecondaryButton('Importar', onTap: () {}),
                      const SizedBox(width: 8),
                      PrimaryButton('Exportar', expand: false, onTap: () {}),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: Container(
                      decoration: BoxDecoration(
                        color: p.segmentBg,
                        borderRadius: BorderRadius.circular(Radii.control),
                      ),
                      child: TextField(
                        onChanged: (v) => setState(() => _query = v),
                        style: TextStyle(fontSize: 13, color: p.onSurface),
                        decoration: InputDecoration(
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          border: InputBorder.none,
                          prefixIcon: Icon(Icons.search, size: 18, color: p.faint),
                          hintText: 'Buscar por nombre',
                          hintStyle: TextStyle(fontSize: 13, color: p.faint),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 30,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.only(left: 8),
                      itemCount: _filters.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 6),
                      itemBuilder: (context, i) {
                        final active = i == _filter;
                        final warn = i == 1;
                        return GestureDetector(
                          onTap: () => setState(() => _filter = i),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 11),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: active
                                  ? (warn ? p.warnBg : p.primary)
                                  : (warn ? p.warnBg : p.segmentBg),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(_filters[i],
                                style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w600,
                                    color: active
                                        ? (warn ? p.warnText : (p.isDark ? p.background : Colors.white))
                                        : (warn ? p.warnText : p.muted))),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: loading
                ? const Center(child: CircularProgressIndicator())
                : ListView(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
                    children: [
                      if (list.isEmpty)
                        _emptyState(context)
                      else ...[
                        SectionCard(
                          padding: EdgeInsets.zero,
                          child: Column(
                            children: [
                              for (int i = 0; i < list.length; i++) ...[
                                _PatientTile(patient: list[i], onTap: () {
                                  Navigator.of(context).push(MaterialPageRoute(
                                      builder: (_) =>
                                          PatientDetailScreen(patient: list[i])));
                                }),
                                if (i < list.length - 1) const ThinDivider(),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: p.surface,
                            borderRadius: BorderRadius.circular(Radii.card),
                            border: Border.all(
                                color: p.isDark ? p.border : const Color(0xFFCFD8DF),
                                style: BorderStyle.solid),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 38,
                                height: 38,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: p.okBg,
                                  borderRadius: BorderRadius.circular(Radii.control),
                                ),
                                child: Icon(Icons.import_export, color: p.ok, size: 18),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Respaldo local',
                                        style: TextStyle(
                                            fontSize: 12.5, fontWeight: FontWeight.w600, color: p.onSurface)),
                                    const SizedBox(height: 2),
                                    Text('La base local se guarda en el dispositivo',
                                        style: TextStyle(fontSize: 11, height: 1.35, color: p.muted)),
                                  ],
                                ),
                              ),
                              Text('Local',
                                  style: TextStyle(
                                      fontSize: 11.5, fontWeight: FontWeight.w600, color: p.primary)),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _emptyState(BuildContext context) {
    final p = AppPalette.of(context);
    return Column(
      children: [
        const SizedBox(height: 24),
        Container(
          width: 56,
          height: 56,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: p.primaryTint,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(Icons.people_outline, color: p.primary, size: 26),
        ),
        const SizedBox(height: 14),
        Text('Aún no hay mediciones guardadas',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: p.onSurface)),
        const SizedBox(height: 5),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Text(
            'Calcula una medición y actívala con "Guardar esta medición" para que el paciente aparezca aquí.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, height: 1.45, color: p.muted),
          ),
        ),
      ],
    );
  }
}

class _PatientTile extends StatelessWidget {
  const _PatientTile({required this.patient, required this.onTap});
  final SavedPatient patient;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final latest = patient.latest;
    final status = latest?.overall ?? ClinicalStatus.none;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            InitialsAvatar(initialsOf(patient.name), size: 36),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(patient.name,
                      style: TextStyle(
                          fontSize: 13.5, fontWeight: FontWeight.w500, color: p.onSurface)),
                  const SizedBox(height: 2),
                  Text(patientMeta(latest),
                      style: TextStyle(fontSize: 11, height: 1.35, color: p.muted)),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                StatusChip(patientTag(latest), status),
                const SizedBox(height: 4),
                Text(relativeDateLabel(latest),
                    style: TextStyle(fontSize: 10, fontFamily: 'monospace', color: p.faint)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
