import 'package:flutter/material.dart';

import '../../../ds/tokens.dart';
import '../../../ui/add_button.dart';

/// A section heading in the system's eyebrow, with the one thing the section
/// can be given: another of whatever it lists. A band a step below the page,
/// edged in the accent, as the desk's SectionHeader is (Cleo, 2026-10-08).
class SectionHeader extends StatelessWidget {
  const SectionHeader({super.key, required this.label, this.onAdd});
  final String label;
  final VoidCallback? onAdd;

  @override
  // Opaque: the list pins it, and the rows scroll under it.
  Widget build(BuildContext context) => Container(
        height: DsGeom.row,
        decoration: BoxDecoration(
          color: Ds.sunk,
          border: Border(bottom: BorderSide(color: Ds.accentMix(12))),
        ),
        child: Padding(
          padding: const EdgeInsets.only(left: 20, right: 13),
          child: Row(
            children: [
              Expanded(child: Text(label.toUpperCase(), style: DsStyle.eyebrow())),
              if (onAdd != null)
                AddButton(
                  semanticLabel: 'New ${label.toLowerCase().replaceAll(RegExp(r's$'), '')}',
                  onPressed: onAdd!,
                ),
            ],
          ),
        ),
      );
}
