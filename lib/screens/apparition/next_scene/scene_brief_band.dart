import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../ds/tokens.dart';
import '../../../ui/press.dart';
import '../../../ui/text.dart';
import '../../../next_scene/next_scene_finder.dart';

/// The prompt "Let's write" took along, over the chapter it opened, until the
/// author closes it. The desk's `SceneBrief`.
class SceneBriefBand extends StatelessWidget {
  const SceneBriefBand({super.key, required this.brief, required this.onClose});
  final SceneBrief brief;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
        decoration: BoxDecoration(
          color: Ds.panel,
          border: Border.all(color: Ds.edge),
          borderRadius: BorderRadius.circular(DsGeom.radius),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Eyebrow(brief.headline, color: Ds.low),
                  const SizedBox(height: 4),
                  Text(brief.prompt, style: DsStyle.prose(DsText.ui, color: Ds.mid)),
                ],
              ),
            ),
            Press(
              onPressed: onClose,
              semanticLabel: 'Close the prompt',
              hitSlop: 12,
              builder: (context, pressed) => Padding(
                padding: const EdgeInsets.all(4),
                child: Icon(LucideIcons.x, size: 15, color: pressed ? Ds.soft : Ds.faint),
              ),
            ),
          ],
        ),
      );
}
