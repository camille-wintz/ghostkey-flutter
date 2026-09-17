import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../chat/providers.dart';
import '../../../chat/review/line_edit_review.dart';
import '../../../server/errors.dart';
import '../../../ui/state_screen.dart';
import 'note_panel.dart';
import 'review_text.dart';

/// A finished pass under review: the text above with the note's passage lit,
/// the note at the bottom with its arrows, Reject and Accept.
class LineEditReviewView extends ConsumerWidget {
  const LineEditReviewView({super.key, required this.projectId, required this.subject, required this.jobId});
  final String projectId;
  final String subject;
  final String jobId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final key = (projectId: projectId, subject: subject, jobId: jobId);
    final review = ref.watch(lineEditReviewProvider(key));
    // The chat may be writing this same text; the desk locks its view for
    // the length of a turn, and so does this.
    final turnRunning = ref.watch(chatTurnProvider(projectId).select((s) => s.sending));

    return review.when(
      skipLoadingOnReload: true,
      loading: () => const StateScreen(spinner: true, message: 'Opening the line edits…'),
      error: (e, _) => StateScreen(
        message: 'The line edits would not open',
        detail: messageFor(e),
        actionLabel: 'Try again',
        onAction: () => ref.invalidate(lineEditReviewProvider(key)),
      ),
      data: (state) {
        final notifier = ref.read(lineEditReviewProvider(key).notifier);
        if (state.notes.isEmpty) {
          return StateScreen(
            message: 'Nothing to change',
            detail: 'The pass read it through and left no notes.',
            actionLabel: 'Done',
            onAction: notifier.done,
          );
        }
        return Column(
          children: [
            Expanded(child: ReviewText(text: state.text, highlight: state.currentRange)),
            NotePanel(
              state: state,
              locked: turnRunning,
              onPrevious: notifier.previous,
              onNext: notifier.next,
              onAccept: notifier.accept,
              onReject: notifier.reject,
              onDone: notifier.done,
            ),
          ],
        );
      },
    );
  }
}
