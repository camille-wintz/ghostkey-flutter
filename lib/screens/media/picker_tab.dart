import 'package:flutter/material.dart';

import '../../ds/tokens.dart';
import '../../ui/press.dart';

/// One of the picker's two tabs in its title bar: Media library, Draw.
class PickerTab extends StatelessWidget {
  const PickerTab({super.key, required this.label, required this.active, required this.onTap, this.busy = false});
  final String label;
  final bool active;
  final VoidCallback onTap;

  /// A draw is running behind this tab — said from the other one too.
  final bool busy;

  @override
  Widget build(BuildContext context) => Press(
        onPressed: onTap,
        semanticLabel: label,
        builder: (context, pressed) => AnimatedContainer(
          duration: DsMotion.duration,
          height: DsGeom.ctl,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: active ? Ds.accentMix(12) : (pressed ? Ds.veil : const Color(0x00000000)),
            borderRadius: BorderRadius.circular(DsGeom.radius),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: DsStyle.ui(DsText.ui, color: active ? Ds.accent200 : Ds.mid, weight: FontWeight.w600),
              ),
              if (busy) ...[
                const SizedBox(width: 6),
                SizedBox.square(dimension: 10, child: CircularProgressIndicator(strokeWidth: 1.5, color: Ds.accent)),
              ],
            ],
          ),
        ),
      );
}
