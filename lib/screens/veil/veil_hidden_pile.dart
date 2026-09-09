import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../ds/tokens.dart';
import '../../server/dto/bible.dart';
import '../../ui/press.dart';
import '../../veil/roster.dart';

/// The collapsed pile of hidden entities at the end of the roster. Hides
/// must stay reversible, so the cards never just vanish — but unhiding is a
/// write, and writes wait for the per-entity routes; until then the pile is
/// a list to read.
class VeilHiddenPile extends StatelessWidget {
  const VeilHiddenPile({super.key, required this.entities, required this.open, required this.onToggle});
  final List<BibleEntity> entities;
  final bool open;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final n = entities.length;
    return Container(
      margin: const EdgeInsets.fromLTRB(8, 18, 8, 0),
      padding: const EdgeInsets.only(top: 12),
      decoration: BoxDecoration(border: Border(top: BorderSide(color: Ds.edge))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Press(
            onPressed: onToggle,
            semanticLabel: open ? 'Hide hidden entities' : 'Show hidden entities',
            builder: (context, pressed) => Opacity(
              opacity: pressed ? 0.7 : 1,
              child: Row(
                children: [
                  Icon(open ? LucideIcons.chevronDown : LucideIcons.chevronRight, size: 15, color: Ds.low),
                  const SizedBox(width: 6),
                  Text('$n hidden ${n == 1 ? 'entity' : 'entities'}', style: DsStyle.ui(DsText.ui, color: Ds.low)),
                ],
              ),
            ),
          ),
          if (open)
            for (final entity in entities)
              Container(
                margin: const EdgeInsets.only(top: 6),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                decoration: BoxDecoration(
                  border: Border.all(color: Ds.edge),
                  borderRadius: BorderRadius.circular(DsGeom.radius),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        titleCase(entity.name),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: DsStyle.ui(DsText.ui, color: Ds.low),
                      ),
                    ),
                    Icon(LucideIcons.eyeOff, size: 14, color: Ds.faint),
                  ],
                ),
              ),
        ],
      ),
    );
  }
}
