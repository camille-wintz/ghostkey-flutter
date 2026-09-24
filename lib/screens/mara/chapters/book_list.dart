import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../ds/tokens.dart';
import '../../../mara/book.dart';
import '../../../mara/chapter_plan.dart';
import '../../../mara/proposal.dart';
import '../../../poltergeist/plan_board.dart';
import '../../../poltergeist/providers.dart';
import '../../../server/dto/projects.dart';
import '../../../server/errors.dart';
import '../../../server/providers.dart';
import '../../../ui/page_notice.dart';
import 'book_chapter_page.dart';
import 'chapter_row_tile.dart';
import 'commit_receipt.dart';
import 'part_heading.dart';

/// The book as it stands: every chapter in its part, with its target. Order
/// and parts are Apparition's; a chapter opens onto what it is for.
class BookList extends ConsumerWidget {
  const BookList({super.key, required this.projectId, required this.tree});
  final String projectId;
  final List<ChaptersListEntry> tree;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final board = ref.watch(planBoardProvider(projectId));
    final receipt = ref.watch(chapterPlanWritesProvider(projectId).select((s) => s.committed));
    final error = ref.watch(chapterPlanWritesProvider(projectId).select((s) => s.error));
    final rows = bookRows(tree, board.value?.plan);

    return RefreshIndicator(
      color: Ds.accent,
      backgroundColor: Ds.panel,
      onRefresh: () => ref.refresh(projectProvider(projectId).future),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(8, 14, 8, 40),
        children: [
          if (receipt != null) CommitReceiptBanner(projectId: projectId, receipt: receipt),
          if (error != null) Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: PageNotice(error, error: true)),
          if (board.error case final e?)
            Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: PageNotice(_planError(e), error: true)),
          for (final row in rows)
            switch (row) {
              BookPartRow(:final name) => PartHeading(name: name),
              BookChapterRow(:final doc, :final number, :final row) => ChapterRowTile(
                  number: number,
                  title: doc.label,
                  measure: row?.targetWords == null ? null : '${wordLabel(row!.targetWords)} target',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(builder: (_) => BookChapterPage(projectId: projectId, documentId: doc.id)),
                  ),
                ),
            },
        ],
      ),
    );
  }

  static String _planError(Object e) => switch (e) {
        PlanFormatUnsupported() => 'The plan was written by a newer version of Ghostkey; update the app to edit notes here.',
        PlanLoadFailed(:final cause) || PlanSeedFailed(:final cause) => "The plan couldn't be read: ${messageFor(cause)}",
        _ => "The plan couldn't be read: ${messageFor(e)}",
      };
}
