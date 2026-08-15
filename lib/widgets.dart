import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'theme.dart';

/// A drawn brand mark (the original PNG logo could not be retrieved intact via
/// the design API, so this vector stand-in carries the app identity: a growth
/// curve rising through a measured child figure, in the brand blue).
class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.size = 96, this.onCream = true});

  final double size;
  final bool onCream;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: onCream ? const Color(0xFFF7F6F1) : Colors.transparent,
        borderRadius: BorderRadius.circular(size * 0.22),
      ),
      child: CustomPaint(painter: _BrandPainter()),
    );
  }
}

class _BrandPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    const blue = Color(0xFF1E5F8C);
    const blueLight = Color(0xFF4FA3D9);

    // Rising growth curve.
    final curve = Paint()
      ..color = blue
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.055
      ..strokeCap = StrokeCap.round;
    final path = Path()
      ..moveTo(w * 0.18, h * 0.78)
      ..cubicTo(w * 0.38, h * 0.74, w * 0.5, h * 0.55, w * 0.82, h * 0.24);
    canvas.drawPath(path, curve);

    // Data dots on the curve.
    final dot = Paint()..color = blueLight;
    canvas.drawCircle(Offset(w * 0.18, h * 0.78), w * 0.045, dot);
    canvas.drawCircle(Offset(w * 0.5, h * 0.55), w * 0.045, dot);
    final endDot = Paint()..color = blue;
    canvas.drawCircle(Offset(w * 0.82, h * 0.24), w * 0.07, endDot);
    canvas.drawCircle(
        Offset(w * 0.82, h * 0.24), w * 0.03, Paint()..color = const Color(0xFFF7F6F1));

    // Measuring ticks along the left axis.
    final tick = Paint()
      ..color = blue.withValues(alpha: 0.35)
      ..strokeWidth = w * 0.02
      ..strokeCap = StrokeCap.round;
    for (int i = 0; i < 5; i++) {
      final y = h * (0.24 + i * 0.135);
      canvas.drawLine(Offset(w * 0.12, y), Offset(w * 0.17, y), tick);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// The standard card surface used across screens (radius 12, 1px border, soft
/// shadow).
class SectionCard extends StatelessWidget {
  const SectionCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(14),
    this.borderColor,
    this.leftAccent,
    this.background,
  });

  final Widget child;
  final EdgeInsets padding;
  final Color? borderColor;
  final Color? leftAccent;
  final Color? background;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Container(
      decoration: BoxDecoration(
        color: background ?? p.surface,
        borderRadius: BorderRadius.circular(Radii.card),
        border: Border.all(color: borderColor ?? p.border),
        boxShadow: p.isDark
            ? null
            : const [
                BoxShadow(
                  color: Color(0x0F0F1B24),
                  blurRadius: 2,
                  offset: Offset(0, 1),
                )
              ],
      ),
      child: leftAccent == null
          ? Padding(padding: padding, child: child)
          : Container(
              decoration: BoxDecoration(
                border: Border(left: BorderSide(color: leftAccent!, width: 3)),
                borderRadius: BorderRadius.circular(Radii.card),
              ),
              child: Padding(padding: padding, child: child),
            ),
    );
  }
}

/// Uppercase section label (labelSmall · +0.7 tracking).
class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key, this.color});
  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Text(
      text.toUpperCase(),
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.7,
        color: color ?? p.muted,
      ),
    );
  }
}

/// Pill status chip (Normal / Riesgo / Severo).
class StatusChip extends StatelessWidget {
  const StatusChip(this.text, this.status, {super.key});
  final String text;
  final ClinicalStatus status;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: p.statusBg(status),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: p.statusText(status),
        ),
      ),
    );
  }
}

/// Rounded segmented control (used for OMS/Colombia, sex, position…).
class SegmentedControl extends StatelessWidget {
  const SegmentedControl({
    super.key,
    required this.options,
    required this.selectedIndex,
    required this.onChanged,
  });

