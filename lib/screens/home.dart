import 'package:flutter/material.dart';
import '../theme.dart';
import '../data.dart';
import '../widgets.dart';
import '../main.dart' show themeModeNotifier;
import 'common.dart';
import 'calculator.dart';
import 'velocity.dart';
import 'patients.dart';
import 'patient_detail.dart';

/// Home / dashboard (design 1b): branded header, quick action, module grid and
/// a preview of the patient database.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  void _open(BuildContext context, Widget screen) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Scaffold(
      backgroundColor: p.background,
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
                        Text('342 registros',
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: p.primary)),
                      ],
                    ),
                  ),
                  const ThinDivider(),
                  for (final patient in kSamplePatients.take(2))
                    _PatientRow(patient: patient, onTap: () => _open(context, PatientDetailScreen(patient: patient))),
                  const ThinDivider(),
                  InkWell(
                    onTap: () => _open(context, const PatientsScreen()),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Center(
                        child: Text('Ver los 342 registros',
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

  static Widget _boxIcon(Color color) => Container(
        width: 14,
        height: 14,
        decoration: BoxDecoration(
          border: Border.all(color: color, width: 2),
          borderRadius: BorderRadius.circular(3),
        ),
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
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Anthro Calculator App',
                          style: TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            letterSpacing: -0.3,
                          )),
                      const SizedBox(height: 3),
                      Text('Antropometría pediátrica clínica',
                          style: TextStyle(
                              fontSize: 12, color: Colors.white.withValues(alpha: 0.75))),
                    ],
                  ),
                ),
                ValueListenableBuilder<ThemeMode>(
                  valueListenable: themeModeNotifier,
                  builder: (context, mode, _) {
                    final dark = Theme.of(context).brightness == Brightness.dark;
                    return IconButton(
                      onPressed: () => themeModeNotifier.value =
                          dark ? ThemeMode.light : ThemeMode.dark,
                      icon: Icon(dark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
                          color: Colors.white, size: 20),
                      splashRadius: 20,
                    );
                  },
                ),
                Container(
                  width: 36,
                  height: 36,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text('GR',
                      style: TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white)),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                HeaderPill(
                  text: 'Offline · datos locales',
                  dotColor: const Color(0xFF8CDEBA),
                  textColor: const Color(0xFFD5F2E5),
                  background: const Color(0xFF1F8A5B).withValues(alpha: 0.22),
                  borderColor: const Color(0xFF8CDEBA).withValues(alpha: 0.45),
                ),
                const SizedBox(width: 8),
                HeaderPill(
                  text: 'Ref. OMS 2006/2007',
                  textColor: const Color(0xFFDCEBF5),
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
  final Patient patient;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        child: Row(
          children: [
            InitialsAvatar(patient.initials, size: 32),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(patient.name,
                      style: TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w500, color: p.onSurface)),
                  const SizedBox(height: 2),
                  Text(patient.meta.split(' · ').take(3).join(' · '),
                      style: TextStyle(fontSize: 11, color: p.muted)),
                ],
              ),
            ),
            StatusChip(patient.tag, patient.status),
          ],
        ),
      ),
    );
  }
}
