import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../ds/tokens.dart';
import 'press.dart';

/// One page in a room's list of pages: its mark, its name, what it does — or,
/// while something is going on in it, that instead.
class PageRow extends StatelessWidget {
  const PageRow({
    super.key,
    required this.icon,
    required this.label,
    required this.description,
    required this.onOpen,
    this.status,
    this.trailingLabel,
  });
  final IconData icon;
  final String label;
  final String description;
  final VoidCallback onOpen;

  /// A run going, or something waiting on the author. Replaces the
  /// description.
  final String? status;

  /// A word before the chevron — "Open" on a thing that already exists.
  final String? trailingLabel;

  @override
  Widget build(BuildContext context) => Press(
        onPressed: onOpen,
        semanticLabel: status == null ? label : '$label, $status',
        builder: (context, pressed) => AnimatedContainer(
          duration: DsMotion.duration,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          decoration: BoxDecoration(
            color: pressed ? Ds.veil : const Color(0x00000000),
            borderRadius: BorderRadius.circular(DsGeom.radius),
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Ds.surf,
                  border: Border.all(color: Ds.edge),
                  borderRadius: BorderRadius.circular(DsGeom.radius - 4),
                ),
                child: Icon(icon, size: 17, color: Ds.accent),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: DsStyle.prose(DsText.body, color: Ds.ink)),
                    const SizedBox(height: 1),
                    Text(
                      status ?? description,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: DsStyle.ui(DsText.eyebrow, color: status != null ? Ds.accent : Ds.low),
                    ),
                  ],
                ),
              ),
              if (trailingLabel case final trailing?) ...[
                const SizedBox(width: 8),
                Text(trailing, style: DsStyle.ui(DsText.ui, color: Ds.accent, weight: FontWeight.w600)),
                const SizedBox(width: 4),
              ],
              Icon(LucideIcons.chevronRight, size: 16, color: Ds.faint),
            ],
          ),
        ),
      );
}
