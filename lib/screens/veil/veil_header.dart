import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../ds/tokens.dart';
import '../../server/dto/bible.dart';
import '../../ui/room_back_button.dart';
import '../../ui/room_bar_action.dart';
import '../../veil/roster.dart';
import '../../veil/tone.dart';

/// The entity page's top row: the way back UP to the roster, then the name,
/// with what it is and how present it is under it. The roster itself wears
/// the shared [RoomTitleBar]; this one sits left rather than centred because
/// the name is the page's title, not a room's.
class VeilHeader extends StatelessWidget {
  const VeilHeader({super.key, required this.entity, required this.onBack, this.onMore});

  final BibleEntity entity;
  final VoidCallback onBack;

  /// The card's own actions (rename, hide).
  final VoidCallback? onMore;

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
        children: [
          RoomBackButton(onPressed: onBack, semanticLabel: 'Back to Veil'),
          const SizedBox(width: 4),
          Expanded(
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
              ],
            ),
          ),
          if (onMore case final onMore?)
            RoomBarAction(icon: LucideIcons.ellipsisVertical, onPressed: onMore, semanticLabel: 'More'),
        ],
      ),
    );
  }
}
