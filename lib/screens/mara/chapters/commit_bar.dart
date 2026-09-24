import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../ds/tokens.dart';
import '../../../mara/chapter_plan.dart';
import '../../../mara/proposal.dart';
import '../../../server/dto/plan.dart';
import '../../../ui/button.dart';
import '../../../ui/name_sheet.dart';
import '../../../ui/page_footer.dart';
import '../../../ui/press.dart';
import '../dismiss_proposal.dart';
import 'carry_toggle.dart';

const String _defaultDraftName = 'Draft from the outline';

/// The one step that makes something, and the way out of the review. A book
/// with no chapters yet creates at once; one that has chapters is told what
/// the commit does — a new draft, the old one untouched — and names it.
class CommitBar extends ConsumerWidget {
  const CommitBar({
    super.key,
    required this.projectId,
    required this.entries,
    required this.bookIsEmpty,
    required this.blocked,
  });
  final String projectId;
  final List<ProposalEntry> entries;
  final bool bookIsEmpty;

  /// The matches point into another draft: nothing may be committed off them.
  final bool blocked;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final writes = ref.watch(chapterPlanWritesProvider(projectId));
    final notifier = ref.read(chapterPlanWritesProvider(projectId).notifier);
    final chapters = proposalChapters(entries);
    final count = chapters.length;
    final carry = proposalCarry(chapters);

    Future<void> create() async {
      if (bookIsEmpty) return notifier.commit();
      final name = await showNameSheet(
        context,
        eyebrow: 'Create the draft',
        current: '',
        action: 'Create the draft',
        placeholder: _defaultDraftName,
        maxLength: 120,
        allowEmpty: true,
        message:
            "This creates $count ${count == 1 ? 'chapter' : 'chapters'} in a new draft and switches you to it. The draft you're in now keeps every chapter it has. Everyone named on a card is attached to its chapter in your world bible.",
      );
      if (name == null) return;
      await notifier.commit(draftName: name.isEmpty ? _defaultDraftName : name);
    }

    return PageFooter(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // No earlier draft means no words to carry, so the question isn't asked.
          if (!bookIsEmpty) ...[
            CarryToggle(carry: carry, onToggle: () => notifier.edit((e) => withCarry(e, !carry.checked))),
            const SizedBox(height: 8),
          ],
          Row(
            children: [
              Press(
                onPressed: writes.dismissing ? null : () => dismissProposal(context, ref, projectId, changeset: false),
                semanticLabel: 'Dismiss',
                builder: (context, pressed) => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                  child: Text(
                    writes.dismissing ? 'Dismissing…' : 'Dismiss',
                    style: DsStyle.ui(DsText.ui, color: pressed ? Ds.soft : Ds.low),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              const Spacer(),
              Flexible(
                flex: 4,
                child: GkButton(
                  label: 'Create $count ${count == 1 ? 'chapter' : 'chapters'}',
                  busy: writes.committing,
                  disabled: blocked || count == 0 || writes.saving,
                  onPressed: create,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
