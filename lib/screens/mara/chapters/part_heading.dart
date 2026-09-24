import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../ds/tokens.dart';
import '../../../ui/press.dart';

/// A part of the book, over its chapters. Read-only unless the list hands it
/// a way to fold it and a menu.
class PartHeading extends StatelessWidget {
  const PartHeading({super.key, required this.name, this.collapsed, this.onToggle, this.onMenu});
  final String name;

  /// Null when the part does not fold here.
  final bool? collapsed;
  final VoidCallback? onToggle;
  final VoidCallback? onMenu;

  @override
  Widget build(BuildContext context) {
    final folded = collapsed;
    return Press(
      onPressed: onToggle,
      semanticLabel: folded == null ? name : '$name, ${folded ? 'folded' : 'open'}',
      builder: (context, pressed) => Container(
        height: DsGeom.row,
        padding: const EdgeInsets.only(left: 12, top: 8),
        decoration: BoxDecoration(
          color: pressed ? Ds.veil : const Color(0x00000000),
          borderRadius: BorderRadius.circular(DsGeom.radius),
        ),
        child: Row(
          children: [
            if (folded != null) ...[
              Icon(folded ? LucideIcons.chevronRight : LucideIcons.chevronDown, size: 14, color: Ds.low),
              const SizedBox(width: 6),
            ],
            Expanded(
              child: Text(
                name.toUpperCase(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: DsStyle.eyebrow(color: Ds.mid, weight: FontWeight.w600),
              ),
            ),
            if (onMenu case final onMenu?)
              Press(
                onPressed: onMenu,
                semanticLabel: 'Part',
                builder: (context, pressed) => Container(
                  width: 40,
                  height: 36,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: pressed ? Ds.veil : const Color(0x00000000),
                    borderRadius: BorderRadius.circular(DsGeom.radius),
                  ),
                  child: Icon(LucideIcons.ellipsis, size: 16, color: Ds.mid),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
