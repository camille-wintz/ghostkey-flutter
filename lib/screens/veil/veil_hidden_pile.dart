import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../ds/tokens.dart';
import '../../server/dto/bible.dart';
import '../../ui/press.dart';
import '../../veil/roster.dart';

/// The collapsed pile of hidden entities at the end of the roster. Hides
/// must stay reversible, so the cards never just vanish: each one here can
/// be brought back.
class VeilHiddenPile extends StatelessWidget {
  const VeilHiddenPile({
    super.key,
    required this.entities,
    required this.open,
    required this.onToggle,
    required this.onUnhide,
  });
  final List<BibleEntity> entities;
  final bool open;
  final VoidCallback onToggle;
  final Future<void> Function(BibleEntity entity) onUnhide;

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
                padding: const EdgeInsets.only(left: 12),
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
                    Press(
                      onPressed: () => onUnhide(entity),
                      semanticLabel: 'Unhide ${titleCase(entity.name)}',
                      builder: (context, pressed) => Container(
                        height: DsGeom.row,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        color: pressed ? Ds.veil : const Color(0x00000000),
                        child: Row(
                          children: [
                            Icon(LucideIcons.eye, size: 14, color: Ds.low),
                            const SizedBox(width: 6),
                            Text('Unhide', style: DsStyle.ui(DsText.ui, color: Ds.low)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
        ],
      ),
    );
  }
}
