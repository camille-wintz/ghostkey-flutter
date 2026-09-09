import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../ds/tokens.dart';
import '../../../ui/press.dart';

/// The ledger's checkbox: a 16px ruled square that fills with the accent
/// when a task completes. The press target is the whole 44px row height.
class TaskCheckbox extends StatelessWidget {
  const TaskCheckbox({super.key, required this.checked, required this.onToggle, required this.label});
  final bool checked;
  final VoidCallback onToggle;
  final String label;

  @override
  Widget build(BuildContext context) => Press(
        onPressed: onToggle,
        semanticLabel: label,
        builder: (context, pressed) => SizedBox(
          width: 32,
          height: DsGeom.row,
          child: Center(
            child: AnimatedContainer(
              duration: DsMotion.duration,
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                color: checked ? (pressed ? Ds.accent600 : Ds.accent) : (pressed ? Ds.accentMix(10) : const Color(0x00000000)),
                border: Border.all(color: checked || pressed ? Ds.accent : Ds.faint, width: 1.5),
                borderRadius: BorderRadius.circular(4),
              ),
              child: checked ? Icon(LucideIcons.check, size: 11, color: Ds.panel) : null,
            ),
          ),
        ),
      );
}
