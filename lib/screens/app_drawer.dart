import 'package:flutter/material.dart';
import '../theme.dart';
import '../widgets.dart';
import '../main.dart' show themeModeNotifier;
import '../settings.dart';
import 'common.dart';
import 'about_dialog.dart';
import 'database_status.dart';

/// General application menu drawer, accessible from the home screen and top bars.
class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final topPadding = MediaQuery.of(context).padding.top;

    return Drawer(
      backgroundColor: p.background,
      surfaceTintColor: Colors.transparent,
      child: Column(
        children: [
          // Drawer Header
          Container(
            width: double.infinity,
            color: p.primary,
            padding: EdgeInsets.fromLTRB(18, topPadding + 18, 18, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const SizedBox(height: 48),
                    ValueListenableBuilder<ThemeMode>(
                      valueListenable: themeModeNotifier,
                      builder: (context, mode, _) {
                        final dark = Theme.of(context).brightness == Brightness.dark;
                        return ThemeTogglePill(
                          isDark: dark,
                          onChanged: (newIsDark) {
                            themeModeNotifier.value =
                                newIsDark ? ThemeMode.dark : ThemeMode.light;
                          },
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                const Text(
                  'Anthro Calculator App',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Calculadora de antropometría pediátrica',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.8),
                  ),
                ),
                const SizedBox(height: 12),
                HeaderPill(
                  text: 'v1.0.0 · Datos locales offline',
                  dotColor: const Color(0xFF8CDEBA),
                  textColor: const Color(0xFFD5F2E5),
                  background: const Color(0xFF1F8A5B).withValues(alpha: 0.25),
                  borderColor: const Color(0xFF8CDEBA).withValues(alpha: 0.4),
                ),
              ],
            ),
          ),

          // Drawer Content Items
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              children: [
                // SECTION: CONFIGURACIÓN
                const SectionLabel('Configuración General'),
                const SizedBox(height: 10),

                // UNIDADES DE MEDIDA
                SectionCard(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.straighten_outlined,
                              size: 18, color: p.primary),
                          const SizedBox(width: 8),
                          Text(
                            'Sistema de Unidades',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: p.onSurface,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      ValueListenableBuilder<UnitSystem>(
                        valueListenable: unitSystemNotifier,
                        builder: (context, currentUnit, _) {
                          return SegmentedControl(
                            options: const ['Métrico (kg, cm)', 'Imperial (lb, in)'],
                            selectedIndex: currentUnit == UnitSystem.metric ? 0 : 1,
                            onChanged: (index) {
                              unitSystemNotifier.value = index == 0
                                  ? UnitSystem.metric
                                  : UnitSystem.imperial;
                            },
                          );
                        },
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Aplica para peso, talla y perímetro cefálico.',
                        style: TextStyle(fontSize: 10.5, color: p.muted),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                // ESTÁNDAR DE REFERENCIA
                // SectionCard(
                //   padding: const EdgeInsets.all(12),
                //   child: Column(
                //     crossAxisAlignment: CrossAxisAlignment.start,
                //     children: [
                //       Row(
                //         children: [
                //           Icon(Icons.menu_book_outlined,
                //               size: 18, color: p.primary),
                //           const SizedBox(width: 8),
                //           Text(
                //             'Patrón de Referencia',
                //             style: TextStyle(
                //               fontSize: 13,
                //               fontWeight: FontWeight.w600,
                //               color: p.onSurface,
                //             ),
                //           ),
                //         ],
                //       ),
                //       const SizedBox(height: 10),
                //       ValueListenableBuilder<ReferenceStandard>(
                //         valueListenable: referenceStandardNotifier,
                //         builder: (context, currentStandard, _) {
                //           return SegmentedControl(
                //             options: const ['OMS 2006', 'Res. 2465 Colombia'],
                //             selectedIndex:
                //                 currentStandard == ReferenceStandard.who ? 0 : 1,
                //             onChanged: (index) {
                //               referenceStandardNotifier.value = index == 0
                //                   ? ReferenceStandard.who
                //                   : ReferenceStandard.colombia;
                //             },
                //           );
                //         },
                //       ),
                //       const SizedBox(height: 6),
                //       Text(
                //         'Estándar para tabla de percentiles y Z-scores.',
                //         style: TextStyle(fontSize: 10.5, color: p.muted),
                //       ),
                //     ],
                //   ),
                // ),

                // const SizedBox(height: 18),
                const ThinDivider(),
                const SizedBox(height: 14),

                // SECTION: DATOS Y ALMACENAMIENTO
                const SectionLabel('Datos y almacenamiento'),
                const SizedBox(height: 8),

                _DrawerTile(
                  icon: Icons.storage_rounded,
                  title: 'Base de datos local',
                  subtitle: 'Monitoreo, indicadores y limpieza',
                  onTap: () {
                    final navigator = Navigator.of(context);
                    navigator.pop(); // Close drawer
                    navigator.push(MaterialPageRoute(
                        builder: (_) => const DatabaseStatusScreen()));
                  },
                ),

                const SizedBox(height: 14),
                const ThinDivider(),
                const SizedBox(height: 14),

                // SECTION: ACERCA DE Y SOPORTE
                const SectionLabel('Información'),
                const SizedBox(height: 8),

                _DrawerTile(
                  icon: Icons.info_outline_rounded,
                  title: 'Acerca de Anthro Calculator',
                  subtitle: 'Versión, tablas de referencia y créditos',
                  onTap: () {
                    Navigator.of(context).pop(); // Close drawer
                    showAboutAppDialog(context);
                  },
                ),
              ],
            ),
          ),

          // Footer selpeca
          const ThinDivider(),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 10),
            child: Footer(padding: EdgeInsets.zero),
          ),
        ],
      ),
    );
  }
}

class _DrawerTile extends StatelessWidget {
  const _DrawerTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(Radii.control),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(Radii.control),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
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
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: p.onSurface,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 11,
                          color: p.muted,
                        ),
                      ),
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
