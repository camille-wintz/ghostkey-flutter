import 'package:flutter/material.dart';

import '../../ds/tokens.dart';
import '../../server/dto/bible.dart';
import '../../ui/text.dart';
import '../../veil/roster.dart';

/// The fixed, always-knowable things about an entity — derived from the
/// bible itself, never from a model. The card's spine, so the prose below
/// never has to restate where something first appears.
class EntityFacts extends StatelessWidget {
  const EntityFacts({super.key, required this.entity});
  final BibleEntity entity;

  @override
  Widget build(BuildContext context) {
    // Only worth a row where it says something the others don't: chapters
    // the plan puts this entity in that it isn't already written into.
    final notedOnly = entity.notedChapters.where((f) => !entity.chapters.contains(f)).length;
    final facts = <(String, String)>[
      ('Kind', entity.type.label),
      ('Source', entity.isUser ? 'Added by you' : 'Found in the manuscript'),
      if (entity.firstAppearance != null) ('First seen', chapterLabel(entity.firstAppearance!)),
      ('Chapters', entity.mentionCount == 0 ? 'None in this book' : '${entity.mentionCount} in this book'),
      if (entity.plannedChapters.isNotEmpty) ('Planned for', chapterCount(entity.plannedChapters.length)),
      if (notedOnly > 0) ('In your notes for', '${chapterCount(notedOnly)} not yet written'),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (label, value) in facts)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Ds.edge))),
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
