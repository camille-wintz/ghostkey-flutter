import 'package:flutter/material.dart';

import '../../../poltergeist/time.dart';
import '../page_header.dart';
import 'dashboard_counts.dart';
import 'dashboard_last_edit.dart';
import 'dashboard_manuscript.dart';
import 'dashboard_summary.dart';
import 'dashboard_tasks.dart';
import 'dashboard_week.dart';

/// The desk blotter the room opens on: a one-line reading of the week under
/// the title, then where you left off, the week's words, the next three
/// tasks, what the board still owes — and the whole manuscript as one ruled
/// band across the foot.
class DashboardTab extends StatelessWidget {
  const DashboardTab({super.key});

  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: [
          PageHeader(title: 'Today', meta: todayLabel(DateTime.now())),
          const DashboardSummary(),
          const SizedBox(height: 32),
          const DashboardLastEdit(),
          const SizedBox(height: 32),
          const DashboardWeek(),
          const SizedBox(height: 32),
          const DashboardTasks(),
          const SizedBox(height: 32),
          const DashboardCounts(),
          const SizedBox(height: 32),
          const DashboardManuscript(),
        ],
      );
}
