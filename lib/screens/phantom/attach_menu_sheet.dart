import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../ds/tokens.dart';
import '../../ui/press.dart';
import '../../ui/sheet.dart';

/// What the composer's paperclip can attach.
enum AttachChoice { chapter, file }

/// Two rows: a chapter of the manuscript, or a file from the phone (.docx,
/// .pdf, text). Resolves with the choice, or null when dismissed.
Future<AttachChoice?> showAttachMenuSheet(BuildContext context) => showGkSheet<AttachChoice>(
      context,
      header: SheetHeader(eyebrow: 'Attach', onClose: () => Navigator.of(context).pop()),
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _Row(
            icon: LucideIcons.fileText,
            title: 'A chapter',
            hint: 'From the manuscript',
            onPressed: () => Navigator.of(context).pop(AttachChoice.chapter),
          ),
          _Row(
            icon: LucideIcons.fileUp,
            title: 'A file',
            hint: 'A .docx, a .pdf or a text file — it joins the library too',
            onPressed: () => Navigator.of(context).pop(AttachChoice.file),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );

class _Row extends StatelessWidget {
  const _Row({required this.icon, required this.title, required this.hint, required this.onPressed});
  final IconData icon;
  final String title;
  final String hint;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Press(
        onPressed: onPressed,
        semanticLabel: title,
        builder: (context, pressed) => Container(
          height: 56,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          color: pressed ? Ds.raise : const Color(0x00000000),
          child: Row(
            children: [
              Icon(icon, size: 18, color: Ds.accent),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: DsStyle.ui(DsText.ui, color: Ds.hi)),
                    Text(hint, maxLines: 1, overflow: TextOverflow.ellipsis, style: DsStyle.ui(DsText.eyebrow, color: Ds.mid)),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
}
