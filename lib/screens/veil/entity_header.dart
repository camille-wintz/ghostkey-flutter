import 'package:flutter/material.dart';

import '../../ds/tokens.dart';
import '../../server/dto/bible.dart';
import '../../ui/text.dart';
import '../../veil/roster.dart';
import '../../veil/tone.dart';

/// The entity's identity block: what kind of thing it is, how present it
/// is, its name and the other names it answers to. No one-line summary,
/// though the roster row carries one: the dossier's own opening paragraph
/// is a few centimetres below, and the summary is its first sentence.
class EntityHeader extends StatelessWidget {
  const EntityHeader({super.key, required this.entity});
  final BibleEntity entity;

  @override
  Widget build(BuildContext context) {
    final renamed = !entity.isUser && entity.extractedName.isNotEmpty && entity.name != entity.extractedName;
    final presence = [
      chapterCount(entity.mentionCount),
      if (entity.firstAppearance != null) 'first in ${chapterLabel(entity.firstAppearance!)}',
      if (entity.plannedChapters.isNotEmpty) '${entity.plannedChapters.length} planned',
    ].join(' · ');

    return Container(
      padding: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Ds.edge))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 6,
                height: 6,
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(color: typeTone(entity.type), shape: BoxShape.circle),
              ),
              Eyebrow('${entity.type.label}${entity.isUser ? ' · added by you' : ''}', semibold: false),
            ],
          ),
          const SizedBox(height: 4),
          Text(presence, style: DsStyle.ui(DsText.ui, color: Ds.faint)),
          const SizedBox(height: 10),
          BrandTitle(titleCase(entity.name)),
          if (entity.aliases.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final alias in entity.aliases)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        border: Border.all(color: Ds.edge),
                        borderRadius: BorderRadius.circular(DsGeom.radius),
                      ),
                      child: Text(alias, style: DsStyle.ui(DsText.ui, color: Ds.mid)),
                    ),
                ],
              ),
            ),
          if (renamed)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text.rich(
                TextSpan(
                  style: DsStyle.ui(DsText.ui, color: Ds.low),
                  children: [
                    const TextSpan(text: 'Renamed from '),
                    TextSpan(text: entity.extractedName, style: TextStyle(color: Ds.mid)),
                    const TextSpan(text: " — the manuscript's own spelling still matches this card."),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
