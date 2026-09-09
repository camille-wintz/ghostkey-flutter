import 'package:flutter/material.dart';

import '../../../core/plan_markers.dart';
import '../../../ds/tokens.dart';
import '../../../poltergeist/plan_rules.dart';
import '../../../server/dto/projects.dart';

/// What a section owes and what it has settled, on the folder's own line —
/// so a shut folder is still legible. A single work bar: the track is every
/// chapter in the folder, one segment per action owed, sized by how many
/// chapters owe it and hued like the rows themselves, then the finished ones
/// in the done hue at the far end. What's left bare between them is the
/// middle ground — chapters owing nothing that nobody has called done.
class PlanFolderSummary extends StatelessWidget {
  const PlanFolderSummary({super.key, required this.rows});
  final List<PlanChapter> rows;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) return const SizedBox.shrink();
    final segments = [
      for (final kind in planActionKinds)
        (short: kind.short, label: kind.label, color: planColor(kind), tone: Ds.mid, count: owedCount(rows, kind)),
      (short: 'done', label: 'Done', color: Ds.done.withValues(alpha: 0.8), tone: Ds.done, count: doneCount(rows)),
    ].where((s) => s.count > 0).toList();

    return Row(
      children: [
        Expanded(
          child: segments.isEmpty
              ? Text('All ${rows.length} clean', style: DsStyle.ui(DsText.ui, color: Ds.faint))
              : Text.rich(
                  TextSpan(
                    style: DsStyle.ui(DsText.ui, color: Ds.mid).copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
                    children: [
                      for (var i = 0; i < segments.length; i++) ...[
                        if (i > 0) TextSpan(text: ' · ', style: TextStyle(color: Ds.faint)),
                        TextSpan(
                          text: '${segments[i].count} ${segments[i].short}',
                          style: TextStyle(color: segments[i].tone),
                        ),
                      ],
                    ],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
        ),
        const SizedBox(width: 12),
        Semantics(
          label: segments.isEmpty
              ? 'All ${rows.length} clean'
              : segments.map((s) => '${s.count} ${s.label}').join(', '),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(DsGeom.radiusRound),
            child: SizedBox(
              width: 96,
              height: 4,
              child: Row(
                children: [
                  for (final s in segments) Expanded(flex: s.count, child: ColoredBox(color: s.color)),
                  Expanded(
                    flex: (rows.length - segments.fold<int>(0, (sum, s) => sum + s.count)).clamp(0, rows.length),
                    child: ColoredBox(color: Ds.raise),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
