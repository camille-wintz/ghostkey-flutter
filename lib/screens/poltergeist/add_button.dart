import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../ds/tokens.dart';
import '../../ui/press.dart';

/// The room's one way to start something: a bordered +, in the house corner.
/// The board's "add a chapter" and the list's "add a task" are the same
/// control.
class AddButton extends StatelessWidget {
  const AddButton({super.key, required this.label, required this.onPressed, this.disabled = false, this.size = DsGeom.ctl});
  final String label;
  final VoidCallback onPressed;
  final bool disabled;
  final double size;

  @override
  Widget build(BuildContext context) => Press(
        onPressed: onPressed,
        enabled: !disabled,
        semanticLabel: label,
        builder: (context, pressed) => Opacity(
          opacity: disabled ? 0.4 : 1,
          child: Container(
            width: size,
            height: size,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: pressed ? Ds.accentMix(12) : const Color(0x00000000),
              border: Border.all(color: pressed ? Ds.accent : Ds.accentMix(35)),
              borderRadius: BorderRadius.circular(DsGeom.radius),
            ),
            child: Icon(LucideIcons.plus, size: 15, color: pressed ? Ds.accent : Ds.accentMix(70)),
          ),
        ),
      );
}
