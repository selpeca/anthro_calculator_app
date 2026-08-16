import 'package:flutter/material.dart';
import '../theme.dart';
import '../widgets.dart';
import 'common.dart';

/// Shows the "Acerca de Anthro Calculator App" modal dialog.
void showAboutAppDialog(BuildContext context) {
  showDialog(
    context: context,
    builder: (context) => const AboutAppDialog(),
  );
}

class AboutAppDialog extends StatelessWidget {
  const AboutAppDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Dialog(
      backgroundColor: p.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Radii.sheet),
        side: BorderSide(color: p.border),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 440),
        padding: const EdgeInsets.all(22),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Center(
                child: BrandMark(size: 72),
              ),
              const SizedBox(height: 14),
              Text(
                'Anthro Calculator App',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: p.onSurface,
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: p.primaryTint,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Versión 1.0.0',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: p.primary,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Calculadora educativa de referencia para estimar indicadores antropométricos, Z-scores, percentiles y velocidad de crecimiento en niñas y niños.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12.5,
                  height: 1.45,
                  color: p.muted,
                ),
              ),
              const SizedBox(height: 20),
              const ThinDivider(),
              const SizedBox(height: 16),
              _FeatureTile(
                icon: Icons.biotech_outlined,
                title: 'Tablas de referencia',
                subtitle:
                    'Basado en las tablas de crecimiento OMS (2006) y la Resolución 2465 de 2016 de Colombia.',
              ),
              const SizedBox(height: 12),
              _FeatureTile(
                icon: Icons.wifi_off_outlined,
                title: 'Privacidad y Offline',
                subtitle:
                    'Los cálculos y datos se almacenan exclusivamente en el dispositivo sin envío a servidores.',
              ),
              const SizedBox(height: 12),
              _FeatureTile(
                icon: Icons.health_and_safety_outlined,
                title: 'Clasificación por rangos',
                subtitle:
                    'Clasificación automática por rangos de referencia (Normal, Riesgo, Agudo/Severo).',
              ),
              const SizedBox(height: 20),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: p.isDark ? p.surfaceAlt : const Color(0xFFF7F9FC),
                  borderRadius: BorderRadius.circular(Radii.control),
                  border: Border.all(color: p.borderSoft),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline, size: 16, color: p.faint),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Herramienta educativa y de referencia. No reemplaza el criterio de un profesional.',
                        style: TextStyle(
                          fontSize: 10.5,
                          height: 1.35,
                          color: p.muted,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              const Footer(padding: EdgeInsets.zero),
              const SizedBox(height: 18),
              PrimaryButton(
                'Cerrar',
                onTap: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FeatureTile extends StatelessWidget {
  const _FeatureTile({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 32,
          height: 32,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: p.primaryTint,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 18, color: p.primary),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: p.onSurface,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 11,
                  height: 1.35,
                  color: p.muted,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
