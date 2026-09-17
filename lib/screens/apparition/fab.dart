import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../ds/tokens.dart';
import '../../ui/press.dart';

/// The tile's edge. The page keeps the caret clear of it.
const double fabSize = 56;

/// The editor's one reach — add something to this chapter.
///
/// A tinted tile, not a filled disc with a glow: the house is matte,
/// separates surfaces with a hairline, and has no lift token. It wears the
/// same 16px corner as every other control, which at 56px reads as a soft
/// square rather than the capsule the same radius makes of a 34px button.
class Fab extends StatelessWidget {
  const Fab({
    super.key,
    required this.onPressed,
    required this.semanticLabel,
    this.icon = LucideIcons.plus,
    this.attention = false,
  });
  final VoidCallback onPressed;
  final String semanticLabel;
  final IconData icon;

  /// The tile turns amber: something inside the menu wants a look.
  final bool attention;

  @override
  Widget build(BuildContext context) {
    final hue = attention ? Ds.attention : Ds.accent;
    return Press(
      onPressed: onPressed,
      semanticLabel: semanticLabel,
      builder: (context, pressed) => Container(
        width: fabSize,
        height: fabSize,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(DsGeom.radius),
          border: Border.all(color: pressed ? hue : hue.withValues(alpha: 0.55)),
          // The system's `color-mix(in srgb, <hue> 14%, void)`, resolved:
          // an OPAQUE blend, not a wash. The page scrolls under this button,
          // and a translucent one would carry the prose across it.
          color: attention
              ? Color.alphaBlend(hue.withValues(alpha: pressed ? 0.20 : 0.14), Ds.void_)
              : (pressed ? const Color(0xFF212747) : const Color(0xFF1A1E35)),
        ),
        child: Icon(icon, size: 22, color: hue),
      ),
    );
  }
}
