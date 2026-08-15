import 'package:flutter/material.dart';
import '../theme.dart';
import '../data.dart';
import '../widgets.dart';
import 'patient_detail.dart';

/// Patient database (design 1i): search, filters, list, and local backup card.
class PatientsScreen extends StatefulWidget {
  const PatientsScreen({super.key});

  @override
  State<PatientsScreen> createState() => _PatientsScreenState();
}

class _PatientsScreenState extends State<PatientsScreen> {
  String _query = '';
  int _filter = 0;

  static const _filters = ['Todos', 'Con alerta · 24', 'Prematuros', 'PC'];

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    var list = kSamplePatients.where((pt) {
      if (_query.isNotEmpty && !pt.name.toLowerCase().contains(_query.toLowerCase())) {
        return false;
      }
      if (_filter == 1 && pt.status != ClinicalStatus.warn && pt.status != ClinicalStatus.severe) {
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
                            Text('342 registros · base local cifrada',
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
                          hintText: 'Buscar por nombre o documento',
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
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
              children: [
                SectionCard(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      for (int i = 0; i < list.length; i++) ...[
                        _PatientTile(patient: list[i]),
                        if (i < list.length - 1) const ThinDivider(),
                      ],
                      if (list.isNotEmpty) const ThinDivider(),
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Center(
                          child: Text('Ver los 342 registros',
                              style: TextStyle(
                                  fontSize: 12, fontWeight: FontWeight.w600, color: p.primary)),
                        ),
                      ),
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
                            Text('Último export: 14/08/2026 · JSON + CSV · 1.8 MB',
                                style: TextStyle(fontSize: 11, height: 1.35, color: p.muted)),
                          ],
                        ),
                      ),
                      Text('Ahora',
                          style: TextStyle(
                              fontSize: 11.5, fontWeight: FontWeight.w600, color: p.primary)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PatientTile extends StatelessWidget {
  const _PatientTile({required this.patient});
  final Patient patient;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return InkWell(
      onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => PatientDetailScreen(patient: patient))),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            InitialsAvatar(patient.initials, size: 36),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(patient.name,
                      style: TextStyle(
                          fontSize: 13.5, fontWeight: FontWeight.w500, color: p.onSurface)),
                  const SizedBox(height: 2),
                  Text(patient.meta,
                      style: TextStyle(fontSize: 11, height: 1.35, color: p.muted)),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                StatusChip(patient.tag, patient.status),
                const SizedBox(height: 4),
                Text(patient.date,
                    style: TextStyle(fontSize: 10, fontFamily: 'monospace', color: p.faint)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
