import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../access/plans.dart';
import '../../ds/tokens.dart';
import '../../rooms/room_tile.dart';
import '../../rooms/rooms.dart';
import '../../server/dto/billing.dart';
import '../../ui/press.dart';

/// One room on the project home: its mark, its name, and what it is for.
/// Drawn as a card with an arrow, as the desktop's AppCard is: bare words
/// beside a mark read as a legend, not a door, and authors didn't know to tap.
/// The lock takes the arrow's place. Fires for locked rows too; the screen
/// decides what a locked tap shows.
class RoomRow extends StatelessWidget {
  const RoomRow({super.key, required this.room, required this.granted, required this.onOpen, this.requiredPlan});
  final Room room;
  final bool granted;
  final Plan? requiredPlan;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final lockedLabel = requiredPlan != null
        ? '${room.title}, locked, needs ${planName(requiredPlan!)}'
        : '${room.title}, locked';
    return Press(
      onPressed: onOpen,
      semanticLabel: granted ? 'Open ${room.title}' : lockedLabel,
      builder: (context, pressed) => Opacity(
        opacity: granted ? 1 : 0.55,
        child: Container(
          constraints: const BoxConstraints(minHeight: 64),
          padding: const EdgeInsets.fromLTRB(10, 10, 14, 10),
          decoration: BoxDecoration(
            color: pressed ? Ds.veilHi : Ds.veil,
            border: Border.all(color: pressed ? Ds.edgeHi : Ds.edge),
            borderRadius: BorderRadius.circular(DsGeom.radius),
          ),
          child: Row(
            children: [
              RoomTile(tile: room.tile, mark: room.mark, size: 52, iconSize: 25),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      room.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: DsStyle.ui(const DsStep(17, 23), color: Ds.hi, weight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      room.subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: DsStyle.ui(DsText.body, color: Ds.mid),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              granted
                  ? Icon(LucideIcons.arrowRight, size: 16, color: pressed ? Ds.hi : Ds.low)
                  : Icon(LucideIcons.lock, size: 15, color: Ds.faint),
            ],
          ),
        ),
      ),
    );
  }
}
