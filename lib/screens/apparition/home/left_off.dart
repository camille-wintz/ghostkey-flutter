import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/dates.dart';
import '../../../core/words.dart';
import '../../../ds/tokens.dart';
import '../../../next_scene/next_scene_finder.dart';
import '../../../server/dto/next_scene.dart';
import '../../../server/dto/projects.dart';
import '../../../server/providers.dart';
import '../../../ui/press.dart';
import '../../project/project_root.dart';
import 'cat_tile.dart';
import 'home_section.dart';

/// Where the writer left off: the last chapter touched, its place and size,
/// and a tap back into it, with the latest cat beside it — with "Find me a scene to write" beside it, its
/// answer unfolding underneath. The desk adds a change note written by the
/// flash model from the chapter's previous snapshot; that note is the desk's
/// own (its main process writes it, there is no server route), so the phone
/// says no more than the chapter list knows.
///
/// A book with no chapters never shows the home: the list gives way to the
/// "Start writing" card (start_writing.dart).
///
/// "Find me a scene to write" and its answer are hidden since 2026-10-08
/// (Cleo); the finder and its callbacks are still taken, so they come back
/// with a line.
class LeftOff extends ConsumerWidget {
  const LeftOff({
    super.key,
    required this.finder,
    required this.onOpen,
    required this.onWrite,
    required this.onStuck,
    required this.stuckPending,
  });
  final NextSceneFinder finder;
  final ValueChanged<String> onOpen;
  final ValueChanged<NextScene> onWrite;
  final ValueChanged<NextScene> onStuck;
  final bool stuckPending;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final project = ref.watch(projectProvider(ProjectScope.of(context))).value;
    final chapters = project == null ? const <DocumentSummary>[] : chaptersInTree(project.chapters);
    DocumentSummary? latest;
    var position = 0;
    for (var i = 0; i < chapters.length; i++) {
      if (latest == null || chapters[i].updatedAt.compareTo(latest.updatedAt) > 0) {
        latest = chapters[i];
        position = i + 1;
      }
    }
    if (latest == null) return const SizedBox.shrink();
    final chapter = latest;

    return HomeSection(
      eyebrow: 'Where you left off',
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: _Card(chapter: chapter, position: position, onOpen: () => onOpen(chapter.filename))),
            const SizedBox(width: 10),
            const CatTile(),
          ],
        ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.chapter, required this.position, required this.onOpen});
  final DocumentSummary chapter;
  final int position;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final metaStyle = DsStyle.ui(DsText.eyebrow, color: Ds.low, tracking: 11 * 0.10)
        .copyWith(fontFeatures: const [FontFeature.tabularFigures()]);
    return Press(
      onPressed: onOpen,
      semanticLabel: 'Open ${chapter.label}',
      builder: (context, pressed) => AnimatedContainer(
        duration: DsMotion.duration,
        decoration: BoxDecoration(
          color: pressed ? Ds.raise : Ds.panel,
          borderRadius: BorderRadius.circular(DsGeom.radius),
          border: Border.all(color: pressed ? Ds.edgeHi : Ds.edge),
        ),
        padding: const EdgeInsets.fromLTRB(18, 14, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              chapter.label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: DsStyle.prose(const DsStep(19, 26)),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 12,
              runSpacing: 6,
              children: [
                Text('CH. $position', style: metaStyle),
                if (chapter.wordCount != null) Text('${formatWords(chapter.wordCount!)} WORDS', style: metaStyle),
                Text(relativeTime(chapter.updatedAt).toUpperCase(), style: metaStyle),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
