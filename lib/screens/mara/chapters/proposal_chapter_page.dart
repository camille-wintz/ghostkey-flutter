import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../mara/providers.dart';
import '../../../server/dto/plan.dart';
import '../../../ui/room_subtitle.dart';
import '../../../ui/state_screen.dart';
import '../mara_page_frame.dart';
import 'proposal_chapter_fields.dart';

/// One proposed chapter, full screen: its title and notes, what the book
/// already has for it, and the way to take it out of the proposal.
class ProposalChapterPage extends ConsumerWidget {
  const ProposalChapterPage({super.key, required this.projectId, required this.chapterId});
  final String projectId;
  final String chapterId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chapters = proposalChapters(ref.watch(authoredOutlineProvider(projectId)).value?.chapters ?? const []);
    final at = chapters.indexWhere((c) => c.id == chapterId);
    return MaraPageFrame(
      title: 'Proposed chapter',
      subtitle: at < 0 ? null : RoomSubtitle('Chapter ${at + 1} of ${chapters.length}'),
      child: at < 0
          ? const StateScreen(message: 'This chapter is no longer in the proposal')
          : ProposalChapterFields(key: ValueKey(chapterId), projectId: projectId, chapter: chapters[at]),
    );
  }
}
