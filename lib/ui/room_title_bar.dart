import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../ds/tokens.dart';
import 'anchored_panel.dart';
import 'press.dart';
import 'room_back_button.dart';

/// The bar every room but Apparition opens on: the way back in the corner,
/// what you are looking at in the middle, one action opposite.
///
/// One line of chrome rather than a room label over a book title over a page
/// title. The room is already said by the room you pressed to get here; what
/// the bar owes is the thing on the screen — today's page, the book, the chat
/// — with its one fact (the date, a count) under it.
///
/// Apparition's [TitleBlock] in a fixed size: the same back button, the same
/// serif name, centred on the SCREEN. The trailing slot keeps its width when
/// empty for that reason — without it the name centres in whatever the back
/// button left over and steps sideways between rooms.
///
/// When [onTitle] is given the name is also the way into the room's list, with
/// the chevron beside it as the hinge that list unfolds from.
class RoomTitleBar extends StatefulWidget {
  const RoomTitleBar({
    super.key,
    required this.title,
    required this.onBack,
    this.subtitle,
    this.onTitle,
    this.titleLabel,
    this.trailing,
  });

  final String title;

  /// A widget rather than a string where the fact can be in flight — the
  /// board's "checking".
  final Widget? subtitle;
  final VoidCallback onBack;

  /// Open the room's list, unfolded from the title's own box.
  final void Function(Rect? anchor)? onTitle;

  /// What pressing the title does, said to a screen reader.
  final String? titleLabel;

  /// The one action this room's chrome carries, if it carries any.
  final Widget? trailing;

  @override
  State<RoomTitleBar> createState() => _RoomTitleBarState();
}

class _RoomTitleBarState extends State<RoomTitleBar> {
  final GlobalKey _titleKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    final name = Text(
      widget.title,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      textAlign: TextAlign.center,
      style: DsStyle.prose(const DsStep(20, 26), weight: FontWeight.w600, color: Ds.hi),
    );
    final onTitle = widget.onTitle;

    return Container(
      constraints: const BoxConstraints(minHeight: 52),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Ds.edge))),
      child: Row(
        children: [
          RoomBackButton(onPressed: widget.onBack, semanticLabel: 'Back to the book'),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (onTitle == null)
                  Padding(padding: const EdgeInsets.symmetric(horizontal: 8), child: name)
                else
                  Press(
                    key: _titleKey,
                    onPressed: () => onTitle(anchorRectOf(_titleKey)),
                    semanticLabel: widget.titleLabel ?? widget.title,
                    builder: (context, pressed) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: pressed ? Ds.veil : const Color(0x00000000),
                        borderRadius: BorderRadius.circular(DsGeom.radius),
                      ),
                      // Held to one line so the box hugs the name and the
                      // chevron sits against its last letter — see TitleBlock.
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(child: name),
                          const SizedBox(width: 6),
                          Icon(LucideIcons.chevronDown, size: 16, color: Ds.mid),
                        ],
                      ),
                    ),
                  ),
                if (widget.subtitle case final subtitle?)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: DefaultTextStyle(
                      style: DsStyle.eyebrow(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      child: subtitle,
                    ),
                  ),
              ],
            ),
          ),
          SizedBox(width: DsGeom.row, child: widget.trailing),
        ],
      ),
    );
  }
}
