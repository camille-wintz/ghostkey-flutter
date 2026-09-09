import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../ds/tokens.dart';
import '../../../poltergeist/providers.dart';
import '../../../poltergeist/tasks_notifier.dart';
import '../../../server/dto/poltergeist.dart';
import '../../../ui/press.dart';
import '../page_header.dart';
import '../project_scope_id.dart';
import 'task_add_row.dart';
import 'task_row.dart';

/// The manual task list: add, check, uncheck. Nothing writes to this list but
/// the writer — no generation, no automation.
class TasksTab extends ConsumerStatefulWidget {
  const TasksTab({super.key});

  @override
  ConsumerState<TasksTab> createState() => _TasksTabState();
}

class _TasksTabState extends ConsumerState<TasksTab> {
  bool _showDone = true;

  @override
  Widget build(BuildContext context) {
    final projectId = projectIdOf(context);
    final state = ref.watch(tasksProvider(projectId));
    final notifier = ref.read(tasksProvider(projectId).notifier);
    final loaded = state.hasValue;
    final tasks = state.value?.tasks;
    final open = openTasks(tasks);
    final done = doneTasks(tasks);
    final total = open.length + done.length;
    final donePct = total == 0 ? 0.0 : done.length / total;

    final meta = !loaded
        ? (state.hasError ? '—' : 'Loading…')
        : open.isEmpty
            ? 'All clear'
            : '${open.length} open · ${done.length} done';

    final items = <Widget>[
      if (state.hasError && !loaded)
        _Notice(
          text: "The list didn't load.",
          action: 'Try again',
          color: Ds.low,
          onAction: () => ref.invalidate(tasksProvider(projectId)),
        ),
      if (loaded) ...[
        // The rule under the header doubles as the ledger's completion
        // figure — how much of the list is crossed off.
        _ProgressRule(fraction: donePct),
        TaskAddRow(onAdd: notifier.add),
        if (state.value!.saveFailed)
          _Notice(
            text: "The last change didn't save.",
            action: 'Retry',
            color: Ds.attention400,
            onAction: notifier.retry,
          ),
        if (open.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 6, bottom: 12),
            child: Text(
              'Nothing open. The list is clean.',
              style: DsStyle.prose(DsText.body, color: Ds.low).copyWith(fontStyle: FontStyle.italic),
            ),
          ),
        for (final task in open) _row(task, notifier),
        if (done.isNotEmpty) ...[
          const SizedBox(height: 28),
          _DoneHeader(count: done.length, open: _showDone, onToggle: () => setState(() => _showDone = !_showDone)),
          if (_showDone)
            for (final task in done) _row(task, notifier),
        ],
      ],
    ];

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      itemCount: 1 + items.length,
      itemBuilder: (context, i) => i == 0 ? PageHeader(title: 'Tasks', meta: meta) : items[i - 1],
    );
  }

  Widget _row(TaskItem task, TasksNotifier notifier) => TaskRow(
        key: ValueKey(task.id),
        task: task,
        onToggle: () => notifier.toggle(task.id),
        onRemove: () => notifier.remove(task.id),
      );
}

class _ProgressRule extends StatelessWidget {
  const _ProgressRule({required this.fraction});
  final double fraction;

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(DsGeom.radiusRound),
        child: SizedBox(
          height: 2,
          child: Stack(
            children: [
              ColoredBox(color: Ds.raise, child: const SizedBox.expand()),
              AnimatedFractionallySizedBox(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOut,
                alignment: Alignment.centerLeft,
                widthFactor: fraction,
                child: ColoredBox(color: Ds.accent, child: const SizedBox.expand()),
              ),
            ],
          ),
        ),
      );
}

class _Notice extends StatelessWidget {
  const _Notice({required this.text, required this.action, required this.color, required this.onAction});
  final String text;
  final String action;
  final Color color;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 12, bottom: 4),
        child: Row(
          children: [
            Expanded(child: Text(text, style: DsStyle.ui(DsText.ui, color: color))),
            Press(
              onPressed: onAction,
              semanticLabel: action,
              builder: (context, pressed) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                child: Text(action, style: DsStyle.ui(DsText.ui, color: pressed ? Ds.hi : Ds.soft, weight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      );
}

class _DoneHeader extends StatelessWidget {
  const _DoneHeader({required this.count, required this.open, required this.onToggle});
  final int count;
  final bool open;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) => Press(
        onPressed: onToggle,
        semanticLabel: open ? 'Hide done tasks' : 'Show done tasks',
        builder: (context, pressed) => Container(
          height: DsGeom.ctl,
          padding: const EdgeInsets.only(bottom: 6),
          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: pressed ? Ds.accentMix(40) : Ds.edgeHi))),
          child: Row(
            children: [
              AnimatedRotation(
                turns: open ? 0.25 : 0,
                duration: DsMotion.duration,
                child: Icon(LucideIcons.chevronRight, size: 12, color: Ds.low),
              ),
              const SizedBox(width: 8),
              Expanded(child: Text('DONE', style: DsStyle.eyebrow(weight: FontWeight.w600))),
              Text(
                '$count',
                style: DsStyle.ui(DsText.eyebrow, color: Ds.low, tracking: 11 * 0.12)
                    .copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
              ),
            ],
          ),
        ),
      );
}
