import 'package:flutter/material.dart';
import '../theme.dart';
import '../widgets.dart';
import 'package:url_launcher/link.dart';

/// Solicita el nombre del paciente con el que se guardará la medición.
///
/// Devuelve el nombre sin espacios exteriores, o `null` si se cancela.
Future<String?> promptPatientName(BuildContext context) {
  return showDialog<String>(
    context: context,
    builder: (_) => const _PatientNameDialog(),
  );
}

class _PatientNameDialog extends StatefulWidget {
  const _PatientNameDialog();

  @override
  State<_PatientNameDialog> createState() => _PatientNameDialogState();
}

class _PatientNameDialogState extends State<_PatientNameDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _controller.text.trim();
    if (name.isEmpty) return;
    Navigator.of(context).pop(name);
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final hasName = _controller.text.trim().isNotEmpty;
    return Dialog(
      backgroundColor: p.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Radii.sheet),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Guardar medición',
                style: TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w700, color: p.onSurface)),
            const SizedBox(height: 4),
            Text('¿Con qué paciente se guarda esta medición?',
                style: TextStyle(fontSize: 12, height: 1.35, color: p.muted)),
            const SizedBox(height: 14),
            TextField(
              controller: _controller,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              onChanged: (_) => setState(() {}),
              onSubmitted: (_) => _submit(),
              style: TextStyle(fontSize: 14, color: p.onSurface),
              cursorColor: p.primary,
              decoration: InputDecoration(
                isDense: true,
                filled: true,
                fillColor: p.surfaceAlt,
                hintText: 'Nombre del paciente',
                hintStyle: TextStyle(fontSize: 13, color: p.faint),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(Radii.control),
                  borderSide: BorderSide(color: p.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(Radii.control),
                  borderSide: BorderSide(color: p.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(Radii.control),
                  borderSide: BorderSide(color: p.primary, width: 1.5),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: SecondaryButton('Cancelar',
                      onTap: () => Navigator.of(context).pop()),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: PrimaryButton('Guardar',
                      enabled: hasName, onTap: hasName ? _submit : null),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// "Desarrollado por selpeca" credit shown at the foot of most screens.
class Footer extends StatelessWidget {
  const Footer({super.key, this.padding = const EdgeInsets.fromLTRB(16, 18, 16, 8)});
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Padding(
      padding: padding,
      child: Center(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Desarrollado por ',
              style: TextStyle(fontSize: 10.5, height: 1.4, color: p.faint),
            ),
            Link(
              uri: Uri.parse('https://www.linkedin.com/in/selpeca/'),
              target: LinkTarget.blank,
              builder: (context, followLink) {
                return InkWell(
                  onTap: followLink,
                  child: Text(
                    'selpeca',
                    style: TextStyle(
                      fontSize: 10.5,
                      height: 1.4,
                      color: p.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// A flat back/title app bar matching the design's screen headers.
class ScreenHeader extends StatelessWidget implements PreferredSizeWidget {
  const ScreenHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
    this.statusDot,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;
  final Color? statusDot;

  @override
  Size get preferredSize => Size.fromHeight(subtitle == null ? 56 : 64);

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Container(
      color: p.surface,
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top,
      ),
      child: Container(
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: p.border)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        child: Row(
          children: [
            IconButton(
              onPressed: () => Navigator.of(context).maybePop(),
              icon: Icon(Icons.arrow_back, color: p.primary, size: 22),
              splashRadius: 22,
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: p.onSurface,
                    ),
                  ),
                  if (subtitle != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        subtitle!,
                        style: TextStyle(fontSize: 11, color: p.muted),
                      ),
                    ),
                ],
              ),
            ),
            if (statusDot != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(color: statusDot, shape: BoxShape.circle),
                ),
              ),
            if (trailing != null) Padding(padding: const EdgeInsets.only(right: 8), child: trailing!),
          ],
        ),
      ),
    );
  }
}
