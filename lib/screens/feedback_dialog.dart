import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme.dart';
import '../widgets.dart';

/// Tipo de comentario capturado por el formulario de soporte.
enum FeedbackType { bug, feature }

/// Correo al que se envían los informes usando el cliente de correo del
/// dispositivo.
const _supportEmail = 'ser.per.eli@gmail.com';

/// Muestra el modal interactivo para reportar un error o sugerir una función.
///
/// Al confirmar, abre el cliente de correo del dispositivo con un mensaje
/// prellenado dirigido a [_supportEmail].
Future<void> showFeedbackDialog(BuildContext context,
    {required FeedbackType type}) {
  return showDialog<void>(
    context: context,
    builder: (_) => FeedbackDialog(type: type),
  );
}

class FeedbackDialog extends StatefulWidget {
  const FeedbackDialog({super.key, required this.type});

  final FeedbackType type;

  @override
  State<FeedbackDialog> createState() => _FeedbackDialogState();
}

class _FeedbackDialogState extends State<FeedbackDialog> {
  final _descriptionController = TextEditingController();
  final _emailController = TextEditingController();

  bool get _isBug => widget.type == FeedbackType.bug;

  String get _title => _isBug ? 'Reportar un error' : 'Sugerir una función';

  bool get _canSubmit => _descriptionController.text.trim().isNotEmpty;

  @override
  void dispose() {
    _descriptionController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  /// Compone el mensaje y abre el cliente de correo con un `mailto:` dirigido
  /// a [_supportEmail]. Cierra el modal solo si el envío fue posible.
  Future<void> _submit() async {
    final description = _descriptionController.text.trim();
    final email = _emailController.text.trim();
    if (description.isEmpty) return;

    final subject = _isBug
        ? '[Anthro Calculator] Reporte de error'
        : '[Anthro Calculator] Sugerencia de función';
    final body = _isBug
        ? [
            'Hola, te escribo desde Anthro Calculator App para reportar un '
                'error.',
            '',
            'Aplicación: Anthro Calculator App · Versión 1.0.0 · Edición '
                'Clínica',
            'Fecha del reporte: ${_formatDate(DateTime.now())}',
            '',
            'DESCRIPCIÓN DEL PROBLEMA',
            description,
            if (email.isNotEmpty) ...[
              '',
              'CONTACTO DE RESPUESTA',
              email,
            ],
            '',
            'Gracias por ayudarme a mejorar la app.',
          ].join('\n')
        : [
            'Hola, te escribo desde Anthro Calculator App para proponer una '
                'nueva función.',
            '',
            'Aplicación: Anthro Calculator App · Versión 1.0.0 · Edición '
                'Clínica',
            'Fecha: ${_formatDate(DateTime.now())}',
            '',
            'DESCRIPCIÓN DE LA FUNCIÓN',
            description,
            if (email.isNotEmpty) ...[
              '',
              'CONTACTO DE RESPUESTA',
              email,
            ],
            '',
            'Gracias por ayudarme a mejorar la app.',
          ].join('\n');

    // Se codifica con %20 (no con `+`) para que los espacios lleguen como
    // espacios reales en el cliente de correo.
    final uri = Uri.parse(
      'mailto:$_supportEmail'
      '?subject=${Uri.encodeComponent(subject)}'
      '&body=${Uri.encodeComponent(body)}',
    );

    final launched =
        await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!mounted) return;
    if (launched) {
      Navigator.of(context).pop();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text('No se pudo abrir el cliente de correo. Inténtalo de nuevo.'),
        ),
      );
    }
  }

  static const _months = [
    'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio',
    'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre',
  ];

  static String _formatDate(DateTime d) =>
      '${d.day} de ${_months[d.month - 1]} de ${d.year}';

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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: p.primaryTint,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      _isBug
                          ? Icons.bug_report_outlined
                          : Icons.lightbulb_outline_rounded,
                      size: 20,
                      color: p.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _title,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: p.onSurface,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _isBug
                              ? 'Cuéntanos qué pasó para poder corregirlo.'
                              : 'Describe la función que te gustaría tener.',
                          style: TextStyle(
                            fontSize: 12,
                            height: 1.35,
                            color: p.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _descriptionController,
                autofocus: true,
                minLines: 4,
                maxLines: 6,
                textCapitalization: TextCapitalization.sentences,
                onChanged: (_) => setState(() {}),
                style: TextStyle(fontSize: 13.5, color: p.onSurface),
                cursorColor: p.primary,
                decoration: InputDecoration(
                  isDense: true,
                  filled: true,
                  fillColor: p.surfaceAlt,
                  hintText: _isBug
                      ? 'Describe el error: qué hacías, qué esperabas y qué ocurrió.'
                      : 'Describe la función y el caso de uso que cubriría.',
                  hintStyle: TextStyle(fontSize: 12, color: p.faint),
                  contentPadding: const EdgeInsets.all(12),
                  alignLabelWithHint: true,
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
              const SizedBox(height: 12),
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                autocorrect: false,
                style: TextStyle(fontSize: 13.5, color: p.onSurface),
                cursorColor: p.primary,
                decoration: InputDecoration(
                  isDense: true,
                  filled: true,
                  fillColor: p.surfaceAlt,
                  hintText: 'Correo de contacto (opcional)',
                  hintStyle: TextStyle(fontSize: 12, color: p.faint),
                  prefixIcon: Icon(Icons.alternate_email_rounded,
                      size: 18, color: p.faint),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 12),
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
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(11),
                decoration: BoxDecoration(
                  color: p.isDark ? p.surfaceAlt : const Color(0xFFF7F9FC),
                  borderRadius: BorderRadius.circular(Radii.control),
                  border: Border.all(color: p.borderSoft),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.mail_outline_rounded, size: 16, color: p.faint),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Al enviar se abrirá tu aplicación de correo con un '
                        'mensaje dirigido a $_supportEmail.',
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
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: SecondaryButton('Cancelar',
                        onTap: () => Navigator.of(context).pop()),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: PrimaryButton('Enviar por correo',
                        enabled: _canSubmit,
                        onTap: _canSubmit ? _submit : null),
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