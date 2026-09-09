import 'package:flutter/widgets.dart';

import 'icons.dart';
import 'rooms.dart';

/// The 60px, radius-17 gradient plate the desktop's AppVisual draws under
/// each room icon. Knows no room: the caller hands it a gradient and a mark.
class RoomTile extends StatelessWidget {
  const RoomTile({super.key, required this.tile, required this.mark, this.size = 60, this.iconSize = 29});
  final TileGradient tile;
  final RoomMark mark;
  final double size;
  final double iconSize;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(17 / 60 * size),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: const Alignment(0.1, 1),
            colors: [tile.start, tile.end],
          ),
        ),
        child: RoomIcon(mark, size: iconSize),
      );
}
