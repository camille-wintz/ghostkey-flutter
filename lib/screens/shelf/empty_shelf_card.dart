import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../ds/tokens.dart';
import '../../rooms/rooms.dart';
import '../../ui/press.dart';

/// What the shelf shows when there is no shelf (the desk's `EmptyShelfCard`):
/// an author with no books gets one door, drawn the way a room's row is — a
/// card with an arrow — because a lone blank cover in an empty grid reads as
/// a placeholder, not as the thing to tap. Opens the same New novel sheet
/// the card does.
class EmptyShelfCard extends StatelessWidget {
  const EmptyShelfCard({super.key, required this.onPressed});
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    // Apparition's plate, as the desk draws it: where a new book is written.
    final tile = rooms.firstWhere((r) => r.key == RoomKey.apparition).tile;
    return Press(
      onPressed: onPressed,
      semanticLabel: 'Import or write your novel',
      builder: (context, pressed) => Container(
        constraints: const BoxConstraints(minHeight: 64),
        padding: const EdgeInsets.fromLTRB(10, 10, 14, 10),
        decoration: BoxDecoration(
          color: pressed ? Ds.veilHi : Ds.veil,
          border: Border.all(color: pressed ? Ds.edgeHi : Ds.edge),
          borderRadius: BorderRadius.circular(DsGeom.radius),
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(17 / 60 * 52),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: const Alignment(0.1, 1),
                  colors: [tile.start, tile.end],
                ),
              ),
              child: const Icon(LucideIcons.plus, size: 25, color: Color(0xFFFFFFFF)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Import or write your novel',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: DsStyle.ui(const DsStep(17, 23), color: Ds.hi, weight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Bring in a manuscript, or start one from scratch.',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: DsStyle.ui(DsText.body, color: Ds.mid),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Icon(LucideIcons.arrowRight, size: 16, color: pressed ? Ds.hi : Ds.low),
          ],
        ),
      ),
    );
  }
}
