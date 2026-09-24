import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../ds/tokens.dart';
import '../../../mara/chapter_plan.dart';
import '../../../mara/changeset.dart';
import '../../../mara/changeset_review.dart';
import '../../../server/dto/plan.dart';
import '../../../server/dto/projects.dart';
import '../../../ui/page_notice.dart';
import 'book_chapter_page.dart';
import 'changeset_badges.dart';
import 'changeset_chapter_page.dart';
import 'changeset_footer.dart';
import 'changeset_header.dart';
import 'changeset_op_card.dart';
import 'chapter_row_tile.dart';
import 'part_heading.dart';

/// A changeset laid over the book: every chapter the draft has, in its part;
/// what is removed marked, what is rewritten standing in its place, what is
/// new where it will land; each change skippable until the apply.
class ChangesetView extends ConsumerWidget {
  const ChangesetView({super.key, required this.projectId, required this.outline, required this.project});
  final String projectId;
  final AuthoredOutline outline;
  final ProjectFull project;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final changeset = outline.changeset!;
    final answers = ref.watch(changesetReviewProvider(projectId));
    final error = ref.watch(chapterPlanWritesProvider(projectId).select((s) => s.error));
    final tree = project.chapters;
    final rows = overlayChangeset(tree, changeset.ops, answers.isSkipped);
    final approved = answers.approved(changeset.ops);
    final carry = changesetCarry(changesetCarryCounts(tree, approved), answers.carry);
    final stale = outline.changesetDraftId != null && outline.changesetDraftId != project.project.activeDraftId;
    final review = ref.read(changesetReviewProvider(projectId).notifier);

    void push(Widget page) => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));
    void openOp(String opId, [int? index]) => push(ChangesetChapterPage(projectId: projectId, opId: opId, index: index));

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(12, 14, 12, 32),
            children: [
              ChangesetHeader(changeset: changeset, intent: outline.intent, stale: stale),
              if (error != null) ...[const SizedBox(height: 12), PageNotice(error, error: true)],
              const SizedBox(height: 14),
              for (final row in rows)
                switch (row) {
                  OverlayPart(:final name) => PartHeading(name: name),
                  OverlayChapter(:final doc, :final number, :final removedBy) => ChapterRowTile(
                      number: number,
                      title: doc.label,
                      badge: removedBy == null ? null : 'removed',
                      badgeColor: Ds.destructive,
                      dimmed: removedBy != null,
                      onTap: () => push(BookChapterPage(projectId: projectId, documentId: doc.id)),
                    ),
                  OverlayRewrite(:final op, :final number) => ChapterRowTile(
                      number: number,
                      title: [for (var i = 0; i < op.written.length; i++) answers.written(op, i).title].join(' · '),
                      badge: opBadge(op).label,
                      badgeColor: opBadge(op).color,
                      onTap: () => openOp(op.id),
                    ),
                  OverlayAdded(:final op, :final index) => ChapterRowTile(
                      title: answers.written(op, index).title,
                      badge: opBadge(op).label,
                      badgeColor: opBadge(op).color,
                      tint: Ds.accentMix(5),
                      onTap: () => openOp(op.id, index),
                    ),
                  OverlayOp(:final op, :final orphan) => ChangesetOpCard(
                      op: op,
                      orphan: orphan,
                      skipped: answers.isSkipped(op.id),
                      onToggle: () => review.toggleSkipped(op.id),
                      onOpen: op is ChangesetWrite ? () => openOp(op.id) : null,
                    ),
                },
            ],
          ),
        ),
        ChangesetFooter(projectId: projectId, ops: changeset.ops, approved: approved, carry: carry, stale: stale),
      ],
    );
  }
}
