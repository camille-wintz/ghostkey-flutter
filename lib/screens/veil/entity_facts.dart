import 'package:flutter/material.dart';

import '../../ds/tokens.dart';
import '../../server/dto/bible.dart';
import '../../ui/text.dart';
import '../../veil/roster.dart';

/// The fixed, always-knowable things about an entity — derived from the
/// bible itself, never from a model. The card's spine, so the prose below
/// never has to restate where something first appears. Kind, chapter count and
/// first appearance sit under the name in the [VeilHeader]; these are the rest.
/// Where the card came from is a reading fact, left out while the page is
/// edited; the page leaves the block out when nothing is left ([hasContent]).
class EntityFacts extends StatelessWidget {
  const EntityFacts({super.key, required this.entity, required this.editing});
  final BibleEntity entity;
  final bool editing;

  /// Whether there is any fact to show.
  static bool hasContent(BibleEntity entity, {required bool editing}) => _facts(entity, editing: editing).isNotEmpty;

  static List<(String, String)> _facts(BibleEntity entity, {required bool editing}) {
    // Only worth a row where it says something the others don't: chapters
    // the plan puts this entity in that it isn't already written into.
    final notedOnly = entity.notedChapters.where((f) => !entity.chapters.contains(f)).length;
    return [
      if (!editing) ('Source', entity.isUser ? 'Added by you' : 'Found in the manuscript'),
      if (entity.plannedChapters.isNotEmpty) ('Planned for', chapterCount(entity.plannedChapters.length)),
      if (notedOnly > 0) ('In your notes for', '${chapterCount(notedOnly)} not yet written'),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final facts = _facts(entity, editing: editing);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (label, value) in facts)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Eyebrow(label, color: Ds.faint, semibold: false),
                const SizedBox(height: 2),
                Text(value, style: DsStyle.ui(DsText.body, color: Ds.soft)),
              ],
            ),
          ),
      ],
    );
  }
}
