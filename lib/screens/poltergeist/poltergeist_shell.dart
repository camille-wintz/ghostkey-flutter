import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../ds/tokens.dart';
import '../../poltergeist/providers.dart';
import '../../server/providers.dart';
import '../project/project_root.dart';
import 'dashboard/dashboard_tab.dart';
import 'plan/plan_tab.dart';
import 'poltergeist_header.dart';
import 'poltergeist_tab_bar.dart';
import 'poltergeist_tabs.dart';
import 'tasks/tasks_tab.dart';
import 'words/words_tab.dart';

/// Coming back to the phone after this long re-reads the manuscript, so the
/// board is held against it again — the desktop's reconcile-on-focus.
const Duration _resumeAfter = Duration(seconds: 30);

/// The room once it has arrived: the header, the open tab, the tab bar. Holds
/// the room's three reads alive for as long as it is open, so tabs share one
/// fetch each and switching between them costs nothing.
class PoltergeistShell extends ConsumerStatefulWidget {
  const PoltergeistShell({super.key});

  @override
  ConsumerState<PoltergeistShell> createState() => _PoltergeistShellState();
}

class _PoltergeistShellState extends ConsumerState<PoltergeistShell> {
  PoltergeistTab _tab = PoltergeistTab.dashboard;
  late final AppLifecycleListener _lifecycle;
  DateTime? _hiddenAt;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(
      onHide: () => _hiddenAt = DateTime.now(),
      onShow: _onShow,
    );
  }

  void _onShow() {
    final hiddenAt = _hiddenAt;
    _hiddenAt = null;
    if (hiddenAt == null || DateTime.now().difference(hiddenAt) < _resumeAfter) return;
    final projectId = ProjectScope.of(context);
    ref.invalidate(projectProvider(projectId));
    ref.invalidate(wordStatsProvider(projectId));
    ref.invalidate(tasksProvider(projectId));
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  void _open(PoltergeistTab tab) {
    if (tab != _tab) setState(() => _tab = tab);
  }

  @override
  Widget build(BuildContext context) {
    final projectId = ProjectScope.of(context);
    // Subscribed, not read: keeps the auto-dispose reads alive for the room's
    // life without rebuilding the shell on every change.
    ref.listen(wordStatsProvider(projectId), (_, _) {});
    ref.listen(planBoardProvider(projectId), (_, _) {});
    final openTasks = ref.watch(openTaskCountProvider(projectId));

    return PoltergeistTabs(
      current: _tab,
      open: _open,
      child: Scaffold(
        backgroundColor: Ds.void_,
        resizeToAvoidBottomInset: true,
        body: SafeArea(
          child: Column(
            children: [
              const PoltergeistHeader(),
              Expanded(
                child: switch (_tab) {
                  PoltergeistTab.dashboard => const DashboardTab(),
                  PoltergeistTab.words => const WordsTab(),
                  PoltergeistTab.tasks => const TasksTab(),
                  PoltergeistTab.plan => const PlanTab(),
                },
              ),
              PoltergeistTabBar(current: _tab, openTasks: openTasks, onOpen: _open),
            ],
          ),
        ),
      ),
    );
  }
}
