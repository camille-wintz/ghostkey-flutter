import 'package:flutter/material.dart';

import '../../ds/tokens.dart';
import '../../server/dto/bible.dart';
import '../../ui/press.dart';
import '../../veil/roster.dart';
import 'entity_portrait.dart';

/// One entity in the roster: its portrait and its name, and nothing else —
/// the desktop's `BibleNavItem`. The dossier summary, the chapter count and
/// the presence bar used to ride along, and together they turned a list meant
/// to be scanned for a name into a column of prose. The entity's page is
/// where all three are read.
class VeilEntityRow extends StatelessWidget {
  const VeilEntityRow({super.key, required this.entity, required this.seriesId, required this.onOpen});

  final BibleEntity entity;
  final String? seriesId;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final name = titleCase(entity.name);
    return Press(
      onPressed: onOpen,
      semanticLabel: name,
      builder: (context, pressed) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: pressed ? Ds.veil : const Color(0x00000000),
          borderRadius: BorderRadius.circular(DsGeom.radius),
        ),
        child: Row(
          children: [
            EntityPortrait(seriesId: seriesId, assetId: entity.imageAssetId, initial: name, size: 36),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: DsStyle.prose(DsText.body, color: Ds.ink),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
