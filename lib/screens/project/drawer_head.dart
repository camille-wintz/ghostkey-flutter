import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../ds/tokens.dart';
import '../../ui/press.dart';

/// A room drawer's head: the book's name as the way back to the project home,
/// and one line of meta under it.
///
/// The book's name IS the control — an arrow beside a label would be a 44px
/// target next to 200px of dead text that looks just as pressable. The rooms
/// that carry a drawer say it here and nowhere else: a faint link at the foot
/// of a scrolling list is the same escape hatch worn as a footnote, and having
/// it in two shapes is what made the rooms read as separate apps.
class DrawerHead extends StatelessWidget {
  const DrawerHead({super.key, required this.title, required this.onLeave, this.meta});

  final String title;
  final VoidCallback onLeave;

  /// What this drawer holds, in the app's own words. Absent while it loads.
  final String? meta;

  @override
  Widget build(BuildContext context) => Press(
        onPressed: onLeave,
        semanticLabel: 'Back to $title',
        builder: (context, pressed) => Container(
          padding: const EdgeInsets.fromLTRB(13, 10, 20, 14),
          decoration: BoxDecoration(
            color: pressed ? Ds.veil : const Color(0x00000000),
            border: Border(bottom: BorderSide(color: Ds.edge)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(width: 22, height: 28, child: Icon(LucideIcons.chevronLeft, size: 18, color: Ds.mid)),
              const SizedBox(width: 6),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: DsStyle.prose(const DsStep(22, 28), weight: FontWeight.w600),
                    ),
                    if (meta != null) ...[
                      const SizedBox(height: 4),
                      Text(meta!, style: DsStyle.ui(DsText.eyebrow, color: Ds.low, tracking: DsTracking.pill)),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      );
}
