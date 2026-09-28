import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../chat/attachments.dart';
import '../../ds/tokens.dart';
import '../../mara/providers.dart';
import '../../server/dto/chat.dart';
import '../../server/dto/jobs.dart';
import '../../server/jobs/api.dart';
import '../../store/active_project.dart';

/// What the assistant changed in the project this turn besides notes: a
/// passage of a chapter, a chapter it wrote, a world-bible card, and the
/// changes it handed to tasks (the outline, the waiting chapters), which land
/// a few seconds after the answer. Receipts, not prompts — each write
/// happened on the author's say-so.
class EditReceipt extends StatelessWidget {
  const EditReceipt({super.key, required this.edits});
  final ChatTurnEdits edits;

  @override
  Widget build(BuildContext context) {
    if (edits.isEmpty) return const SizedBox.shrink();
    final rows = <(IconData, Color, String, String, String)>[
      for (final e in edits.chapterEdits)
        e.created
            ? (LucideIcons.filePlus, Ds.attention, 'Wrote ', stripMd(e.filename), ' into the manuscript')
            : (LucideIcons.filePen, Ds.attention, 'Edited a passage of ', stripMd(e.filename), ' in the manuscript'),
      for (final e in edits.bibleEdits) (LucideIcons.bookMarked, Ds.done, e.created ? 'Added ' : 'Updated ', e.name, ' in the world bible'),
    ];
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final t in edits.tasks) Padding(padding: const EdgeInsets.only(bottom: 4), child: _TaskRow(task: t)),
          for (var i = 0; i < rows.length; i++)
            Padding(
              padding: EdgeInsets.only(top: i == 0 ? 0 : 4),
              child: Row(
                children: [
                  Icon(rows[i].$1, size: 13, color: rows[i].$2),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text.rich(
                      TextSpan(
                        text: rows[i].$3,
                        children: [
                          TextSpan(text: rows[i].$4, style: TextStyle(color: Ds.hi)),
                          TextSpan(text: rows[i].$5),
                        ],
                      ),
                      style: DsStyle.ui(DsText.ui, color: Ds.mid),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// A task's line, following its job: the label while it runs, then its own
/// receipt. Mobile follows a job by asking (lib/server/jobs/run_job.dart); a
/// queued task has no row yet, so a missing one is asked again. When it
/// lands, the outline and the chapters are read again.
class _TaskRow extends ConsumerStatefulWidget {
  const _TaskRow({required this.task});
  final ChatTask task;

  @override
  ConsumerState<_TaskRow> createState() => _TaskRowState();
}

class _TaskRowState extends ConsumerState<_TaskRow> {
  static const _poll = Duration(milliseconds: 1500);
  static const _patience = 60;

  JobSnapshot? _job;
  Timer? _timer;
  int _asked = 0;

  @override
  void initState() {
    super.initState();
    _ask();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _ask() async {
    final projectId = ref.read(activeProjectProvider).projectId;
    if (projectId == null) return;
    _asked++;
    try {
      final job = await getJob(projectId, widget.task.id);
      if (!mounted) return;
      setState(() => _job = job);
      if (!job.isRunning) {
        ref.invalidate(authoredOutlineProvider(projectId));
        return;
      }
    } catch (e) {
      // Queued behind another change to the same page: no row yet.
      debugPrint('[edit_receipt] task ${widget.task.id} not readable yet: $e');
    }
    if (mounted && _asked < _patience) _timer = Timer(_poll, _ask);
  }

  @override
  Widget build(BuildContext context) {
    final job = _job;
    final result = job != null && !job.isRunning && job.result is Map ? job.result as Map : null;
    final summary = result?['summary'] is String ? result!['summary'] as String : null;
    final failed = job != null && (job.status == JobStatus.error || job.status == JobStatus.cancelled || result?['ok'] == false);
    final color = failed ? Ds.destructive : (summary != null ? Ds.done : Ds.attention);
    final icon = widget.task.task == 'update_chapter_plan' ? LucideIcons.listOrdered : LucideIcons.scrollText;
    return Row(
      children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            summary ?? (failed ? "${widget.task.label} didn't land" : '${widget.task.label}…'),
            style: DsStyle.ui(DsText.ui, color: Ds.mid),
          ),
        ),
      ],
    );
  }
}
