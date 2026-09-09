import 'package:flutter/material.dart';

import '../../ds/tokens.dart';
import '../../server/dto/bible.dart';
import '../../ui/press.dart';
import '../../veil/roster.dart';
import 'entity_portrait.dart';
import 'entity_screen.dart';
import 'veil_section.dart';

/// Who and what this entity is bound to, per its dossier. Ties arrive
/// resolved to roster keys, but the roster moves under them: one hidden or
/// renamed since the dossier was written no longer has a page, and is
/// dropped rather than drawn as a card that bounces back. Tapping one opens
/// that entity's page on top of this one.
class EntityTies extends StatelessWidget {
  const EntityTies({super.key, required this.ties, required this.entities, required this.seriesId});
  final List<DossierTie> ties;
  final List<BibleEntity> entities;
  final String? seriesId;

  @override
  Widget build(BuildContext context) {
    final resolved = [
      for (final tie in ties)
        for (final entity in entities.where((e) => e.key == tie.key && !e.hidden).take(1)) (tie, entity),
    ];
    if (resolved.isEmpty) return const SizedBox.shrink();

    return VeilSection(
      title: 'Ties',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (i, (tie, entity)) in resolved.indexed)
            Padding(
              padding: EdgeInsets.only(top: i == 0 ? 0 : 8),
              child: _TieCard(
                entity: entity,
                relation: tie.relation,
                seriesId: seriesId,
                onOpen: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => EntityScreen(entityKey: entity.key)),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _TieCard extends StatelessWidget {
  const _TieCard({required this.entity, required this.relation, required this.seriesId, required this.onOpen});
  final BibleEntity entity;
  final String relation;
  final String? seriesId;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final name = titleCase(entity.name);
    return Press(
      onPressed: onOpen,
      semanticLabel: '$name, $relation',
      builder: (context, pressed) => AnimatedContainer(
        duration: DsMotion.duration,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: pressed ? Ds.raise : Ds.surf,
          border: Border.all(color: pressed ? Ds.accentMix(25) : Ds.edge),
          borderRadius: BorderRadius.circular(DsGeom.radius),
        ),
        child: Row(
          children: [
            EntityPortrait(seriesId: seriesId, assetId: entity.imageAssetId, initial: name, size: 28),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: DsStyle.prose(DsText.body, color: Ds.ink)),
                  Text(relation, maxLines: 2, overflow: TextOverflow.ellipsis, style: DsStyle.ui(DsText.ui, color: Ds.low)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
