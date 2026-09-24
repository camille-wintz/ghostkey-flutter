import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../mara/chapter_plan.dart';
import '../../../mara/providers.dart';
import '../../../server/providers.dart';
import '../../../ui/room_subtitle.dart';
import '../../project/project_root.dart';
import '../mara_page_frame.dart';
import 'chapters_view.dart';

/// The Chapters page: the plan's chapters, whichever face is up — a
/// changeset, a proposal, the book, or nothing yet.
class ChaptersPage extends ConsumerWidget {
  const ChaptersPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projectId = ProjectScope.of(context);
    final outline = ref.watch(authoredOutlineProvider(projectId)).value;
    final tree = ref.watch(projectProvider(projectId)).value?.chapters;
    final status = outline == null || tree == null ? '' : chaptersStatusLine(outline, tree);
    return MaraPageFrame(
      title: 'Chapters',
      subtitle: status.isEmpty ? null : RoomSubtitle(status),
      child: ChaptersView(projectId: projectId),
    );
  }
}
