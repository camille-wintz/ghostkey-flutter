import 'package:flutter/material.dart';

import '../ds/tokens.dart';
import 'press.dart';

/// The one action a [RoomTitleBar] carries when it carries any.
class RoomBarAction extends StatelessWidget {
  const RoomBarAction({super.key, required this.icon, required this.onPressed, required this.semanticLabel});

  final IconData icon;
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
          child: Icon(icon, size: 18, color: Ds.mid),
        ),
      );
}
