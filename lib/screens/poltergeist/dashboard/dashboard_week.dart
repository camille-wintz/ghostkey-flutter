import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/words.dart';
import '../../../ds/tokens.dart';
import '../../../poltergeist/ledger.dart';
import '../../../poltergeist/providers.dart';
import '../poltergeist_tabs.dart';
import '../project_scope_id.dart';
import '../section_link.dart';
import '../words/word_columns.dart';
import 'dashboard_section.dart';

/// The week's words as seven amber columns with their figures in place, and
/// the week's total and daily average under the baseline.
class DashboardWeek extends ConsumerWidget {
  const DashboardWeek({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projectId = projectIdOf(context);
    final days = ref.watch(wordStatsProvider(projectId)).value;
    final week = lastWeek(days ?? const []);
    final total = week.fold(0, (sum, d) => sum + d.written);
    final perDay = (total / 7).round();
    final figure = DsStyle.ui(DsText.ui, color: Ds.soft).copyWith(fontFeatures: const [FontFeature.tabularFigures()]);

    return DashboardSection(
      eyebrow: 'This week',
      action: SectionLink('Ledger →', onPressed: () => PoltergeistTabs.of(context).open(PoltergeistTab.words)),
      child: days == null
          ? const SectionNote('Loading…')
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                WordColumns(days: week, weekdayLabels: true, showValues: true),
                const SizedBox(height: 12),
                Text.rich(
                  TextSpan(
                    style: DsStyle.ui(DsText.ui, color: Ds.low),
                    children: [
                      TextSpan(text: formatWords(total), style: figure),
                      const TextSpan(text: ' words this week · '),
                      TextSpan(text: formatWords(perDay), style: figure),
                      const TextSpan(text: '/day'),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}
