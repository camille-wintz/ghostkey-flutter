import 'package:flutter/material.dart';

import '../../../ds/tokens.dart';
import '../../../server/dto/plan.dart';

/// One card of a board, read only: a section mark as an eyebrow heading, a
/// beat as its title over what happens there.
class StoryCardTile extends StatelessWidget {
  const StoryCardTile({super.key, required this.card});
  final StoryCard card;

  @override
  Widget build(BuildContext context) {
    if (card.isLabel) {
      return Padding(
        padding: const EdgeInsets.only(left: 4),
        child: Text(card.title, style: DsStyle.prose(DsText.body, weight: FontWeight.w600, color: Ds.hi)),
      );
    }
    final title = card.title.trim();
    final description = card.description.trim();
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Ds.surf,
        border: Border.all(color: Ds.edge),
        borderRadius: BorderRadius.circular(DsGeom.radius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            (title.isEmpty ? 'Untitled card' : title).toUpperCase(),
            style: DsStyle.eyebrow(color: title.isEmpty ? Ds.faint : Ds.soft, weight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          Text(
            description.isEmpty ? 'Nothing here yet.' : description,
            style: DsStyle.ui(DsText.body, color: description.isEmpty ? Ds.low : Ds.ink),
          ),
          if (card.chapters.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(card.chapters.map((c) => c.replaceFirst(RegExp(r'\.md$'), '')).join(' · '), style: DsStyle.ui(DsText.ui, color: Ds.low)),
          ],
        ],
      ),
    );
  }
}
