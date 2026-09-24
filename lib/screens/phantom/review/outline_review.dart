import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../chat/review/providers.dart';
import '../../../mara/providers.dart';
import '../../../server/dto/edit_pass.dart';
import '../../../server/errors.dart';
import '../../../ui/state_screen.dart';
import 'line_edit_review_view.dart';
import 'outline_review_editor.dart';
import 'pass_status.dart';

/// The Outline page a turn opened: editable. A finished pass on the outline
/// is ruled on first, as on the desk, where its notes sit under the editor.
class OutlineReview extends ConsumerWidget {
  const OutlineReview({super.key, required this.projectId});
  final String projectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subject = (projectId: projectId, subject: 'outline');
    final job = ref.watch(editPassJobProvider(subject));
    final finished = job.value;
    if (finished != null && EditPassResult.tryParse(finished.result) != null) {
      return LineEditReviewView(projectId: projectId, subject: 'outline', jobId: finished.id);
    }

    final outline = ref.watch(authoredOutlineProvider(projectId));
    return outline.when(
      skipLoadingOnReload: true,
      loading: () => const StateScreen(spinner: true, message: 'Opening the outline…'),
      error: (e, _) => StateScreen(
        message: 'The outline would not open',
        detail: messageFor(e),
        actionLabel: 'Try again',
        onAction: () => ref.invalidate(authoredOutlineProvider(projectId)),
      ),
      data: (outline) => Column(
        children: [
          Expanded(child: OutlineReviewEditor(projectId: projectId, initial: outline.text)),
          PassStatus(subject: subject, job: job),
        ],
      ),
    );
  }
}
