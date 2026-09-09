import 'package:flutter/widgets.dart';

import '../../ds/tokens.dart';
import '../../ui/press.dart';

/// The dock's square control (pause / play): a raised tile with a hairline,
/// one row tall, no lift.
class DockIconButton extends StatelessWidget {
  const DockIconButton({super.key, required this.icon, required this.label, required this.onPressed});
  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Press(
        onPressed: onPressed,
        semanticLabel: label,
        builder: (context, pressed) => AnimatedContainer(
          duration: DsMotion.duration,
          width: DsGeom.row,
          height: DsGeom.row,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: pressed ? Ds.veilHi : Ds.raise,
            border: Border.all(color: pressed ? Ds.edgeHi : Ds.edge),
            borderRadius: BorderRadius.circular(DsGeom.radius),
          ),
          child: Icon(icon, size: 18, color: Ds.mid),
        ),
      );
}
