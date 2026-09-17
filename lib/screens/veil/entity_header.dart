import 'package:flutter/material.dart';

import '../../ds/tokens.dart';
import '../../server/dto/bible.dart';

/// What the entity answers to besides its name: its aliases, and the
/// manuscript's own spelling when the author corrected it. The name itself,
/// its type and its presence ride in the [VeilHeader] above the page.
///
/// No one-line summary, though the desktop's roster once carried one: the
/// dossier's own opening paragraph is a few centimetres below, and the
/// summary is its first sentence.
class EntityHeader extends StatelessWidget {
  const EntityHeader({super.key, required this.entity});
  final BibleEntity entity;

  /// Whether there is anything for this block to say at all.
  static bool hasContent(BibleEntity entity) => entity.aliases.isNotEmpty || _renamed(entity);

  static bool _renamed(BibleEntity entity) =>
      !entity.isUser && entity.extractedName.isNotEmpty && entity.name != entity.extractedName;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (entity.aliases.isNotEmpty)
            Wrap(
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
          if (_renamed(entity))
            Padding(
              padding: EdgeInsets.only(top: entity.aliases.isNotEmpty ? 12 : 0),
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
      );
}
