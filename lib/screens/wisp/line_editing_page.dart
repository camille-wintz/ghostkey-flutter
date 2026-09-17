import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../ds/tokens.dart';
import '../../server/dto/edit_pass.dart';
import '../../server/dto/jobs.dart';
import '../../server/dto/projects.dart';
import '../../server/errors.dart';
import '../../server/providers.dart';
import '../../ui/state_screen.dart';
import '../../wisp/providers.dart';
import '../project/project_root.dart';
import 'line_edit_chapter_row.dart';
import 'line_edit_chapter_screen.dart';
import 'line_edit_sheet.dart';
import 'report_card.dart';
import 'wisp_notice.dart';

/// Every chapter with its line edit, so a book can be passed over chapter by
/// chapter from one list. A chapter opens onto its own page, where its notes
/// are ruled on over the text — PhantomMemory's review, the same one.
class LineEditingPage extends ConsumerWidget {
  const LineEditingPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projectId = ProjectScope.of(context);
    final project = ref.watch(projectProvider(projectId));
    final jobs = ref.watch(wispJobsProvider(projectId)).value ?? const <JobSnapshot>[];

    final data = project.value;
    if (data == null) {
      return project.hasError
          ? StateScreen(
              message: 'Could not load the chapters.',
              detail: messageFor(project.error),
              actionLabel: 'Try Again',
              onAction: () => ref.invalidate(projectProvider(projectId)),
            )
          : const StateScreen(spinner: true, message: 'Loading the chapters…');
    }
    final chapters = chaptersInTree(data.chapters);

    // The newest pass on each chapter; the feed is newest first.
    final passes = <String, JobSnapshot>{};
    for (final job in jobs.where((j) => j.kind == 'edit_pass' && j.subject != null)) {
      passes.putIfAbsent(job.subject!, () => job);
    }

    void open(DocumentSummary chapter) => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => LineEditChapterScreen(projectId: projectId, chapter: chapter)),
        );

    return RefreshIndicator(
      color: Ds.accent,
      backgroundColor: Ds.panel,
      onRefresh: () => ref.refresh(wispJobsProvider(projectId).future),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 40),
        children: [
          Text(
            'Craft notes on each chapter, plus the proofread, to accept one at a time.',
            style: DsStyle.ui(DsText.ui, color: Ds.mid),
          ),
          const SizedBox(height: 14),
          if (chapters.isEmpty)
            const WispNotice('The manuscript has no chapters yet. Add some in Apparition and come back to Wisp.')
          else
            ReportCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  for (final (i, chapter) in chapters.indexed)
                    LineEditChapterRow(
                      index: i,
                      chapter: chapter,
                      pass: passes[chapter.id],
                      divider: i > 0,
                      onOpen: () => open(chapter),
                      onLineEdit: () => showLineEditSheet(context, projectId: projectId, chapter: chapter),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// How many notes a finished pass left waiting, or null when it left none to
/// review (still running, failed, or already ruled on and dismissed).
int? waitingNotes(JobSnapshot? pass) {
  if (pass == null || pass.status != JobStatus.done) return null;
  return EditPassResult.tryParse(pass.result)?.notes.length;
}