  final List<String> options;
  final int selectedIndex;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: p.segmentBg,
        borderRadius: BorderRadius.circular(Radii.control),
      ),
      child: Row(
        children: [
          for (int i = 0; i < options.length; i++)
            Expanded(
              child: GestureDetector(
                onTap: () => onChanged(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: i == selectedIndex ? p.primary : Colors.transparent,
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: Text(
                    options[i],
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: i == selectedIndex
                          ? (p.isDark ? p.background : Colors.white)
                          : p.muted,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Filled primary button matching the design's "Calcular" style.
class PrimaryButton extends StatelessWidget {
  const PrimaryButton(this.label,
      {super.key, this.onTap, this.expand = true, this.enabled = true});
  final String label;
  final VoidCallback? onTap;
  final bool expand;

  /// Cuando es `false`, se atenúa, pierde la sombra e ignora el toque.
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final btn = GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 18),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: enabled ? p.primary : p.primary.withValues(alpha: 0.38),
          borderRadius: BorderRadius.circular(Radii.control),
          boxShadow: enabled
              ? [
                  BoxShadow(
                    color: p.primary.withValues(alpha: 0.28),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  )
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: p.isDark ? p.background : Colors.white,
          ),
        ),
      ),
    );
    return expand ? SizedBox(width: double.infinity, child: btn) : btn;
  }
}

/// Outlined secondary button.
class SecondaryButton extends StatelessWidget {
  const SecondaryButton(this.label, {super.key, this.onTap});
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: p.isDark ? Colors.transparent : p.surface,
          borderRadius: BorderRadius.circular(Radii.control),
          border: Border.all(
              color: p.isDark ? p.border : const Color(0xFFCFE2EF), width: 1.5),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: p.primary,
          ),
        ),
      ),
    );
  }
}

/// A small circular avatar with initials.
class InitialsAvatar extends StatelessWidget {
  const InitialsAvatar(this.initials,
      {super.key, this.size = 32, this.bg, this.fg});
  final String initials;
  final double size;
  final Color? bg;
  final Color? fg;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: bg ?? (p.isDark ? p.primaryTint : const Color(0xFFEEF3F7)),
        shape: BoxShape.circle,
      ),
      child: Text(
        initials,
        style: TextStyle(
          fontSize: size * 0.36,
          fontWeight: FontWeight.w600,
          color: fg ?? p.primary,
        ),
      ),
    );
  }
}

/// A percentile bar with a dot marker, colored by status.
class PercentileBar extends StatelessWidget {
  const PercentileBar({super.key, required this.percentile, required this.color});
  final int percentile;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return LayoutBuilder(builder: (context, c) {
      final frac = (percentile.clamp(0, 100)) / 100.0;
      return SizedBox(
        height: 11,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              left: 0,
              right: 0,
              top: 3,
              child: Container(
                height: 5,
                decoration: BoxDecoration(
                  color: p.isDark ? p.border : const Color(0xFFE7ECF0),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
            Positioned(
              left: (c.maxWidth - 11) * frac,
              top: 0,
              child: Container(
                width: 11,
                height: 11,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  border: Border.all(color: p.surface, width: 2),
                ),
              ),
            ),
          ],
        ),
      );
    });
  }
}

/// Simple offline / reference pill used in headers.
class HeaderPill extends StatelessWidget {
  const HeaderPill({
    super.key,
    required this.text,
    this.dotColor,
    this.textColor,
    this.background,
    this.borderColor,
  });

  final String text;
  final Color? dotColor;
  final Color? textColor;
  final Color? background;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: background ?? Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: borderColor != null ? Border.all(color: borderColor!) : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (dotColor != null) ...[
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
          ],
          Text(
            text,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: textColor ?? Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

/// Rotating chevron used on expandable rows.
class Chevron extends StatelessWidget {
  const Chevron({super.key, required this.expanded});
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return AnimatedRotation(
      turns: expanded ? 0.5 : 0,
      duration: const Duration(milliseconds: 180),
      child: Icon(Icons.keyboard_arrow_down_rounded, color: p.primary, size: 22),
    );
  }
}

/// Small helper to build a "measurement chip" (value + unit) as used on the
/// design system card.
class MetricBox extends StatelessWidget {
  const MetricBox({
    super.key,
    required this.label,
    required this.value,
    required this.unit,
    this.status = ClinicalStatus.none,
    this.dashed = false,
  });

