import 'dart:async';

import 'package:flutter/material.dart';
import '../db/database.dart';
import '../db/models.dart';
import '../theme.dart';
import '../widgets.dart';
import 'package:url_launcher/link.dart';
import 'patient_format.dart';

/// Resultado del diálogo de nombre de paciente: el nombre y, si el usuario
/// eligió un paciente existente (con historial), su id para asociar la
/// medición. Si [patientId] es `null` se crea una ficha nueva por nombre.
class PatientNameResult {
  const PatientNameResult({required this.name, this.patientId});

  final String name;
  final int? patientId;
}

/// Solicita el nombre del paciente con el que se guardará la medición y, al
/// escribir, sugiere pacientes existentes para asociar el registro.
///
/// Devuelve el nombre sin espacios exteriores, o `null` si se cancela.
Future<PatientNameResult?> promptPatientName(BuildContext context,
    {String? initialName}) {
  return showDialog<PatientNameResult>(
    context: context,
    builder: (_) => _PatientNameDialog(initialName: initialName),
  );
}

class _PatientNameDialog extends StatefulWidget {
  const _PatientNameDialog({this.initialName});

  final String? initialName;

  @override
  State<_PatientNameDialog> createState() => _PatientNameDialogState();
}

class _PatientNameDialogState extends State<_PatientNameDialog> {
  static const _debounceDuration = Duration(milliseconds: 250);
  static const _maxSuggestions = 3;

  late final TextEditingController _controller;
  Timer? _debounce;
  List<SavedPatient> _suggestions = const [];
  bool _searching = false;
  SavedPatient? _selected;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialName ?? '');
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    setState(() {
      _selected = null;
      if (value.trim().isEmpty) {
        _suggestions = const [];
        _searching = false;
        return;
      }
      _searching = true;
    });
    _debounce = Timer(_debounceDuration, _search);
  }

  Future<void> _search() async {
    final query = _controller.text;
    if (!mounted || query.trim().isEmpty) return;
    final result = await AnthroDatabase.instance.searchPatients(query);
    if (!mounted || _controller.text != query) return;
    setState(() {
      _suggestions = result.take(_maxSuggestions).toList();
      _searching = false;
    });
  }

  void _select(SavedPatient patient) {
    _debounce?.cancel();
    setState(() {
      _selected = patient;
      _suggestions = const [];
      _searching = false;
      _controller.text = patient.name;
      _controller.selection =
          TextSelection.collapsed(offset: patient.name.length);
    });
  }

  void _submit() {
    final name = _controller.text.trim();
    if (name.isEmpty) return;
    Navigator.of(context).pop(
      PatientNameResult(name: name, patientId: _selected?.id),
    );
  }

  Widget _suggestionRow(SavedPatient p) {
    final palette = AppPalette.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _select(p),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(p.name,
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: palette.onSurface)),
                    const SizedBox(height: 1),
                    Text(
                      '${p.measurementCount} '
                      '${p.measurementCount == 1 ? 'medición' : 'mediciones'}',
                      style: TextStyle(fontSize: 11, color: palette.muted),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: palette.surfaceAlt,
                  borderRadius: BorderRadius.circular(Radii.chip),
                  border: Border.all(color: palette.border, width: 0.5),
                ),
                child: Text(
                  patientTag(p.latest),
                  style: TextStyle(fontSize: 10, color: palette.muted),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final hasName = _controller.text.trim().isNotEmpty;
    final noMatches =
        hasName && !_searching && _suggestions.isEmpty && _selected == null;
    return Dialog(
      backgroundColor: p.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Radii.sheet),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Guardar medición',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: p.onSurface)),
              const SizedBox(height: 4),
              Text('¿Con qué paciente se guarda esta medición?',
                  style: TextStyle(fontSize: 12, height: 1.35, color: p.muted)),
              const SizedBox(height: 14),
              TextField(
                controller: _controller,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                onChanged: _onChanged,
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
              if (_searching)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: SizedBox(
                    height: 14,
                    child: Center(
                      child: SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: p.primary),
                      ),
                    ),
                  ),
                ),
              if (_suggestions.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Container(
                    decoration: BoxDecoration(
                      color: p.surfaceAlt,
                      borderRadius: BorderRadius.circular(Radii.control),
                      border: Border.all(color: p.border),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [for (final s in _suggestions) _suggestionRow(s)],
                    ),
                  ),
                ),
              if (noMatches)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 9),
                    decoration: BoxDecoration(
                      color: p.surfaceAlt,
                      borderRadius: BorderRadius.circular(Radii.control),
                      border: Border.all(color: p.border),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.person_add_alt_1_outlined,
                            size: 15, color: p.muted),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Paciente nuevo: se creará su ficha',
                            style: TextStyle(fontSize: 12, color: p.muted),
                          ),
                        ),
                      ],
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
