import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../chat/review/providers.dart';
import '../../../server/dto/edit_pass.dart';
import '../../../server/errors.dart';
import '../../../ui/state_screen.dart';
import '../../apparition/providers.dart';
import 'line_edit_review_view.dart';
import 'pass_status.dart';
import 'review_text.dart';

/// A chapter a turn opened. With a finished pass on it, its line edits to
/// rule on; otherwise the chapter to read, and where its pass stands.
class ChapterReview extends ConsumerWidget {
  const ChapterReview({super.key, required this.projectId, required this.documentId});
  final String projectId;
  final String documentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subject = (projectId: projectId, subject: documentId);
    final job = ref.watch(editPassJobProvider(subject));
    final finished = job.value;
    if (finished != null && EditPassResult.tryParse(finished.result) != null) {
      return LineEditReviewView(projectId: projectId, subject: documentId, jobId: finished.id);
    }

    final doc = ref.watch(documentProvider((projectId: projectId, documentId: documentId)));
    return doc.when(
      loading: () => const StateScreen(spinner: true, message: 'Opening the chapter…'),
      error: (e, _) => StateScreen(
        message: 'The chapter would not open',
        detail: messageFor(e),
        actionLabel: 'Try again',
        onAction: () => ref.invalidate(documentProvider((projectId: projectId, documentId: documentId))),
      ),
      data: (doc) => Column(
        children: [
          Expanded(child: ReviewText(text: doc.content)),
          PassStatus(subject: subject, job: job),
        ],
      ),
    );
  }
}
