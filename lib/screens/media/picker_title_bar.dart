import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../ds/tokens.dart';
import '../../media/picker_prefs.dart';
import '../../ui/button.dart';
import '../../ui/room_bar_action.dart';
import 'picker_tab.dart';

/// The picker's one line of chrome: the close in the corner, the two tabs
/// centred on the screen, and — once something is picked that a tap did not
/// already hand back — the commit opposite ("Add 3", "Use this").
class PickerTitleBar extends StatelessWidget {
  const PickerTitleBar({
    super.key,
    required this.tab,
    required this.onTab,
    required this.onClose,
    required this.drawing,
    this.commitLabel,
    this.onCommit,
  });

  final LibraryTab tab;
  final ValueChanged<LibraryTab> onTab;
  final VoidCallback onClose;
  final bool drawing;
  final String? commitLabel;
  final VoidCallback? onCommit;

  @override
  Widget build(BuildContext context) {
    final commit = commitLabel;
    return Container(
      constraints: const BoxConstraints(minHeight: 52),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Ds.edge))),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Row(
            children: [
              RoomBarAction(icon: LucideIcons.x, onPressed: onClose, semanticLabel: 'Close'),
              const Spacer(),
              if (commit != null)
                Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: GkButton(label: commit, onPressed: onCommit),
                ),
            ],
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              PickerTab(
                label: 'Media library',
                active: tab == LibraryTab.library,
                onTap: () => onTab(LibraryTab.library),
              ),
              const SizedBox(width: 4),
              PickerTab(
                label: 'Draw',
                active: tab == LibraryTab.draw,
                busy: drawing,
                onTap: () => onTab(LibraryTab.draw),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
