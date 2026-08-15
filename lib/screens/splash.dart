import 'package:flutter/material.dart';
import '../theme.dart';
import '../reference/reference_repository.dart';
import 'home.dart';
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))
      ..forward();
    _boot();
  }

  Future<void> _boot() async {
    // Precarga las tablas de referencia (semilla + almacén local) mientras corre
    // la animación; navega cuando terminan ambas, respetando el tiempo mínimo.
    await Future.wait([
      ReferenceRepository.ensureLoaded(),
      Future<void>.delayed(const Duration(milliseconds: 2100)),
    ]);
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 350),
        pageBuilder: (_, a, _) =>
            FadeTransition(opacity: a, child: const HomeScreen()),
      ),
    );
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final bg = p.isDark ? const Color(0xFF0E1620) : const Color(0xFFF5F4EF);

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(32, 0, 32, 28),
          child: Column(
            children: [
              Expanded(
                child: Center(
                  child: FadeTransition(
                    opacity: _c,
                    child: ScaleTransition(
                      scale: Tween(begin: 0.92, end: 1.0).animate(
                          CurvedAnimation(parent: _c, curve: Curves.easeOut)),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 210,
                            height: 210,
                            decoration: BoxDecoration(
                              color: p.isDark ? const Color(0xFFF7F6F1) : Colors.transparent,
                              borderRadius: BorderRadius.circular(46),
                              boxShadow: p.isDark
                                  ? [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.3),
                                        blurRadius: 20,
                                        offset: const Offset(0, 10),
                                      )
                                    ]
                                  : null,
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: Image.asset(
                              'assets/icon.png',
                              fit: BoxFit.cover,
                            ),
                          ),
                          const SizedBox(height: 24),
                          Text(
                            'Antropometría pediátrica clínica\nOMS · Colombia',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13,
                              height: 1.4,
                              letterSpacing: 0.2,
                              color: p.isDark ? const Color(0xFF93A3B1) : const Color(0xFF5C6B77),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Column(
                children: [
                  SizedBox(
                    width: 132,
                    height: 3,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: LinearProgressIndicator(
                        backgroundColor:
                            p.isDark ? const Color(0xFF24313F) : const Color(0xFFDFE4E2),
                        valueColor: AlwaysStoppedAnimation(
                            p.isDark ? const Color(0xFF4FA3D9) : const Color(0xFF2E6D96)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
                    decoration: BoxDecoration(
                      color: p.isDark
                          ? const Color(0xFF1F8A5B).withValues(alpha: 0.18)
                          : const Color(0xFFEAF2E9),
                      borderRadius: BorderRadius.circular(999),
                      border: p.isDark ? null : Border.all(color: const Color(0xFFCFE3D3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: p.isDark ? const Color(0xFF8CDEBA) : const Color(0xFF1F8A5B),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Listo para trabajar sin conexión',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: p.isDark ? const Color(0xFF8CDEBA) : const Color(0xFF1F6B4C),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text.rich(
                    TextSpan(
                      style: TextStyle(fontSize: 10.5, height: 1.4, color: p.faint),
                      children: [
                        const TextSpan(text: 'v1.0.0 · Desarrollado por '),
                        TextSpan(
                          text: 'selpeca',
                          style: TextStyle(
                            color: p.isDark ? const Color(0xFF4FA3D9) : const Color(0xFF2E6D96),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
