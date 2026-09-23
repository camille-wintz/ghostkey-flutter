import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../access/plans.dart';
import '../../ds/tokens.dart';
import '../../rooms/room_tile.dart';
import '../../rooms/rooms.dart';
import '../../server/dto/billing.dart';
import '../../ui/press.dart';

/// One room on the project home: its mark, what it is for, and its name.
/// Drawn as a card with an arrow, as the desktop's AppCard is: bare words
/// beside a mark read as a legend, not a door, and authors didn't know to tap.
/// The lock takes the arrow's place. Fires for locked rows too; the screen
/// decides what a locked tap shows.
///
/// What the room does leads and its name follows, as on the desktop: an
/// author looking for "worldbuild" shouldn't have to know it is called Veil.
class RoomRow extends StatelessWidget {
  const RoomRow({
    super.key,
    required this.room,
    required this.granted,
    required this.onOpen,
    this.requiredPlan,
    this.primary = false,
  });
  final Room room;
  final bool granted;
  final Plan? requiredPlan;
  final VoidCallback onOpen;

  /// The room the house is for — Apparition, where the book is: a larger
  /// card over the rest, washed and edged in the accent (the desktop's
  /// `prominence="primary"`).
  final bool primary;

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
          constraints: BoxConstraints(minHeight: primary ? 92 : 64),
          padding: primary ? const EdgeInsets.fromLTRB(14, 14, 18, 14) : const EdgeInsets.fromLTRB(10, 10, 14, 10),
          decoration: BoxDecoration(
            color: primary ? null : (pressed ? Ds.veilHi : Ds.veil),
            gradient: primary
                ? LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Ds.accentMix(pressed ? 22 : 14), pressed ? Ds.veilHi : Ds.veil],
                    stops: const [0, 0.7],
                  )
                : null,
            border: Border.all(
              color: primary ? Ds.accentMix(pressed ? 70 : 40) : (pressed ? Ds.edgeHi : Ds.edge),
            ),
            borderRadius: BorderRadius.circular(DsGeom.radius),
          ),
          child: Row(
            children: [
              RoomTile(tile: room.tile, mark: room.mark, size: primary ? 64 : 52, iconSize: primary ? 31 : 25),
              SizedBox(width: primary ? 16 : 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      room.subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: primary
                          ? DsStyle.prose(const DsStep(22, 27), weight: FontWeight.w600)
                          : DsStyle.ui(const DsStep(17, 23), color: Ds.hi, weight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      room.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: DsStyle.ui(DsText.body, color: Ds.mid),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              granted
                  ? Icon(
                      LucideIcons.arrowRight,
                      size: primary ? 20 : 16,
                      color: primary ? (pressed ? Ds.accent200 : Ds.accent) : (pressed ? Ds.hi : Ds.low),
                    )
                  : Icon(LucideIcons.lock, size: 15, color: Ds.faint),
            ],
          ),
        ),
      ),
    );
  }
}
