import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../ds/tokens.dart';
import '../../ui/press.dart';
import '../../wisp/pages.dart';

/// One task in the room's list: its mark, its name, what it does — or, while
/// something is going on in it, that instead.
class WispTaskRow extends StatelessWidget {
  const WispTaskRow({super.key, required this.page, required this.onOpen, this.status});
  final WispPage page;
  final VoidCallback onOpen;

  /// A run going, or questions waiting. Replaces the description.
  final String? status;

  @override
  Widget build(BuildContext context) => Press(
        onPressed: onOpen,
        semanticLabel: status == null ? page.label : '${page.label}, $status',
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
                child: Icon(page.icon, size: 17, color: Ds.accent),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(page.label, style: DsStyle.prose(DsText.body, color: Ds.ink)),
                    const SizedBox(height: 1),
                    Text(
                      status ?? page.description,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: DsStyle.ui(DsText.eyebrow, color: status != null ? Ds.accent : Ds.low),
                    ),
                  ],
                ),
              ),
              Icon(LucideIcons.chevronRight, size: 16, color: Ds.faint),
            ],
          ),
        ),
      );
}
