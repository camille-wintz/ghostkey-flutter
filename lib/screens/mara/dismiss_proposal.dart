import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../mara/chapter_plan.dart';
import '../../ui/confirm_sheet.dart';

/// Throw the pending proposal or changeset away — asked first, because it may
/// carry an hour of the author's reordering. The one way out of a review,
/// wherever it is offered.
Future<void> dismissProposal(BuildContext context, WidgetRef ref, String projectId, {required bool changeset}) async {
  final ok = await showConfirmSheet(
    context,
    eyebrow: 'Dismiss',
    title: changeset ? 'Dismiss these changes?' : 'Dismiss these chapters?',
    message: changeset
        ? "The proposed changes go, and you're back on the plan. The book and the plan both stay as they are."
        : "The proposed chapters go, and you're back on the plan. Nothing in the book changes — no chapter existed yet.",
    confirmLabel: 'Dismiss',
    destructive: true,
  );
  if (ok) await ref.read(chapterPlanWritesProvider(projectId).notifier).dismiss();
}
