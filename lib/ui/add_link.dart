import 'package:flutter/material.dart';

import '../ds/tokens.dart';
import 'press.dart';

/// A quiet "add" at the foot of a list: a mark and a word, dimmed when it
/// waits.
class AddLink extends StatelessWidget {
  const AddLink({super.key, required this.icon, required this.label, required this.onPressed});
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => Press(
        onPressed: onPressed,
        semanticLabel: label,
        hitSlop: 6,
        builder: (context, pressed) => Opacity(
          opacity: onPressed == null ? 0.45 : (pressed ? 0.7 : 1),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 15, color: Ds.accent),
              const SizedBox(width: 6),
              Text(label, style: DsStyle.ui(DsText.ui, color: Ds.soft, weight: FontWeight.w600)),
            ],
          ),
        ),
      );
}
