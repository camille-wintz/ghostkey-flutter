import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../chat/providers.dart';
import '../../../chat/work_plan_draft.dart';
import '../../../server/dto/work_plan.dart';
import '../../../ui/page_notice.dart';
import '../../mara/outline/outline_editor.dart';

/// The plan's editor: the outline's full page of prose, read only while a
/// turn runs — the turn keeps this same plan current — and re-read when one
/// ends.
class WorkPlanReviewEditor extends ConsumerStatefulWidget {
  const WorkPlanReviewEditor({super.key, required this.projectId, required this.plan});
  final String projectId;

  /// Read once, on open; after that the draft owns the text.
  final WorkPlan plan;

  @override
  ConsumerState<WorkPlanReviewEditor> createState() => _WorkPlanReviewEditorState();
}

class _WorkPlanReviewEditorState extends ConsumerState<WorkPlanReviewEditor> {
  late final WorkPlanDraft _draft =
      WorkPlanDraft(ProviderScope.containerOf(context, listen: false), widget.projectId, widget.plan);

  @override
  void dispose() {
    _draft.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(conversationProvider(widget.projectId).select((s) => s.busy), (was, now) {
      if (was == true && !now) _draft.refresh();
    });
    final turnRunning = ref.watch(conversationProvider(widget.projectId).select((s) => s.busy));
    return Column(
      children: [
        ValueListenableBuilder(
          valueListenable: _draft.replaced,
          builder: (context, replaced, _) => replaced
              ? const Padding(
                  padding: EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: PageNotice('The chat changed this plan while you were typing. This is its copy.'),
                )
              : const SizedBox.shrink(),
        ),
        Expanded(
          child: OutlineEditor(
            autosave: _draft.autosave,
            readOnly: turnRunning,
            readOnlyNote: 'Read only while the chat answers',
            hint: 'What this task is for, what is decided, what is open, what comes next.',
          ),
        ),
      ],
    );
  }
}
