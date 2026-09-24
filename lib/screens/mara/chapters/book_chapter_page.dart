import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../poltergeist/providers.dart';
import '../../../server/dto/projects.dart';
import '../../../server/providers.dart';
import '../../../ui/room_subtitle.dart';
import '../../../ui/state_screen.dart';
import '../mara_page_frame.dart';
import 'book_chapter_fields.dart';

/// One chapter of the book, full screen: what it is for — its target and its
/// notes, both on its plan row — and what the book already says of it.
class BookChapterPage extends ConsumerWidget {
  const BookChapterPage({super.key, required this.projectId, required this.documentId});
  final String projectId;
  final String documentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tree = ref.watch(projectProvider(projectId)).value?.chapters ?? const <ChaptersListEntry>[];
    final docs = chaptersInTree(tree);
    final at = docs.indexWhere((d) => d.id == documentId);
    final board = ref.watch(planBoardProvider(projectId));
    final row = board.value?.plan.chapters.where((r) => r.documentId == documentId).firstOrNull;
    final doc = at < 0 ? null : docs[at];
    return MaraPageFrame(
      title: doc?.label ?? 'Chapter',
      subtitle: at < 0 ? null : RoomSubtitle('Chapter ${at + 1}'),
      child: switch ((doc, row)) {
        (null, _) => const StateScreen(message: 'This chapter is no longer in the book'),
        (final doc?, final row?) => BookChapterFields(key: ValueKey(row.id), projectId: projectId, doc: doc, row: row),
        (_, null) when board.isLoading => const StateScreen(spinner: true, message: 'Reading the plan…'),
        (_, null) => const StateScreen(
            message: "This chapter's plan row is on its way",
            detail: 'It joins the plan the next time the plan is read against the book.',
          ),
      },
    );
  }
}
