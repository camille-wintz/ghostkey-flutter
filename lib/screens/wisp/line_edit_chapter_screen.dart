import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../chat/review/providers.dart';
import '../../ds/tokens.dart';
import '../../server/dto/projects.dart';
import '../../ui/room_bar_action.dart';
import '../../ui/room_subtitle.dart';
import '../../ui/room_title_bar.dart';
import '../phantom/review/chapter_review.dart';
import 'line_edit_sheet.dart';

/// One chapter's line edit, pushed over Wisp: PhantomMemory's chapter review
/// — the notes to rule on when a pass has finished, the chapter and where its
/// pass stands otherwise — with the way to start a pass in the bar.
class LineEditChapterScreen extends ConsumerWidget {
  const LineEditChapterScreen({super.key, required this.projectId, required this.chapter});
  final String projectId;
  final DocumentSummary chapter;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final job = ref.watch(editPassJobProvider((projectId: projectId, subject: chapter.id))).value;
    final running = job?.isRunning ?? false;

    return Scaffold(
      backgroundColor: Ds.void_,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            RoomTitleBar(
              title: chapter.label,
              subtitle: const RoomSubtitle('Line editing'),
              onBack: () => Navigator.of(context).pop(),
              trailing: running
                  ? null
                  : RoomBarAction(
                      icon: LucideIcons.penLine,
                      semanticLabel: 'Line edit this chapter',
                      onPressed: () => showLineEditSheet(context, projectId: projectId, chapter: chapter),
                    ),
            ),
            Expanded(child: ChapterReview(projectId: projectId, documentId: chapter.id)),
          ],
        ),
      ),
    );
  }
}
