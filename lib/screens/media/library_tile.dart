import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../ds/tokens.dart';
import '../../ui/press.dart';

/// One picture in the picker's grid, square. Picked is edged in the accent
/// and ticked; marked (already on the card) is ticked and dimmed, and a tap
/// does nothing to it — a hold still offers its actions.
class LibraryTile extends StatelessWidget {
  const LibraryTile({
    super.key,
    required this.url,
    required this.title,
    required this.picked,
    required this.marked,
    required this.onTap,
    required this.onHold,
  });
  final String? url;
  final String title;
  final bool picked;
  final bool marked;
  final VoidCallback onTap;
  final VoidCallback onHold;

  @override
  Widget build(BuildContext context) {
    final url = this.url;
    final name = title.trim().isEmpty ? 'picture' : title.trim();
    return Press(
      onPressed: onTap,
      onLongPress: onHold,
      semanticLabel: marked ? '$name, already on the card' : (picked ? '$name, picked' : name),
      builder: (context, pressed) => AnimatedContainer(
        duration: DsMotion.duration,
        decoration: BoxDecoration(
          color: Ds.raise,
          border: Border.all(color: picked ? Ds.accent : Ds.edge, width: picked ? 2 : 1),
          borderRadius: BorderRadius.circular(DsGeom.radius - 6),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (url != null)
              Opacity(
                opacity: marked ? 0.45 : (pressed ? 0.8 : 1),
                child: Image.network(
                  url,
                  fit: BoxFit.cover,
                  errorBuilder: (context, _, _) => Icon(LucideIcons.imageOff, size: 18, color: Ds.faint),
                ),
              ),
            if (picked || marked)
              Positioned(
                top: 6,
                right: 6,
                child: Container(
                  width: 22,
                  height: 22,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: picked ? Ds.accent : Ds.raise,
                    shape: BoxShape.circle,
                    border: Border.all(color: picked ? Ds.accent : Ds.edgeHi),
                  ),
                  child: Icon(LucideIcons.check, size: 13, color: picked ? Ds.void_ : Ds.mid),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
