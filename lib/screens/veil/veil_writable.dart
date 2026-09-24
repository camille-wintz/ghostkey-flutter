import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../ds/tokens.dart';
import '../../ui/press.dart';

/// One of the author's fields on a card, as the page shows it: their words,
/// or — when they have written none — the dossier's in a fainter hand, or
/// an invitation. Tapping opens the field's sheet.
class VeilWritable extends StatelessWidget {
  const VeilWritable({
    super.key,
    required this.text,
    required this.placeholder,
    required this.onTap,
    required this.semanticLabel,
    this.suggested = false,
    this.prose = true,
  });

  final String text;
  final String placeholder;
  final VoidCallback onTap;
  final String semanticLabel;

  /// [text] is the dossier's, not the author's.
  final bool suggested;

  /// The manuscript's face for long answers, the app's for short cells.
  final bool prose;

  @override
  Widget build(BuildContext context) {
    final empty = text.trim().isEmpty;
    final color = empty ? Ds.faint : (suggested ? Ds.low : Ds.ink);
    final style = prose ? DsStyle.prose(DsText.body, color: color) : DsStyle.ui(DsText.body, color: color);
    return Press(
      onPressed: onTap,
      semanticLabel: semanticLabel,
      builder: (context, pressed) => Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
        decoration: BoxDecoration(
          color: pressed ? Ds.veil : Ds.surf,
          border: Border.all(color: Ds.edge),
          borderRadius: BorderRadius.circular(DsGeom.radius),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: Text(empty ? placeholder : text.trim(), style: style)),
            const SizedBox(width: 8),
            Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Icon(LucideIcons.pencil, size: 13, color: Ds.faint),
            ),
          ],
        ),
      ),
    );
  }
}
