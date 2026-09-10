import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../ds/tokens.dart';
import '../../ui/anchored_panel.dart';
import '../../ui/press.dart';
import '../../ui/room_back_button.dart';

/// Back · the chat's name · the manuscript switch · model chip. Apparition's
/// bar, in this room's proportions: the corner is the way out of the room,
/// and the name in the middle is the way into the list of chats — the
/// chevron under it is the hinge that list unfolds from.
class ChatTopBar extends StatefulWidget {
  const ChatTopBar({
    super.key,
    required this.title,
    required this.modelName,
    required this.manuscriptWrites,
    required this.onBack,
    required this.onOpenChats,
    required this.onModel,
    required this.onManuscript,
  });

  final String title;
  final String modelName;

  /// Whether the assistant may edit chapters this conversation — the
  /// "Write in the manuscript" / "Read only" switch. Write by default; the one
  /// control that lets model text reach the manuscript, so it is the author's
  /// to flip and it says which way it is set.
  final bool manuscriptWrites;
  final VoidCallback onManuscript;
  final VoidCallback onBack;

  /// Open the chat list, unfolded from the title's own box.
  final void Function(Rect? anchor) onOpenChats;
  final VoidCallback onModel;

  @override
  State<ChatTopBar> createState() => _ChatTopBarState();
}

class _ChatTopBarState extends State<ChatTopBar> {
  final GlobalKey _titleKey = GlobalKey();

  @override
  Widget build(BuildContext context) => Container(
        height: 52,
        padding: const EdgeInsets.symmetric(horizontal: 6),
        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Ds.edge))),
        child: Row(
          children: [
            RoomBackButton(onPressed: widget.onBack, semanticLabel: 'Back to the book'),
            Expanded(
              child: Center(
                child: Press(
                  key: _titleKey,
                  onPressed: () => widget.onOpenChats(anchorRectOf(_titleKey)),
                  semanticLabel: '${widget.title}, open your chats',
                  builder: (context, pressed) => Container(
                    height: DsGeom.row,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      color: pressed ? Ds.veil : const Color(0x00000000),
                      borderRadius: BorderRadius.circular(DsGeom.radius),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            widget.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: DsStyle.ui(DsText.ui, color: Ds.soft),
                          ),
                        ),
                        const SizedBox(width: 5),
                        Icon(LucideIcons.chevronDown, size: 14, color: Ds.mid),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Press(
              onPressed: widget.onManuscript,
              semanticLabel: widget.manuscriptWrites
                  ? 'Writing in the manuscript — tap for read only'
                  : 'Read only — tap to write in the manuscript',
              builder: (context, pressed) => AnimatedContainer(
                duration: DsMotion.duration,
                height: 28,
                margin: const EdgeInsets.only(right: 6),
                padding: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  color: pressed ? Ds.accentMix(12) : Ds.panel,
                  border: Border.all(color: pressed ? Ds.edgeHi : Ds.edge),
                  borderRadius: BorderRadius.circular(DsGeom.radius),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      widget.manuscriptWrites ? LucideIcons.penLine : LucideIcons.lock,
                      size: 12,
                      color: widget.manuscriptWrites ? Ds.accent : Ds.mid,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      widget.manuscriptWrites ? 'Write' : 'Read only',
                      style: DsStyle.ui(DsText.ui, color: Ds.soft),
                    ),
                  ],
                ),
              ),
            ),
            Press(
              onPressed: widget.onModel,
              semanticLabel: 'Choose model',
              builder: (context, pressed) => AnimatedContainer(
                duration: DsMotion.duration,
                height: 28,
                margin: const EdgeInsets.only(right: 6),
                padding: const EdgeInsets.only(left: 10, right: 6),
                decoration: BoxDecoration(
                  color: pressed ? Ds.accentMix(12) : Ds.panel,
                  border: Border.all(color: pressed ? Ds.edgeHi : Ds.edge),
                  borderRadius: BorderRadius.circular(DsGeom.radius),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 120),
                      child: Text(
                        widget.modelName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: DsStyle.ui(DsText.ui, color: Ds.soft),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(LucideIcons.chevronDown, size: 12, color: Ds.mid),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
}
