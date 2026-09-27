import 'package:flutter/material.dart';

import '../../ds/tokens.dart';
import '../../server/dto/bible.dart';

/// What the entity answers to besides its name: its aliases, and the
/// manuscript's own spelling when the author corrected it. The name itself,
/// its type and its presence ride in the [VeilHeader] above the page. The
/// aliases are a reading fact and the corrected spelling an editing one, so
/// each shows only in its own mode.
///
/// No one-line summary, though the desktop's roster once carried one: the
/// dossier's own opening paragraph is a few centimetres below, and the
/// summary is its first sentence.
class EntityHeader extends StatelessWidget {
  const EntityHeader({super.key, required this.entity, this.editing = false});
  final BibleEntity entity;
  final bool editing;

  /// Whether there is anything for this block to say at all.
  static bool hasContent(BibleEntity entity, {bool editing = false}) =>
      editing ? _renamed(entity) : entity.aliases.isNotEmpty;

  static bool _renamed(BibleEntity entity) =>
      !entity.isUser && entity.extractedName.isNotEmpty && entity.name != entity.extractedName;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!editing && entity.aliases.isNotEmpty)
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
          if (editing && _renamed(entity))
            Text.rich(
              TextSpan(
                style: DsStyle.ui(DsText.ui, color: Ds.low),
                children: [
                  const TextSpan(text: 'Renamed from '),
                  TextSpan(text: entity.extractedName, style: TextStyle(color: Ds.mid)),
                  const TextSpan(text: " — the manuscript's own spelling still matches this card."),
                ],
              ),
            ),
        ],
      );
}
