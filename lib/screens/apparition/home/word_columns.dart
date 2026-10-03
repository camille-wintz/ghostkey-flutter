import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/words.dart';
import '../../../ds/tokens.dart';
import '../../../rewards/ledger.dart';

/// The columns' box. With figures above them the bars keep to a fixed scale
/// so a label never collides with the rule; without, a column may fill it.
const double _boxHeight = 96;
const double _barMax = 68;

/// The ruled baseline is drawn INSIDE the box, so a full-height column has
/// one pixel less than the box to stand in. Without it a peak day overflows
/// by exactly 1.0 and wears the debug stripes.
const double _baseline = 1;

/// The words chart: the ledger's amber fill stood upright, a column a day (a
/// month, for the year). Each column rests on the ruled baseline; the current
/// one burns brighter, and an empty one keeps a 2px ember so the span reads
/// as its days, not gaps. Scaled to the busiest column shown.
///
/// Amber, not the accent: the graph is a reading, and a reading is one of the
/// few things allowed to carry colour — amber because words owed and words
/// written are the same attention surface.
class WordColumns extends StatelessWidget {
  const WordColumns({super.key, required this.columns, this.showValues = false, this.labelEvery = 1});

  /// Oldest first; the last is the current day or month.
  final List<WordColumn> columns;

  /// Print each column's count above it — the week, which has the room.
  final bool showValues;

  /// A phone is too narrow to name thirty columns: label the current one and
  /// every [labelEvery]th back from it.
  final int labelEvery;

  @override
  Widget build(BuildContext context) {
    final peak = columnPeak(columns);
    final last = columns.length - 1;
    // Seven columns can afford a gutter a month of thirty cannot.
    final gap = showValues ? 4.0 : (columns.length > 12 ? 2.0 : 3.0);
    final ticked = columns.any((c) => c.met);

    Widget across(Widget Function(int i, WordColumn column) cell) => Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            for (var i = 0; i < columns.length; i++) ...[
              if (i > 0) SizedBox(width: gap),
              Expanded(child: cell(i, columns[i])),
            ],
          ],
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          height: _boxHeight,
          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Ds.edge))),
          child: across((i, c) => _Column(written: c.written, peak: peak, current: i == last, showValue: showValues)),
        ),
        const SizedBox(height: 6),
        across(
          (i, c) => Text(
            (last - i) % labelEvery == 0 ? c.label : '',
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.clip,
            style: DsStyle.ui(
              showValues ? const DsStep(12, 16) : const DsStep(9, 12),
              color: i == last ? Ds.attention : Ds.faint,
            ),
          ),
        ),
        if (ticked) ...[
          const SizedBox(height: 2),
          ExcludeSemantics(
            child: across(
              (i, c) => SizedBox(
                height: 10,
                child: c.met ? Icon(LucideIcons.check, size: 10, color: Ds.attention400) : null,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _Column extends StatelessWidget {
  const _Column({required this.written, required this.peak, required this.current, required this.showValue});
  final int written;
  final int peak;
  final bool current;
  final bool showValue;

  @override
  Widget build(BuildContext context) {
    final worked = written > 0;
    final share = written / peak;
    const floor = _boxHeight - _baseline;
    final height = showValue
        ? (share * _barMax).round().clamp(2, _barMax.toInt()).toDouble()
        : worked
            ? (share * floor).clamp(_boxHeight * 0.03, floor)
            : 2.0;
    final fill = current
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
                formatWords(written),
                maxLines: 1,
                overflow: TextOverflow.clip,
                style: DsStyle.ui(
                  const DsStep(10, 13),
                  color: current ? Ds.attention400 : Ds.low,
                  tracking: 0.4,
                ),
              ),
            ),
          ),
        Container(height: height, color: fill),
      ],
    );
  }
}
