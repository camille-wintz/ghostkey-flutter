import 'package:flutter/material.dart';

import '../../ds/tokens.dart';
import '../../ui/press.dart';

/// The small action at the right of a [VeilSection]'s title: Update on the
/// dossier, Keep the dossier's on the appearance and the GMC.
class VeilSectionLink extends StatelessWidget {
  const VeilSectionLink({super.key, required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Press(
        onPressed: onTap,
        semanticLabel: label,
        builder: (context, pressed) => Opacity(
          opacity: pressed ? 0.7 : 1,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 12, color: Ds.low),
              const SizedBox(width: 5),
              Text(label, style: DsStyle.ui(DsText.ui, color: Ds.low)),
            ],
          ),
        ),
      );
}
