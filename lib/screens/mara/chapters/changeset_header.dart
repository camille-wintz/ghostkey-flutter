import 'package:flutter/material.dart';

import '../../../ds/tokens.dart';
import '../../../mara/changeset.dart';
import '../../../server/dto/plan.dart';
import '../../../ui/page_notice.dart';
import '../../../ui/text.dart';

/// What the changeset is, before the changes: the request it answers, what
/// it changes, how big that is, and what is still open.
class ChangesetHeader extends StatelessWidget {
  const ChangesetHeader({super.key, required this.changeset, required this.intent, required this.stale});
  final Changeset changeset;
  final String intent;

  /// The ops point into a draft that is no longer the one being written.
  final bool stale;

  @override
  Widget build(BuildContext context) {
    final count = changeset.ops.length;
    final ledger = changeset.ledger;
    final problems = changeset.verdict?.ok == false ? changeset.verdict!.problems : const <String>[];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (stale)
          const PageNotice(
            "These changes were read against a different draft — they name chapters you're no longer writing in. Ask the chat again to compare the request with this one.",
          ),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Ds.panel,
            border: Border.all(color: Ds.edge),
            borderRadius: BorderRadius.circular(DsGeom.radius),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (intent.trim().isNotEmpty) ...[
                const Eyebrow('Your request'),
                const SizedBox(height: 4),
                Text(intent.trim(), style: DsStyle.prose(DsText.body, color: Ds.mid)),
                const SizedBox(height: 12),
              ],
              const Eyebrow('What changes'),
              const SizedBox(height: 6),
              Text(
                changeset.summary.isNotEmpty ? changeset.summary : 'Here is how your request changes the book.',
                style: DsStyle.prose(DsText.body, color: Ds.hi).copyWith(height: 1.5),
              ),
              const SizedBox(height: 8),
              UiText(
                switch ((ledger, count)) {
                  (final ledger?, 0) => 'No changes — all ${ledger.chaptersBefore} chapters stay as they are.',
                  (final ledger?, _) => ledgerLine(ledger),
                  (null, 0) => 'No changes — the book stays as it is.',
                  (null, _) => 'Everything not marked below stays exactly as it is.',
                },
                step: DsText.ui,
                color: Ds.low,
              ),
            ],
          ),
        ),
        if (changeset.questions.isNotEmpty) ...[
          const SizedBox(height: 12),
          _Section(
            title: changeset.questions.length == 1 ? 'One question' : '${changeset.questions.length} questions',
            color: Ds.accent300,
            lines: changeset.questions,
            footnote: 'Answer them in the chat, and the changes are revised.',
          ),
        ],
        if (problems.isNotEmpty) ...[
          const SizedBox(height: 12),
          _Section(title: 'Read back against your plan, this proposal still', color: Ds.attention300, lines: problems),
        ],
      ],
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.color, required this.lines, this.footnote});
  final String title;
  final Color color;
  final List<String> lines;
  final String? footnote;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: color.withValues(alpha: 0.35)),
          borderRadius: BorderRadius.circular(DsGeom.radius),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Eyebrow(title, color: color),
            const SizedBox(height: 8),
            for (final line in lines)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(line, style: DsStyle.prose(DsText.body, color: Ds.hi)),
              ),
            if (footnote case final footnote?) UiText(footnote, step: DsText.ui, color: Ds.low),
          ],
        ),
      );
}