  final String label;
  final String value;
  final String unit;
  final ClinicalStatus status;
  final bool dashed;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final colored = status != ClinicalStatus.none;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        color: colored ? p.statusBg(status) : (p.isDark ? p.surfaceAlt : const Color(0xFFF7F9FB)),
        borderRadius: BorderRadius.circular(Radii.control),
        border: Border.all(
          color: colored ? p.statusColor(status) : p.border,
          width: colored ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionLabel(label, color: colored ? p.statusText(status) : p.muted),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Expanded(
                child: Text(
                  value,
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w700,
                    fontFeatures: kTabular,
                    color: colored ? p.statusText(status) : p.onSurface,
                  ),
                ),
              ),
              Text(
                unit,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: colored ? p.statusText(status) : p.muted,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Draws a subtle dashed-ish separator used sparingly.
class ThinDivider extends StatelessWidget {
  const ThinDivider({super.key});
  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Container(height: 1, color: p.borderSoft);
  }
}

double degToRad(double deg) => deg * math.pi / 180.0;

/// A premium interactive sliding pill toggle for switching between Light and Dark mode.
class ThemeTogglePill extends StatefulWidget {
  const ThemeTogglePill({
    super.key,
    required this.isDark,
    required this.onChanged,
  });

  final bool isDark;
  final ValueChanged<bool> onChanged;

  @override
  State<ThemeTogglePill> createState() => _ThemeTogglePillState();
}

class _ThemeTogglePillState extends State<ThemeTogglePill> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;

    return Tooltip(
      message: isDark ? 'Cambiar a modo claro' : 'Cambiar a modo oscuro',
      child: Semantics(
        button: true,
        label: isDark
            ? 'Modo oscuro activo. Toca para cambiar a modo claro'
            : 'Modo claro activo. Toca para cambiar a modo oscuro',
        child: GestureDetector(
          onTapDown: (_) => setState(() => _isPressed = true),
          onTapUp: (_) => setState(() => _isPressed = false),
          onTapCancel: () => setState(() => _isPressed = false),
          onTap: () => widget.onChanged(!isDark),
          behavior: HitTestBehavior.opaque,
          child: AnimatedScale(
            scale: _isPressed ? 0.94 : 1.0,
            duration: const Duration(milliseconds: 120),
            curve: Curves.easeOutCubic,
            child: Container(
              width: 66,
              height: 32,
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.22),
                border: Border.all(
                  color: Colors.white.withValues(alpha: isDark ? 0.30 : 0.25),
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Static/Background Icons layer
                  Row(
                    children: [
                      Expanded(
                        child: Center(
                          child: Icon(
                            Icons.wb_sunny_rounded,
                            size: 15,
                            color: Colors.white.withValues(alpha: isDark ? 0.5 : 0.0),
                          ),
                        ),
                      ),
                      Expanded(
                        child: Center(
                          child: Icon(
                            Icons.nightlight_round,
                            size: 14,
                            color: Colors.white.withValues(alpha: isDark ? 0.0 : 0.55),
                          ),
                        ),
                      ),
                    ],
                  ),
                  // Animated sliding thumb containing active icon
                  AnimatedAlign(
                    duration: const Duration(milliseconds: 260),
                    curve: Curves.easeInOutCubic,
                    alignment: isDark ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isDark ? const Color(0xFF1E293B) : Colors.white,
                        boxShadow: [
                          BoxShadow(
                            color: isDark
                                ? const Color(0xFF38BDF8).withValues(alpha: 0.45)
                                : const Color(0xFFF59E0B).withValues(alpha: 0.5),
                            blurRadius: 8,
                            spreadRadius: 1,
                          ),
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.2),
                            blurRadius: 3,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                      child: Center(
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 200),
                          transitionBuilder: (child, anim) => ScaleTransition(
                            scale: anim,
                            child: FadeTransition(opacity: anim, child: child),
                          ),
                          child: isDark
                              ? const Icon(
                                  Icons.nightlight_round,
                                  key: ValueKey('moon_active'),
                                  size: 14,
                                  color: Color(0xFF38BDF8),
                                )
                              : const Icon(
                                  Icons.wb_sunny_rounded,
                                  key: ValueKey('sun_active'),
                                  size: 15,
                                  color: Color(0xFFD97706),
                                ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

