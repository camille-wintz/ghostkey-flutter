import 'package:flutter/material.dart';

import '../../ds/tokens.dart';
import '../../ui/press.dart';

/// One segment of a type switch — the roster's filter, the add sheet's pick.
class VeilTypeTab extends StatelessWidget {
  const VeilTypeTab({super.key, required this.label, required this.active, required this.empty, required this.onTap});
  final String label;
  final bool active;
  final bool empty;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Press(
        onPressed: onTap,
        semanticLabel: label,
        builder: (context, pressed) => AnimatedContainer(
          duration: DsMotion.duration,
          height: 30,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: active ? Ds.accentMix(12) : (pressed ? Ds.veil : const Color(0x00000000)),
            borderRadius: BorderRadius.circular(DsGeom.radius - 2),
          ),
          child: Text(
            label.toUpperCase(),
            style: DsStyle.eyebrow(
              color: active ? Ds.accent200 : (empty ? Ds.faint : Ds.low),
              weight: FontWeight.w600,
            ),
          ),
        ),
      );
}
