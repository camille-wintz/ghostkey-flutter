import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../chat/providers.dart';
import '../../../server/errors.dart';
import '../../../ui/state_screen.dart';
import 'work_plan_review_editor.dart';

/// A work plan the chat opened, or the author opened from the drawer:
/// editable markdown, read once and saved as it is typed.
class WorkPlanReview extends ConsumerWidget {
  const WorkPlanReview({super.key, required this.projectId, required this.planId});
  final String projectId;
  final String planId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final key = (projectId: projectId, planId: planId);
    return ref.watch(workPlanProvider(key)).when(
          skipLoadingOnReload: true,
          loading: () => const StateScreen(spinner: true, message: 'Opening the plan…'),
          error: (e, _) => StateScreen(
            message: e is ServerError && e.status == 404 ? 'This plan was deleted' : 'The plan would not open',
            detail: messageFor(e),
            actionLabel: 'Try again',
            onAction: () => ref.invalidate(workPlanProvider(key)),
          ),
          data: (plan) => WorkPlanReviewEditor(key: ValueKey(plan.id), projectId: projectId, plan: plan),
        );
  }
}
