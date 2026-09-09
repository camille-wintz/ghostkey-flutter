import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../ds/tokens.dart';
import '../../../poltergeist/numbers.dart';
import '../../../server/dto/projects.dart';
import '../../../ui/press.dart';
import 'plan_folder_summary.dart';

/// One folder of the manuscript, as a section of the ledger you can shut.
/// The header carries the whole section's outstanding work, so closing a
/// folder puts its chapters away without hiding what they owe.
class PlanFolderHeader extends StatelessWidget {
  const PlanFolderHeader({super.key, required this.name, required this.rows, required this.open, required this.onToggle});
  final String name;
  final List<PlanChapter> rows;
  final bool open;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) => Press(
        onPressed: onToggle,
        semanticLabel: '${open ? 'Collapse' : 'Expand'} $name',
        builder: (context, pressed) => Container(
          margin: const EdgeInsets.only(top: 10),
          padding: const EdgeInsets.fromLTRB(12, 10, 14, 10),
          decoration: BoxDecoration(
            color: pressed ? Ds.accentMix(4) : Ds.panel.withValues(alpha: 0.6),
            border: Border.all(color: Ds.accentMix(12)),
            borderRadius: open
                ? const BorderRadius.vertical(top: Radius.circular(DsGeom.radius))
                : BorderRadius.circular(DsGeom.radius),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  AnimatedRotation(
                    turns: open ? 0.25 : 0,
                    duration: DsMotion.duration,
                    child: Icon(LucideIcons.chevronRight, size: 12, color: Ds.accent),
                  ),
                  const SizedBox(width: 10),
                  Icon(LucideIcons.folder, size: 13, color: Ds.accentMix(50)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      name.toUpperCase(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: DsStyle.eyebrow(color: Ds.hi, weight: FontWeight.w600),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    plural(rows.length, 'chapter'),
                    style: DsStyle.ui(DsText.eyebrow, color: Ds.low).copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
                  ),
                ],
              ),
              if (rows.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8, left: 22),
                  child: PlanFolderSummary(rows: rows),
                ),
            ],
          ),
        ),
      );
}
