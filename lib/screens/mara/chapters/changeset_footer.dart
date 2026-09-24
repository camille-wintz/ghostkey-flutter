import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../ds/tokens.dart';
import '../../../mara/chapter_plan.dart';
import '../../../mara/changeset_review.dart';
import '../../../mara/proposal.dart';
import '../../../server/dto/plan.dart';
import '../../../ui/button.dart';
import '../../../ui/page_footer.dart';
import '../../../ui/press.dart';
import '../dismiss_proposal.dart';
import 'carry_toggle.dart';

/// The two ways out of a changeset, and the count between them. Applying is
/// deterministic — what was accepted is exactly what becomes the proposal.
class ChangesetFooter extends ConsumerWidget {
  const ChangesetFooter({
    super.key,
    required this.projectId,
    required this.ops,
    required this.approved,
    required this.carry,
    required this.stale,
  });
  final String projectId;
  final List<ChangesetOp> ops;
  final List<ChangesetOp> approved;
  final CarryState carry;
  final bool stale;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final writes = ref.watch(chapterPlanWritesProvider(projectId));
    final answers = ref.watch(changesetReviewProvider(projectId));
    final skipped = ops.length - approved.length;
    return PageFooter(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CarryToggle(
            carry: carry,
            onToggle: () => ref.read(changesetReviewProvider(projectId).notifier).setCarry(!carry.checked),
          ),
          const SizedBox(height: 6),
          Text(
            '${approved.length} of ${ops.length} ${ops.length == 1 ? 'change' : 'changes'} accepted'
            '${skipped > 0 ? ' · $skipped skipped' : ''}',
            style: DsStyle.ui(DsText.ui, color: Ds.low),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Press(
                onPressed: writes.dismissing ? null : () => dismissProposal(context, ref, projectId, changeset: true),
                semanticLabel: 'Dismiss changes',
                builder: (context, pressed) => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                  child: Text(
                    writes.dismissing ? 'Dismissing…' : 'Dismiss changes',
                    style: DsStyle.ui(DsText.ui, color: pressed ? Ds.soft : Ds.low),
                  ),
                ),
              ),
              const Spacer(),
              Flexible(
                child: GkButton(
                  label: 'Apply into a chapter plan',
                  busy: writes.applying,
                  disabled: stale,
                  onPressed: () => ref
                      .read(chapterPlanWritesProvider(projectId).notifier)
                      .applyChanges(approved, carry: answers.carry),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
