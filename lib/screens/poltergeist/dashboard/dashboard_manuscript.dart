import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/plan_markers.dart';
import '../../../core/words.dart';
import '../../../ds/tokens.dart';
import '../../../poltergeist/numbers.dart';
import '../../../poltergeist/plan_rules.dart';
import '../../../poltergeist/providers.dart';
import '../../../server/dto/projects.dart';
import '../poltergeist_tabs.dart';
import '../project_scope_id.dart';
import '../section_link.dart';
import 'dashboard_section.dart';

/// The whole book in one ruled band: every chapter's standing laid end to
/// end, clean grey through the plan ladder's hues, with the manuscript's size
/// on the rule. Move/delete rows and missing chapters sit out — the band
/// shows where the prose stands, not the board's bookkeeping. The band is
/// always drawn: with no chapter standing yet it is one neutral rule.
class DashboardManuscript extends ConsumerWidget {
  const DashboardManuscript({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projectId = projectIdOf(context);
    final rows = ref.watch(planBoardProvider(projectId)).value?.plan.chapters ?? const <PlanChapter>[];
    final days = ref.watch(wordStatsProvider(projectId)).value;

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
      eyebrow: 'Manuscript',
      action: SectionLink('$meta →', onPressed: () => PoltergeistTabs.of(context).open(PoltergeistTab.plan)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 8,
            child: shown == 0
                ? ColoredBox(color: Ds.edgeHi)
                // stretch, not the default centre: a childless ColoredBox
                // takes the smallest height its constraints allow, so under
                // a centred Row every segment of the band draws at zero.
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final s in segments)
                        if (s.figure > 0)
                          Expanded(
                            flex: (s.figure * 1000 / shown).round(),
                            child: Padding(
                              padding: const EdgeInsets.only(right: 2),
                              child: ColoredBox(color: s.color),
                            ),
                          ),
                    ],
                  ),
          ),
          const SizedBox(height: 12),
          // Two abreast: the four standings are a key to the band above them,
          // so they want to stay near it rather than run off down the page.
          for (var i = 0; i < segments.length; i += 2) ...[
            if (i > 0) const SizedBox(height: 10),
            Row(
              children: [
                for (final s in segments.skip(i).take(2)) Expanded(child: _Key(label: s.label, figure: s.figure, color: s.color)),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _Key extends StatelessWidget {
  const _Key({required this.label, required this.figure, required this.color});
  final String label;
  final int figure;
  final Color color;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 8, height: 8, color: color),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              '$label $figure'.toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: DsStyle.eyebrow(color: Ds.faint),
            ),
          ),
        ],
      );
}
