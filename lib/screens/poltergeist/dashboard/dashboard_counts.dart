import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/plan_markers.dart';
import '../../../ds/tokens.dart';
import '../../../poltergeist/plan_rules.dart';
import '../../../poltergeist/providers.dart';
import '../../../server/dto/projects.dart';
import '../poltergeist_tabs.dart';
import '../project_scope_id.dart';
import '../section_link.dart';
import 'dashboard_section.dart';

/// What the plan board still owes — line edits and rewrites in the ladder's
/// own hues — next to how much of the manuscript owes nothing. Reads the
/// board's own state; the counts refresh when the board does.
class DashboardCounts extends ConsumerWidget {
  const DashboardCounts({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projectId = projectIdOf(context);
    final board = ref.watch(planBoardProvider(projectId));
    final plan = board.value?.plan;
    final rows = plan?.chapters ?? const <PlanChapter>[];

    return DashboardSection(
      eyebrow: 'Owed edits',
      action: SectionLink('Chapters →', onPressed: () => PoltergeistTabs.of(context).open(PoltergeistTab.plan)),
      child: plan == null
          ? SectionNote(board.hasError ? 'No plan yet — open the Plan tab to build one.' : 'Loading…', italic: board.hasError)
          : Row(
              children: [
                _Stat(figure: owedCount(rows, PlanActionKind.lineEdit), label: PlanActionKind.lineEdit.label, color: planColor(PlanActionKind.lineEdit)),
                const SizedBox(width: 36),
                _Stat(figure: owedCount(rows, PlanActionKind.rewrite), label: PlanActionKind.rewrite.label, color: planColor(PlanActionKind.rewrite)),
                const SizedBox(width: 36),
                _Stat(figure: cleanCount(rows), label: 'Clean', color: Ds.faint),
              ],
            ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.figure, required this.label, required this.color});
  final int figure;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$figure',
            style: DsStyle.prose(const DsStep(30, 30), color: color).copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
          ),
          const SizedBox(height: 6),
          Text(label.toUpperCase(), style: DsStyle.eyebrow()),
        ],
      );
}
