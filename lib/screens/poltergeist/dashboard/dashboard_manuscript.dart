import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/plan_markers.dart';
import '../../../core/words.dart';
import '../../../ds/tokens.dart';
import '../../../poltergeist/numbers.dart';
import '../../../poltergeist/plan_rules.dart';
import '../../../poltergeist/providers.dart';
import '../../../server/dto/projects.dart';
import '../project_scope_id.dart';
import 'dashboard_section.dart';

/// The whole book in one ruled band: every chapter's standing laid end to
/// end, clean grey through the plan ladder's hues, with the manuscript's size
/// on the rule. Move/delete rows and missing chapters sit out — the band
/// shows where the prose stands, not the board's bookkeeping.
class DashboardManuscript extends ConsumerWidget {
  const DashboardManuscript({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projectId = projectIdOf(context);
    final rows = ref.watch(planBoardProvider(projectId)).value?.plan.chapters ?? const <PlanChapter>[];
    final days = ref.watch(wordStatsProvider(projectId)).value;
    if (rows.isEmpty) return const SizedBox.shrink();

    final segments = [
      (label: 'Clean', figure: cleanCount(rows), color: Ds.faint),
      (label: 'Line edit', figure: owedCount(rows, PlanActionKind.lineEdit), color: planColor(PlanActionKind.lineEdit).withValues(alpha: 0.7)),
      (label: 'Rewrite', figure: owedCount(rows, PlanActionKind.rewrite), color: planColor(PlanActionKind.rewrite)),
      (label: 'To write', figure: owedCount(rows, PlanActionKind.write), color: planColor(PlanActionKind.write)),
    ];
    final shown = segments.fold(0, (sum, s) => sum + s.figure);
    final totalWords = days != null && days.isNotEmpty ? days.last.total : null;
    final meta = [plural(rows.length, 'chapter'), if (totalWords != null) '${formatWords(totalWords)} words'].join(' · ');

    return DashboardSection(
      eyebrow: 'The manuscript',
      action: Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          meta.toUpperCase(),
          style: DsStyle.ui(DsText.eyebrow, color: Ds.faint, tracking: 11 * 0.12)
              .copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 8,
            child: Row(
              children: [
                for (final s in segments)
                  if (s.figure > 0)
                    Expanded(
                      flex: (s.figure * 1000 / (shown == 0 ? 1 : shown)).round(),
                      child: Padding(
                        padding: const EdgeInsets.only(right: 2),
                        child: ColoredBox(color: s.color),
                      ),
                    ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 18,
            runSpacing: 6,
            children: [
              for (final s in segments)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(width: 8, height: 8, color: s.color),
                    const SizedBox(width: 8),
                    Text('${s.label} ${s.figure}'.toUpperCase(), style: DsStyle.eyebrow()),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }
}
