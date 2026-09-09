import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../ds/tokens.dart';
import '../../../poltergeist/time.dart';
import '../../../server/dto/poltergeist.dart';
import '../../../ui/press.dart';
import 'task_checkbox.dart';

/// One ruled task row: check to complete, uncheck to reopen, an age figure on
/// the right margin, and a quiet × for the task that should never have been
/// written down. A phone has no hover, so the × stays, faint.
class TaskRow extends StatelessWidget {
  const TaskRow({super.key, required this.task, required this.onToggle, this.onRemove});
  final TaskItem task;
  final VoidCallback onToggle;

  /// Absent on the dashboard's short list, which only completes.
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final done = !task.isOpen;
    return Container(
      height: DsGeom.row,
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Ds.edge))),
      child: Row(
        children: [
          TaskCheckbox(
            checked: done,
            onToggle: onToggle,
            label: done ? 'Reopen "${task.title}"' : 'Complete "${task.title}"',
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              task.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: DsStyle.ui(DsText.ui, color: done ? Ds.faint : Ds.ink).copyWith(
                decoration: done ? TextDecoration.lineThrough : null,
                decorationColor: Ds.faint,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            shortAge(done ? task.completedAt! : task.createdAt),
            style: DsStyle.ui(DsText.eyebrow, color: Ds.faint).copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
          ),
          if (onRemove != null)
            Press(
              onPressed: onRemove,
              semanticLabel: 'Remove "${task.title}"',
              builder: (context, pressed) => SizedBox(
                width: 36,
                height: DsGeom.row,
                child: Icon(LucideIcons.x, size: 13, color: pressed ? Ds.destructive : Ds.faint),
              ),
            )
          else
            const SizedBox(width: 4),
        ],
      ),
    );
  }
}
