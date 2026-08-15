import 'package:flutter/material.dart';
import '../theme.dart';
import '../db/database.dart';
import '../db/models.dart';
import '../widgets.dart';
import 'common.dart';
import 'calculator.dart';
import 'velocity.dart';
import 'patients.dart';
import 'patient_detail.dart';
import 'patient_format.dart';
import 'reference_status.dart';

import '../settings.dart';
import 'app_drawer.dart';
import 'about_dialog.dart';

/// Home / dashboard (design 1b): branded header, quick action, module grid and
/// a preview of the patient database (leída de la base local).
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<SavedPatient>? _patients;

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

  void _open(BuildContext context, Widget screen) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final patients = _patients ?? const <SavedPatient>[];
    return Scaffold(
      backgroundColor: p.background,
      drawer: const AppDrawer(),
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          _Header(),
          Transform.translate(
            offset: const Offset(0, -10),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SectionCard(
                child: Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: p.primaryTint,
                        borderRadius: BorderRadius.circular(11),
                      ),
                      child: Icon(Icons.add, color: p.primary, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Nueva medición rápida',
                              style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: p.onSurface)),
                          const SizedBox(height: 2),
                          Text('3 toques: paciente → medidas → resultados',
                              style: TextStyle(fontSize: 12, color: p.muted)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () => _open(context, const CalculatorScreen()),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                        decoration: BoxDecoration(
                          color: p.primary,
                          borderRadius: BorderRadius.circular(9),
                        ),
                        child: Text('Iniciar',
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: p.isDark ? p.background : Colors.white)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
            child: SectionLabel('Módulos'),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: _ModuleCard(
                    iconBg: p.primaryTint,
                    icon: _boxIcon(p.primary),
                    title: 'Calculadora estándar',
                    subtitle: 'OMS · Colombia',
                    onTap: () => _open(context, const CalculatorScreen()),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _ModuleCard(
                    iconBg: p.okBg,
                    icon: Icon(Icons.show_chart, color: p.ok, size: 18),
                    title: 'Velocidad de crecimiento',
                    subtitle: 'Δ entre evaluaciones',
                    onTap: () => _open(context, const VelocityScreen()),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: SectionCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Base de datos de pacientes',
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: p.onSurface)),
                        Text(
                            '${patients.length} registro${patients.length == 1 ? '' : 's'}',
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: p.primary)),
                      ],
                    ),
                  ),
                  const ThinDivider(),
                  if (patients.isEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 14, 14, 4),
                      child: Text('Aún no hay mediciones guardadas.',
                          style: TextStyle(fontSize: 12, height: 1.35, color: p.muted)),
                    )
                  else
                    for (final patient in patients.take(2)) ...[
                      _PatientRow(
                          patient: patient,
                          onTap: () => _open(
                              context, PatientDetailScreen(patient: patient))),
                      const ThinDivider(),
                    ],
                  InkWell(
                    onTap: () => _open(context, const PatientsScreen()),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Center(
                        child: Text(
                            patients.isEmpty
                                ? 'Ir a la base de pacientes'
                                : 'Ver todos los registros',
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: p.primary)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Footer(),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  static Widget _boxIcon(Color color) => Icon(
        Icons.calculate_outlined,
        color: color,
        size: 18,
      );
}

class _Header extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Container(
      color: p.primary,
      padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 14, 16, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Builder(
                        builder: (context) => IconButton(
                          onPressed: () => Scaffold.of(context).openDrawer(),
                          icon: const Icon(Icons.menu_rounded, color: Colors.white, size: 26),
                          tooltip: 'Abrir Menú Principal',
                        ),
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          'Anthro Calculator App',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            letterSpacing: -0.3,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => showAboutAppDialog(context),
                  icon: const Icon(Icons.info_outline_rounded, color: Colors.white, size: 24),
                  tooltip: 'Acerca de Anthro Calculator',
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                GestureDetector(
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => const ReferenceStatusScreen())),
                  child: HeaderPill(
                    text: 'Offline · datos locales',
                    dotColor: const Color(0xFF8CDEBA),
                    textColor: const Color(0xFFD5F2E5),
                    background: const Color(0xFF1F8A5B).withValues(alpha: 0.22),
                    borderColor: const Color(0xFF8CDEBA).withValues(alpha: 0.45),
                  ),
                ),
                const SizedBox(width: 8),
                ValueListenableBuilder<UnitSystem>(
                  valueListenable: unitSystemNotifier,
                  builder: (context, unit, _) {
                    return HeaderPill(
                      text: unit == UnitSystem.metric ? 'Métrico (kg, cm)' : 'Imperial (lb, in)',
                      textColor: Colors.white.withValues(alpha: 0.9),
                      background: Colors.white.withValues(alpha: 0.12),
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ModuleCard extends StatelessWidget {
  const _ModuleCard({
    required this.iconBg,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final Color iconBg;
  final Widget icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return GestureDetector(
      onTap: onTap,
      child: SectionCard(
        child: SizedBox(
          height: 96,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: icon,
              ),
              const Spacer(),
              Text(title,
                  style: TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600, color: p.onSurface, height: 1.25)),
              const SizedBox(height: 3),
              Text(subtitle, style: TextStyle(fontSize: 11, color: p.muted)),
            ],
          ),
        ),
      ),
    );
  }
}

class _PatientRow extends StatelessWidget {
  const _PatientRow({required this.patient, required this.onTap});
  final SavedPatient patient;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final latest = patient.latest;
    final meta = patientMeta(latest).split(' · ').take(3).join(' · ');
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        child: Row(
          children: [
            InitialsAvatar(initialsOf(patient.name), size: 32),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(patient.name,
                      style: TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w500, color: p.onSurface)),
                  const SizedBox(height: 2),
                  Text(meta,
                      style: TextStyle(fontSize: 11, color: p.muted)),
                ],
              ),
            ),
            StatusChip(patientTag(latest),
                latest?.overall ?? ClinicalStatus.none),
          ],
        ),
      ),
    );
  }
}
