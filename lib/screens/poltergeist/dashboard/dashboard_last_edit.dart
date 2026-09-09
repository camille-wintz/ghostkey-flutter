import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/words.dart';
import '../../../ds/tokens.dart';
import '../../../poltergeist/providers.dart';
import '../../../poltergeist/time.dart';
import '../../../server/dto/projects.dart';
import '../../../server/providers.dart';
import '../project_scope_id.dart';
import 'dashboard_section.dart';

/// Where the writer left off: the last chapter touched, its place and size,
/// and what pass it still owes. The desktop adds a change note written by
/// the flash model; the phone reads the tree it already has and says no
/// more than it knows.
class DashboardLastEdit extends ConsumerWidget {
  const DashboardLastEdit({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projectId = projectIdOf(context);
    final project = ref.watch(projectProvider(projectId)).value;
    final plan = ref.watch(planBoardProvider(projectId)).value?.plan;

    final chapters = project == null ? const <DocumentSummary>[] : chaptersInTree(project.chapters);
    DocumentSummary? latest;
    var position = 0;
    for (var i = 0; i < chapters.length; i++) {
      if (latest == null || chapters[i].updatedAt.compareTo(latest.updatedAt) > 0) {
        latest = chapters[i];
        position = i + 1;
      }
    }
    final owed = latest == null
        ? null
        : plan?.chapters.where((c) => c.documentId == latest!.id).firstOrNull?.action;

    return DashboardSection(
      eyebrow: 'Where you left off',
      child: project == null
          ? const SectionNote('Loading…')
          : latest == null
              ? const SectionNote('No chapters yet.', italic: true)
              : _Card(chapter: latest, position: position, owed: owed),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.chapter, required this.position, required this.owed});
  final DocumentSummary chapter;
  final int position;
  final PlanActionKind? owed;

  @override
  Widget build(BuildContext context) {
    final metaStyle = DsStyle.ui(DsText.eyebrow, color: Ds.low, tracking: 11 * 0.10)
        .copyWith(fontFeatures: const [FontFeature.tabularFigures()]);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Expanded(
              child: Text(
                chapter.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: DsStyle.prose(DsText.prose),
              ),
            ),
            const SizedBox(width: 12),
            Text(relativeTime(chapter.updatedAt), style: DsStyle.ui(DsText.ui, color: Ds.low)),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 14,
          children: [
            Text('CH. $position', style: metaStyle),
            if (chapter.wordCount != null) Text('${formatWords(chapter.wordCount!)} WORDS', style: metaStyle),
            if (owed != null)
              Text(
                '${owed!.wire.replaceAll('_', ' ')} OWED'.toUpperCase(),
                style: metaStyle.copyWith(color: Ds.accent600),
              ),
          ],
        ),
      ],
    );
  }
}
