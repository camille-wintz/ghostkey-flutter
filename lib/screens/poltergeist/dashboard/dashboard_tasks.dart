import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../ds/tokens.dart';
import '../../../poltergeist/providers.dart';
import '../../../poltergeist/tasks_notifier.dart';
import '../../../ui/button.dart';
import '../poltergeist_tabs.dart';
import '../project_scope_id.dart';
import '../section_link.dart';
import '../tasks/task_row.dart';
import 'dashboard_section.dart';

const int _slots = 3;

/// The top of the task list — the next three things, completable in place,
/// each with its age on the right margin, and the way into the full list
/// under them. An empty list is a good night's work, not a missing feature:
/// it says so in the serif the room keeps for the author's own words.
class DashboardTasks extends ConsumerWidget {
  const DashboardTasks({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projectId = projectIdOf(context);
    final state = ref.watch(tasksProvider(projectId));
    final top = openTasks(state.value?.tasks).take(_slots).toList();
    void openTasksTab() => PoltergeistTabs.of(context).open(PoltergeistTab.tasks);

    final addTask = GkButton(
      label: 'Add task',
      variant: ButtonVariant.outline,
      onPressed: openTasksTab,
      leading: Icon(LucideIcons.plus, size: 13, color: Ds.soft),
    );

    return DashboardSection(
      eyebrow: 'Next tasks',
      action: SectionLink('All tasks →', onPressed: openTasksTab),
      child: !state.hasValue
          ? const SectionNote('Loading…')
          : top.isEmpty
              ? Row(
                  children: [
                    Expanded(
                      child: Text(
                        'No pending tasks — enjoy the break.',
                        style: DsStyle.prose(DsText.body, color: Ds.low).copyWith(fontStyle: FontStyle.italic),
                      ),
                    ),
                    const SizedBox(width: 16),
                    addTask,
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final task in top)
                      TaskRow(
                        key: ValueKey(task.id),
                        task: task,
                        onToggle: () => ref.read(tasksProvider(projectId).notifier).toggle(task.id),
                      ),
                    const SizedBox(height: 12),
                    addTask,
                  ],
                ),
    );
  }
}
