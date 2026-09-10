import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../ds/tokens.dart';
import '../../../ui/press.dart';

/// A folder's heading in the chapter list: tap to fold or unfold. It holds a
/// slot others step past during a drag, but a hold on it lifts nothing.
class FolderTile extends StatelessWidget {
  const FolderTile({super.key, required this.name, required this.open, required this.onToggle});
  final String name;
  final bool open;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) => Semantics(
        expanded: open,
        child: Press(
          onPressed: onToggle,
          semanticLabel: name,
          builder: (context, pressed) => Container(
            height: DsGeom.row,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            color: pressed ? Ds.veil : const Color(0x00000000),
            child: Row(
              children: [
                Icon(open ? LucideIcons.chevronDown : LucideIcons.chevronRight, size: 14, color: Ds.mid),
                const SizedBox(width: 10),
                Icon(LucideIcons.folder, size: 14, color: Ds.mid),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: DsStyle.ui(DsText.body, color: Ds.soft)),
                ),
              ],
            ),
          ),
        ),
      );
}
