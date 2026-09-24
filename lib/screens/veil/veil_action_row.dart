import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../ds/tokens.dart';
import '../../ui/press.dart';

/// One row of a Veil actions sheet: an icon, what it does, and why or why
/// not.
class VeilActionRow extends StatelessWidget {
  const VeilActionRow({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.enabled,
    required this.locked,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool enabled;

  /// Not on the plan: drawn with a padlock and still tappable, so the tap
  /// can explain which plan opens it.
  final bool locked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Press(
        onPressed: onTap,
        enabled: enabled,
        semanticLabel: title,
        builder: (context, pressed) => Opacity(
          opacity: enabled ? 1 : 0.45,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              color: pressed ? Ds.veil : const Color(0x00000000),
              borderRadius: BorderRadius.circular(DsGeom.radius),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Icon(icon, size: 17, color: Ds.accent),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: DsStyle.ui(DsText.body, color: Ds.hi, weight: FontWeight.w600)),
                      const SizedBox(height: 3),
                      Text(subtitle, style: DsStyle.ui(DsText.ui, color: Ds.mid)),
                    ],
                  ),
                ),
                if (locked)
                  Padding(
                    padding: const EdgeInsets.only(left: 10, top: 3),
                    child: Icon(LucideIcons.lock, size: 15, color: Ds.faint),
                  ),
              ],
            ),
          ),
        ),
      );
}
