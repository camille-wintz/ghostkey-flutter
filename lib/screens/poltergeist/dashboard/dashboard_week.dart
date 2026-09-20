import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../poltergeist/ledger.dart';
import '../../../poltergeist/providers.dart';
import '../poltergeist_tabs.dart';
import '../section_link.dart';
import '../words/word_columns.dart';
import 'dashboard_section.dart';

/// The week's words as seven amber columns with their figures in place, and
/// a tick under each day that met the daily target. The figures under the
/// baseline — the week's total, the streak, what the week is worth against
/// its cat — belong to the ledger a tap away; here the shape of the week is
/// the reading.
class DashboardWeek extends ConsumerWidget {
  const DashboardWeek({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rewards = ref.watch(rewardsProvider).value;
    final days = rewards?.days;

    return DashboardSection(
      eyebrow: 'This week',
      action: SectionLink('Ledger →', onPressed: () => PoltergeistTabs.of(context).open(PoltergeistTab.words)),
      child: days == null
          ? const SectionNote('Loading…')
          : WordColumns(
              days: lastWeek(days),
              weekdayLabels: true,
              showValues: true,
              metDays: rewards?.metDays.toSet(),
            ),
    );
  }
}
