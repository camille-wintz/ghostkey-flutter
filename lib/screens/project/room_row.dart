import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../access/plans.dart';
import '../../ds/tokens.dart';
import '../../rooms/room_tile.dart';
import '../../rooms/rooms.dart';
import '../../server/dto/billing.dart';
import '../../ui/press.dart';

/// One room on the project home: its mark, its name, and what it is for.
/// Deliberately not a card — the mark is the object, and the row is just the
/// reach around it. Fires for locked rows too; the screen decides what a
/// locked tap shows.
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
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
          decoration: BoxDecoration(
            color: pressed ? Ds.veil : const Color(0x00000000),
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
              if (!granted) Icon(LucideIcons.lock, size: 15, color: Ds.faint),
            ],
          ),
        ),
      ),
    );
  }
}
