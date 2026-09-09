import 'package:flutter/material.dart';

import '../../ds/tokens.dart';
import '../../server/dto/bible.dart';
import '../../server/dto/projects.dart';
import '../../veil/tone.dart';
import 'veil_section.dart';

/// Where in the book this entity actually is: one tick per chapter, in
/// manuscript order, lit where the extraction found it and dimmer where it
/// is only expected — planned by the author (DOCUMENT ID) or named in the
/// chapter's note (FILENAME). The three sets are the desktop's, kept
/// distinct; planned and noted share a shade on purpose, because to the eye
/// scanning the strip both mean "meant to be here, not here yet".
class EntityPresence extends StatelessWidget {
  const EntityPresence({super.key, required this.entity, required this.chapters});
  final BibleEntity entity;

  /// The book's chapters, folders flattened, in reading order.
  final List<DocumentSummary> chapters;

  @override
  Widget build(BuildContext context) {
    final appears = entity.chapters.toSet();
    final planned = entity.plannedChapters.toSet();
    final noted = entity.notedChapters.toSet();
    final lit = typeTone(entity.type);

    return VeilSection(
      title: 'Through the book',
      trailing: Text('${entity.mentionCount}/${chapters.length}', style: DsStyle.ui(DsText.eyebrow, color: Ds.faint)),
      child: Semantics(
        label: 'Appears in ${entity.mentionCount} of ${chapters.length} chapters',
        child: Row(
          children: [
            for (final chapter in chapters)
              Expanded(
                child: Container(
                  height: 14,
                  margin: const EdgeInsets.symmetric(horizontal: 0.5),
                  decoration: BoxDecoration(
                    color: appears.contains(chapter.filename)
                        ? lit
                        : (planned.contains(chapter.id) || noted.contains(chapter.filename))
                            ? Ds.accentMix(25)
                            : Ds.veilHi,
                    borderRadius: BorderRadius.circular(1),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
