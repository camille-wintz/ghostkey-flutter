import 'package:flutter/material.dart';

import '../../ds/tokens.dart';
import '../../ui/press.dart';

/// A small trailing affordance on a section's rule — "All tasks →". The
/// tracked eyebrow, faint until pressed.
class SectionLink extends StatelessWidget {
  const SectionLink(this.label, {super.key, required this.onPressed, this.color});
  final String label;
  final VoidCallback onPressed;
  final Color? color;

  @override
  Widget build(BuildContext context) => Press(
        onPressed: onPressed,
        semanticLabel: label,
        builder: (context, pressed) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          child: Text(
            label.toUpperCase(),
            style: DsStyle.ui(DsText.eyebrow, color: pressed ? Ds.accent : (color ?? Ds.faint), tracking: 11 * 0.12),
          ),
        ),
      );
}
