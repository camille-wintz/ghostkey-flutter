import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../ds/tokens.dart';
import '../../server/dto/bible.dart';
import '../../ui/button.dart';
import '../../ui/room_back_button.dart';
import '../../ui/room_bar_action.dart';
import '../../veil/roster.dart';
import '../../veil/tone.dart';

/// The entity page's top row: the way back UP to the roster, then the name,
/// with what it is and how present it is under it. The roster itself wears
/// the shared [RoomTitleBar]; this one sits left rather than centred because
/// the name is the page's title, not a room's.
///
/// Under the name, the page's mode as a real button: Edit while reading, Done
/// while editing — every field saves as it is written, so Done saves nothing.
/// The card's own actions (rename, hide) sit at the right of the top row, and
/// only while editing: reading a dossier changes nothing.
class VeilHeader extends StatelessWidget {
  const VeilHeader({
    super.key,
    required this.entity,
    required this.onBack,
    required this.editing,
    required this.onEdit,
    required this.onDone,
    this.onMore,
    this.besideEdit,
  });

  final BibleEntity entity;
  final VoidCallback onBack;
  final bool editing;
  final VoidCallback onEdit;
  final VoidCallback onDone;

  /// The card's own actions (rename, hide), offered while editing.
  final VoidCallback? onMore;

  /// A second button beside Edit — the ID card, on a character being read.
  final Widget? besideEdit;

  @override
  Widget build(BuildContext context) {
    final facts = [
      entity.type.label,
      chapterCount(entity.mentionCount),
      if (entity.firstAppearance != null) 'first in ${chapterLabel(entity.firstAppearance!)}',
    ].join(' · ');

    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 10, 16, 4),
      child: Row(
        // The back arrow stays level with the name, not the middle of the block.
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RoomBackButton(onPressed: onBack, semanticLabel: 'Back to Veil'),
          const SizedBox(width: 4),
          Expanded(
            // 6px centres the 32px name line on the 44px back button.
            child: Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Semantics(
                    header: true,
                    child: Text(
                      titleCase(entity.name),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: DsStyle.prose(DsText.title, weight: FontWeight.w600, color: Ds.hi),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        margin: const EdgeInsets.only(right: 7),
                        decoration: BoxDecoration(color: typeTone(entity.type), shape: BoxShape.circle),
                      ),
                      Expanded(
                        child: Text(
                          facts,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: DsStyle.ui(DsText.ui, color: Ds.low),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  // A word rather than a bare icon: it changes what every band
                  // below does. The Row keeps the button its own width.
                  Row(
                    children: [
                      GkButton(
                        label: editing ? 'Done' : 'Edit',
                        onPressed: editing ? onDone : onEdit,
                        leading: Icon(editing ? LucideIcons.check : LucideIcons.pencil, size: 15, color: Ds.accent),
                      ),
                      if (besideEdit case final beside?) ...[const SizedBox(width: 8), beside],
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (editing)
            if (onMore case final onMore?)
              RoomBarAction(icon: LucideIcons.ellipsisVertical, onPressed: onMore, semanticLabel: 'More'),
        ],
      ),
    );
  }
}
