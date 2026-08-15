import 'package:flutter/material.dart';
import '../theme.dart';
import 'package:url_launcher/link.dart';

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
