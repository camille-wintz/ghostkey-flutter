import 'package:flutter/material.dart';

import '../../ds/tokens.dart';
import '../../ui/button.dart';

/// The "no bible yet" state: one button and one sentence about what it
/// reads. Disabled with a hint when the book has no chapters — the outline
/// the extraction reads is made from them.
class VeilGenerateCallout extends StatelessWidget {
  const VeilGenerateCallout({
    super.key,
    required this.hasChapters,
    required this.running,
    required this.onGenerate,
  });

  final bool hasChapters;
  final bool running;
  final VoidCallback onGenerate;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Ds.surf,
          border: Border.all(color: Ds.edge),
          borderRadius: BorderRadius.circular(DsGeom.radius),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Generate from the story outline',
              style: DsStyle.ui(DsText.body, color: Ds.hi, weight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            Text(
              hasChapters
                  ? 'GhostKey reads your story outline for the characters, places and terms the manuscript has committed to, and keeps what you add by hand.'
                  : 'Write a chapter first — the bible is read from the story outline of what you have written.',
              style: DsStyle.ui(DsText.ui, color: Ds.mid),
            ),
            const SizedBox(height: 14),
            GkButton(
              label: 'Generate',
              onPressed: onGenerate,
              disabled: !hasChapters,
              busy: running,
            ),
          ],
        ),
      );
}
