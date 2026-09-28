import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../ds/tokens.dart';
import '../../ui/press.dart';

/// The gallery strip's last tile while editing: more pictures, from the
/// library.
class GalleryAddTile extends StatelessWidget {
  const GalleryAddTile({super.key, required this.height, required this.onPressed, this.busy = false});
  final double height;
  final VoidCallback onPressed;
  final bool busy;

  @override
  Widget build(BuildContext context) => Press(
        onPressed: busy ? null : onPressed,
        semanticLabel: 'Add pictures',
        builder: (context, pressed) => Container(
          width: height * 0.75,
          height: height,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: pressed ? Ds.veil : Ds.surf,
            border: Border.all(color: Ds.edgeHi),
            borderRadius: BorderRadius.circular(DsGeom.radius),
          ),
          child: busy
              ? SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Ds.accent))
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(LucideIcons.plus, size: 20, color: Ds.accent),
                    const SizedBox(height: 6),
                    Text('Add', style: DsStyle.ui(DsText.ui, color: Ds.mid, weight: FontWeight.w600)),
                  ],
                ),
        ),
      );
}
