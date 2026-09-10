import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../ds/tokens.dart';
import '../../../ui/press.dart';

/// A section heading in the system's eyebrow, with the one thing the section
/// can be given: another of whatever it lists.
class SectionHeader extends StatelessWidget {
  const SectionHeader({super.key, required this.label, this.onAdd});
  final String label;
  final VoidCallback? onAdd;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: DsGeom.row,
        child: Padding(
          padding: const EdgeInsets.only(left: 20, right: 13),
          child: Row(
            children: [
              Expanded(child: Text(label.toUpperCase(), style: DsStyle.eyebrow())),
              if (onAdd != null)
                Press(
                  onPressed: onAdd,
                  semanticLabel: 'New ${label.toLowerCase().replaceAll(RegExp(r's$'), '')}',
                  builder: (context, pressed) => Container(
                    width: DsGeom.ctl,
                    height: DsGeom.ctl,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(DsGeom.radius),
                      color: pressed ? Ds.veil : const Color(0x00000000),
                    ),
                    child: Icon(LucideIcons.plus, size: 15, color: Ds.mid),
                  ),
                ),
            ],
          ),
        ),
      );
}
