import 'package:flutter/material.dart';

import '../../ds/tokens.dart';
import '../../ui/press.dart';

/// One part of the library the grid can show — All, Unfiled, a folder — or
/// the last chip, which makes a folder.
class FolderChip extends StatelessWidget {
  const FolderChip({
    super.key,
    required this.label,
    required this.active,
    required this.onTap,
    this.onHold,
    this.icon,
  });
  final String label;
  final bool active;
  final VoidCallback onTap;

  /// A folder's own actions (Rename, Delete folder); null on the fixed chips.
  final VoidCallback? onHold;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final ink = active ? Ds.accent200 : Ds.mid;
    return Press(
      onPressed: onTap,
      onLongPress: onHold,
      semanticLabel: label,
      builder: (context, pressed) => AnimatedContainer(
        duration: DsMotion.duration,
        height: 32,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active ? Ds.accentMix(12) : (pressed ? Ds.veil : Ds.surf),
          border: Border.all(color: active ? Ds.accentMix(40) : Ds.edge),
          borderRadius: BorderRadius.circular(DsGeom.radius),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon case final icon?) ...[
              Icon(icon, size: 13, color: ink),
              const SizedBox(width: 5),
            ],
            Text(label, style: DsStyle.ui(DsText.ui, color: ink, weight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}
