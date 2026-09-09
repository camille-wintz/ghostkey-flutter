import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../ds/tokens.dart';
import '../../ui/press.dart';
import '../../ui/text.dart';

/// The entity page's top row: the way back UP to the roster, not out to the
/// project. The roster itself wears the shared [RoomHeader] — this one exists
/// because a page one level deeper must go back one level, and saying "the
/// book" there would skip the list the reader came from.
class VeilHeader extends StatelessWidget {
  const VeilHeader({super.key, required this.backLabel, required this.onBack, required this.eyebrow});

  final String backLabel;
  final VoidCallback onBack;
  final String eyebrow;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: Row(
        children: [
          const SizedBox(width: 10),
          Press(
            onPressed: onBack,
            semanticLabel: 'Back',
            builder: (context, pressed) => Container(
              height: 44,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                color: pressed ? Ds.veil : const Color(0x00000000),
                borderRadius: BorderRadius.circular(DsGeom.radius),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(LucideIcons.chevronLeft, size: 17, color: Ds.mid),
                  const SizedBox(width: 4),
                  UiText(backLabel, color: Ds.mid),
                ],
              ),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Align(
              alignment: Alignment.centerLeft,
              child: Eyebrow(eyebrow, color: Ds.accent300),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
    );
  }
}
