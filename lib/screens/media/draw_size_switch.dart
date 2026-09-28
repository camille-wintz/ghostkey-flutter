import 'package:flutter/material.dart';

import '../../ds/tokens.dart';
import '../../server/media/api.dart';
import '../../ui/press.dart';

/// Square · Portrait · Landscape, as one segmented control.
class DrawSizeSwitch extends StatelessWidget {
  const DrawSizeSwitch({super.key, required this.value, required this.onChanged, this.enabled = true});
  final DrawSize value;
  final ValueChanged<DrawSize> onChanged;
  final bool enabled;

  static String labelFor(DrawSize size) => switch (size) {
        DrawSize.square => 'Square',
        DrawSize.portrait => 'Portrait',
        DrawSize.landscape => 'Landscape',
      };

  @override
  Widget build(BuildContext context) => Container(
        height: 40,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: Ds.surf,
          border: Border.all(color: Ds.edge),
          borderRadius: BorderRadius.circular(DsGeom.radius),
        ),
        child: Row(
          children: [
            for (final size in DrawSize.values)
              Expanded(
                child: Press(
                  onPressed: () => onChanged(size),
                  enabled: enabled,
                  semanticLabel: labelFor(size),
                  builder: (context, pressed) => AnimatedContainer(
                    duration: DsMotion.duration,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: size == value ? Ds.accentMix(12) : (pressed ? Ds.veil : const Color(0x00000000)),
                      borderRadius: BorderRadius.circular(DsGeom.radius - 3),
                    ),
                    child: Text(
                      labelFor(size),
                      style: DsStyle.ui(
                        DsText.ui,
                        color: size == value ? Ds.accent200 : Ds.mid,
                        weight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      );
}
