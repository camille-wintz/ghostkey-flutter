import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../ds/tokens.dart';
import '../../server/dto/bible.dart';
import '../../ui/press.dart';
import '../../veil/roster.dart';
import 'entity_portrait.dart';

/// One tie on the entity page: the tied card's portrait and name, how they
/// are tied under it. Reading, the whole card opens that entity; editing
/// ([onRemove] given), it holds still and carries a remove. The add-a-tie
/// sheet lists its candidates with it too, their kind in the relation's
/// place. The phone web's `TieCard.tsx`.
class TieCard extends StatelessWidget {
  const TieCard({
    super.key,
    required this.entity,
    required this.relation,
    required this.seriesId,
    required this.onOpen,
    this.onRemove,
    this.disabled = false,
  });

  final BibleEntity entity;
  final String relation;
  final String? seriesId;
  final VoidCallback onOpen;

  /// Present while editing: the tie's remove button.
  final VoidCallback? onRemove;

  /// A write is in flight; the remove waits for it.
  final bool disabled;

  @override
  Widget build(BuildContext context) {
    final name = titleCase(entity.name);
    final body = [
      EntityPortrait(seriesId: seriesId, assetId: entity.imageAssetId, initial: name, size: 28),
      const SizedBox(width: 10),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: DsStyle.prose(DsText.body, color: Ds.ink)),
            if (relation.isNotEmpty)
              Text(relation, maxLines: 2, overflow: TextOverflow.ellipsis, style: DsStyle.ui(DsText.ui, color: Ds.low)),
          ],
        ),
      ),
    ];

    final onRemove = this.onRemove;
    if (onRemove == null) {
      return Press(
        onPressed: onOpen,
        semanticLabel: relation.isEmpty ? name : '$name, $relation',
        builder: (context, pressed) => AnimatedContainer(
          duration: DsMotion.duration,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: pressed ? Ds.raise : Ds.surf,
            border: Border.all(color: pressed ? Ds.accentMix(25) : Ds.edge),
            borderRadius: BorderRadius.circular(DsGeom.radius),
          ),
          child: Row(children: body),
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
      decoration: BoxDecoration(
        color: Ds.surf,
        border: Border.all(color: Ds.edge),
        borderRadius: BorderRadius.circular(DsGeom.radius),
      ),
      child: Row(
        children: [
          ...body,
          Press(
            onPressed: onRemove,
            enabled: !disabled,
            semanticLabel: 'Remove the tie to $name',
            builder: (context, pressed) => Opacity(
              opacity: disabled ? 0.45 : 1,
              child: Container(
                width: DsGeom.row,
                height: DsGeom.row,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: pressed ? Ds.veil : const Color(0x00000000),
                  borderRadius: BorderRadius.circular(DsGeom.radius),
                ),
                child: Icon(LucideIcons.x, size: 18, color: Ds.low),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
