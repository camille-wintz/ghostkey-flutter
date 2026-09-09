import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../ds/tokens.dart';
import 'press.dart';

/// The control that opens a room's own list — chapters in Apparition, chats in
/// PhantomMemory. One widget rather than one icon per room: the two rooms had
/// drifted to different marks at different weights, which is what made moving
/// between them read as moving between two apps.
class RoomMenuButton extends StatelessWidget {
  const RoomMenuButton({super.key, required this.onPressed, required this.semanticLabel});

  final VoidCallback onPressed;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) => Press(
        onPressed: onPressed,
        semanticLabel: semanticLabel,
        builder: (context, pressed) => Container(
          width: DsGeom.row,
          height: DsGeom.row,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: pressed ? Ds.veil : const Color(0x00000000),
            borderRadius: BorderRadius.circular(DsGeom.radius),
          ),
          child: Icon(LucideIcons.menu, size: 22, color: Ds.hi),
        ),
      );
}
