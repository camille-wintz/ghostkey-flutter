import 'package:flutter/material.dart';

import 'dashboard_cat.dart';
import 'dashboard_last_edit.dart';
import 'dashboard_manuscript.dart';
import 'dashboard_tasks.dart';
import 'dashboard_week.dart';

/// The desk blotter the room opens on, and the same five readings the desk
/// shows, in the order a phone reads them: the week's words, where you left
/// off, the next tasks, the newest cat, and the whole manuscript as one
/// ruled band across the foot.
class DashboardTab extends StatelessWidget {
  const DashboardTab({super.key});

  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: const [
          DashboardWeek(),
          SizedBox(height: 32),
          DashboardLastEdit(),
          SizedBox(height: 32),
          DashboardTasks(),
          SizedBox(height: 32),
          DashboardCat(),
          SizedBox(height: 32),
          DashboardManuscript(),
        ],
      );
}
