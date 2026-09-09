import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../ds/tokens.dart';
import '../../../poltergeist/ledger.dart';
import '../../../poltergeist/numbers.dart';
import '../../../poltergeist/providers.dart';
import '../../../server/dto/projects.dart';
import '../project_scope_id.dart';

/// The blotter's opening line — the week, the list, and the board read back
/// as one italic sentence under the page title, numbers spelled as prose.
/// Rides the reads the panels below already make, so it costs nothing.
class DashboardSummary extends ConsumerWidget {
  const DashboardSummary({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projectId = projectIdOf(context);
    final days = ref.watch(wordStatsProvider(projectId)).value;
    if (days == null) return const SizedBox.shrink();
    final openCount = ref.watch(openTaskCountProvider(projectId));
    final plan = ref.watch(planBoardProvider(projectId)).value?.plan;

    final wroteDays = lastWeek(days).where((d) => d.written > 0).length;
    final wrote = wroteDays == 0
        ? 'No words yet in the last seven days.'
        : 'You wrote on ${spellNumber(wroteDays)} of the last seven days.';
    final tasks = openCount == 0 ? 'No tasks open' : '${_capitalize(spellNumber(openCount))} task${openCount == 1 ? '' : 's'} open';
    final owedCount = (plan?.chapters ?? const <PlanChapter>[]).where((c) => c.action != null).length;
    final owed = owedCount == 0
        ? 'nothing owed on the board'
        : '${spellNumber(owedCount)} chapter${owedCount == 1 ? '' : 's'} still owed a pass';

    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Text(
        '$wrote $tasks, $owed.',
        style: DsStyle.prose(DsText.body, color: Ds.mid).copyWith(fontStyle: FontStyle.italic),
      ),
    );
  }
}

String _capitalize(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
