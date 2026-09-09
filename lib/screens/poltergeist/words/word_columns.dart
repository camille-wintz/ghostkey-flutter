import 'package:flutter/material.dart';

import '../../../core/words.dart';
import '../../../ds/tokens.dart';
import '../../../poltergeist/ledger.dart';
import '../../../poltergeist/time.dart';
import '../../../server/dto/poltergeist.dart';

/// The columns' box. With figures above them the bars keep to a fixed scale
/// so a label never collides with the rule; without, a column may fill it.
const double _boxHeight = 96;
const double _barMax = 68;

/// The words-per-day columns: the ledger's amber fill stood upright. Each
/// column rests on the ruled baseline; today burns brighter, and a day with
/// no words keeps a 2px ember so the week reads as seven days, not gaps.
/// Scaled to the trailing week's best day, so the current week always reads
/// at full size; an older, bigger day clips at full height.
///
/// Amber, not the accent: the graph is a reading, and a reading is one of the
/// few things allowed to carry colour — amber because words owed and words
/// written are the same attention surface.
class WordColumns extends StatelessWidget {
  const WordColumns({super.key, required this.days, required this.weekdayLabels, this.showValues = false});

  /// Oldest first, as the series arrives.
  final List<WordStatsDay> days;

  /// Weekday letters suit a week; days of the month suit a longer run.
  final bool weekdayLabels;

  /// Print each day's count above its column.
  final bool showValues;

  @override
  Widget build(BuildContext context) {
    final peak = weekPeak(days);
    final gap = days.length > 7 ? 2.0 : 3.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          height: _boxHeight,
          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Ds.edge))),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (var i = 0; i < days.length; i++) ...[
                if (i > 0) SizedBox(width: gap),
                Expanded(
                  child: _Column(
                    day: days[i],
                    peak: peak,
                    isToday: i == days.length - 1,
                    showValue: showValues,
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 6),
        // A phone is too narrow to name thirty columns: a long run labels
        // today and every fifth day back from it.
        Row(
          children: [
            for (var i = 0; i < days.length; i++) ...[
              if (i > 0) SizedBox(width: gap),
              Expanded(
                child: Text(
                  weekdayLabels || (days.length - 1 - i) % 5 == 0 ? columnLabel(days[i].day, weekday: weekdayLabels) : '',
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.clip,
                  style: DsStyle.ui(
                    days.length > 7 ? const DsStep(9, 12) : DsText.eyebrow,
                    color: i == days.length - 1 ? Ds.attention : Ds.faint,
                  ),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

class _Column extends StatelessWidget {
  const _Column({required this.day, required this.peak, required this.isToday, required this.showValue});
  final WordStatsDay day;
  final int peak;
  final bool isToday;
  final bool showValue;

  @override
  Widget build(BuildContext context) {
    final worked = day.written > 0;
    final share = day.written / peak;
    final height = showValue
        ? (share * _barMax).round().clamp(2, _barMax.toInt()).toDouble()
        : worked
            ? (share * _boxHeight).clamp(_boxHeight * 0.03, _boxHeight)
            : 2.0;
    final fill = isToday
        ? Ds.attention
        : worked
            ? Ds.attentionMix(38)
            : Ds.attentionMix(14);
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        if (showValue)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Opacity(
              opacity: worked ? 1 : 0,
              child: Text(
                formatWords(day.written),
                maxLines: 1,
                overflow: TextOverflow.clip,
                style: DsStyle.ui(const DsStep(9, 12), color: Ds.faint, tracking: 0.5),
              ),
            ),
          ),
        Container(height: height, color: fill),
      ],
    );
  }
}
