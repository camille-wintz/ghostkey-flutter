import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../ds/tokens.dart';
import '../../../poltergeist/providers.dart';
import '../../../poltergeist/tasks_notifier.dart';
import '../../../ui/press.dart';
import '../poltergeist_tabs.dart';
import '../project_scope_id.dart';
import '../section_link.dart';
import '../tasks/task_row.dart';
import 'dashboard_section.dart';

const int _slots = 3;

/// The top of the task list — the next three things, completable in place,
/// each with its age on the right margin. A spare slot offers the full list's
/// add row rather than leaving dead space.
class DashboardTasks extends ConsumerWidget {
  const DashboardTasks({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projectId = projectIdOf(context);
    final state = ref.watch(tasksProvider(projectId));
    final top = openTasks(state.value?.tasks).take(_slots).toList();
    void openTasksTab() => PoltergeistTabs.of(context).open(PoltergeistTab.tasks);

    return DashboardSection(
      eyebrow: 'Next tasks',
      action: SectionLink('All tasks →', onPressed: openTasksTab),
      child: !state.hasValue
          ? const SectionNote('Loading…')
          : Column(
              children: [
                for (final task in top)
                  TaskRow(
                    key: ValueKey(task.id),
                    task: task,
                    onToggle: () => ref.read(tasksProvider(projectId).notifier).toggle(task.id),
                  ),
                if (top.length < _slots) _AddSlot(onPressed: openTasksTab),
              ],
            ),
    );
  }
}

class _AddSlot extends StatelessWidget {
  const _AddSlot({required this.onPressed});
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Press(
        onPressed: onPressed,
        semanticLabel: 'Add a task',
        builder: (context, pressed) => Container(
          height: 38,
          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Ds.edge))),
          child: Row(
            children: [
              SizedBox(
                width: 32,
                child: Center(child: Text('+', style: DsStyle.ui(DsText.ui, color: pressed ? Ds.low : Ds.faint))),
              ),
              const SizedBox(width: 6),
              Text('Add a task', style: DsStyle.ui(DsText.ui, color: pressed ? Ds.low : Ds.faint)),
            ],
          ),
        ),
      );
}
