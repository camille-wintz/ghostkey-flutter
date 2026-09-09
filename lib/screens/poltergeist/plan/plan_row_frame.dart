import 'package:flutter/material.dart';

import '../../../ds/tokens.dart';

/// The card a folder's rows sit in, drawn row by row so the list stays
/// virtual: side hairlines on every row, the bottom corners on the last.
/// Loose rows get no frame — an unfiled run isn't a section, it's just
/// what's left.
class PlanRowFrame extends StatelessWidget {
  const PlanRowFrame({super.key, required this.inFolder, required this.last, required this.child});
  final bool inFolder;
  final bool last;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!inFolder) return child;
    final side = BorderSide(color: Ds.accentMix(12));
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Ds.panel.withValues(alpha: 0.6),
        border: Border(left: side, right: side, bottom: last ? side : BorderSide.none),
        borderRadius: last ? const BorderRadius.vertical(bottom: Radius.circular(DsGeom.radius)) : null,
      ),
      child: child,
    );
  }
}
