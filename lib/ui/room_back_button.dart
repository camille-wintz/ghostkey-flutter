import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../ds/tokens.dart';
import 'press.dart';

/// The way out of a room, for the two rooms whose chrome is a title rather
/// than [RoomHeader]'s labelled row — Apparition and PhantomMemory.
///
/// One widget rather than one chevron per room: the mark, its weight and the
/// box around it are the same in both, so moving between them reads as moving
/// between rooms of one app. It took the slot the list's hamburger used to
/// hold — the list is opened by pressing the title now, and the way back is
/// what a phone expects to find at the top left.
class RoomBackButton extends StatelessWidget {
  const RoomBackButton({super.key, required this.onPressed, required this.semanticLabel});

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
          child: Icon(LucideIcons.chevronLeft, size: 22, color: Ds.hi),
        ),
      );
}
