import 'package:flutter/material.dart';

import '../../../core/words.dart';
import '../../../ds/tokens.dart';
import '../../../poltergeist/time.dart';
import '../../../server/dto/poltergeist.dart';

/// One ruled day of the ledger. The bar lives behind the figure rather than
/// beside it: the column reads as a shape and states the exact count at the
/// same time. Amber, like the week's columns — same reading, same hue.
class LedgerRow extends StatelessWidget {
  const LedgerRow({super.key, required this.day, required this.peak, required this.isToday});
  final WordStatsDay day;

  /// The trailing week's busiest day; older days above it clip at full width.
  final int peak;
  final bool isToday;

  @override
  Widget build(BuildContext context) {
    final worked = day.written > 0;
    final fill = worked ? (day.written / peak).clamp(0.015, 1.0) : 0.0;
    final ink = !worked
        ? Ds.faint
        : isToday
            ? Ds.attention300
            : Ds.soft;
    return Container(
      height: 36,
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Ds.edge))),
      child: Stack(
        fit: StackFit.expand,
        children: [
          FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: fill,
            child: ColoredBox(color: Ds.attentionMix(9)),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    dayLabel(day.day),
                    style: DsStyle.ui(DsText.ui, color: isToday ? Ds.attention300 : Ds.low),
                  ),
                ),
                Text(
                  worked ? formatWords(day.written) : '—',
                  style: DsStyle.ui(DsText.ui, color: ink).copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
