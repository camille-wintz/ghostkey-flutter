import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../ds/tokens.dart';
import '../../ui/press.dart';
import '../../ui/room_menu_button.dart';

/// Menu (drawer) · session title · model chip. The Apparition bar's idiom.
class ChatTopBar extends StatelessWidget {
  const ChatTopBar({
    super.key,
    required this.title,
    required this.modelName,
    required this.onMenu,
    required this.onModel,
  });

  final String title;
  final String modelName;
  final VoidCallback onMenu;
  final VoidCallback onModel;

  @override
  Widget build(BuildContext context) => Container(
        height: 52,
        padding: const EdgeInsets.symmetric(horizontal: 6),
        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Ds.edge))),
        child: Row(
          children: [
            RoomMenuButton(onPressed: onMenu, semanticLabel: 'Open chats'),
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: DsStyle.ui(DsText.ui, color: Ds.mid),
              ),
            ),
            Press(
              onPressed: onModel,
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
                        modelName,
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
