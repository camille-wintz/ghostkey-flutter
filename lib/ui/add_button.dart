import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../ds/tokens.dart';
import 'press.dart';

/// A list's +: the primary button's tint and edge around the mark alone,
/// square at the control's height, and lit — a live part, not a glyph in the
/// margin. The web phone's `AddButton` is the same control.
class AddButton extends StatelessWidget {
  const AddButton({super.key, required this.semanticLabel, required this.onPressed});
  final String semanticLabel;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Press(
    onPressed: onPressed,
    semanticLabel: semanticLabel,
    builder: (context, pressed) => AnimatedContainer(
      duration: DsMotion.duration,
      width: DsGeom.ctl,
      height: DsGeom.ctl,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(DsGeom.radius),
        color: Ds.accentMix(pressed ? 20 : 12),
        border: Border.all(color: pressed ? Ds.accent : Ds.accentMix(55)),
        boxShadow: [BoxShadow(color: Ds.accentMix(pressed ? 45 : 30), blurRadius: 14)],
      ),
      child: Icon(LucideIcons.plus, size: 16, color: Ds.accent),
    ),
  );
}
