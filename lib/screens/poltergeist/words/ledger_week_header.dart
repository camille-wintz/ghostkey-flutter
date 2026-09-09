import 'package:flutter/material.dart';

import '../../../core/words.dart';
import '../../../ds/tokens.dart';
import '../../../poltergeist/ledger.dart';

/// The rule between weeks: the week's name and what it holds.
class LedgerWeekHeader extends StatelessWidget {
  const LedgerWeekHeader({super.key, required this.week});
  final LedgerWeek week;

  @override
  Widget build(BuildContext context) => Container(
        height: DsGeom.row,
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Ds.edgeHi))),
        child: Row(
          children: [
            Expanded(child: Text(week.label.toUpperCase(), style: DsStyle.eyebrow(weight: FontWeight.w600))),
            Text(
              week.written > 0 ? '${formatWords(week.written)} words' : 'quiet',
              style: DsStyle.ui(DsText.eyebrow, color: week.written > 0 ? Ds.mid : Ds.faint, tracking: 11 * 0.12)
                  .copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
            ),
          ],
        ),
      );
}
