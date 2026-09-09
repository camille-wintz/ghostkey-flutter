import 'package:flutter/material.dart';

import '../../ds/tokens.dart';
import '../../server/dto/bible.dart';
import '../../ui/text.dart';
import '../../veil/tone.dart';

/// "Characters · 9" — the heading over one type's block of the roster.
class VeilGroupHeader extends StatelessWidget {
  const VeilGroupHeader({super.key, required this.type, required this.count});
  final BibleEntityType type;
  final int count;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(8, 16, 8, 6),
        child: Row(
          children: [
            Container(
              width: 6,
              height: 6,
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(color: typeTone(type), shape: BoxShape.circle),
            ),
            Eyebrow(type.plural),
            const Spacer(),
            Text('$count', style: DsStyle.ui(DsText.eyebrow, color: Ds.faint)),
          ],
        ),
      );
}
