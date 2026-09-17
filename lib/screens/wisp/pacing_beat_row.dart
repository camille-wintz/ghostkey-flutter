import 'package:flutter/material.dart';

import '../../core/chapter_title.dart';
import '../../ds/tokens.dart';
import '../../server/dto/wisp.dart';

/// One chapter on the wave: its name, what the reading says about it, and
/// its intensity as a short bar.
class PacingBeatRow extends StatelessWidget {
  const PacingBeatRow({super.key, required this.index, required this.beat, required this.divider});
  final int index;
  final PacingBeat beat;
  final bool divider;

  @override
  Widget build(BuildContext context) {
    final intensity = beat.intensity;
    final shown = intensity == intensity.roundToDouble() ? intensity.toInt().toString() : intensity.toStringAsFixed(1);
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(border: divider ? Border(top: BorderSide(color: Ds.edge)) : null),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SizedBox(
                width: 24,
                child: Text('${index + 1}', style: DsStyle.ui(DsText.ui, color: Ds.low)),
              ),
              Expanded(
                child: Text(
                  chapterLabel(beat.chapter),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: DsStyle.ui(DsText.ui, color: Ds.ink),
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                width: 64,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(DsGeom.radiusRound),
                  child: LinearProgressIndicator(
                    value: intensity / 10,
                    minHeight: 5,
                    color: Ds.accent,
                    backgroundColor: Ds.surf,
                  ),
                ),
              ),
              SizedBox(
                width: 28,
                child: Text(shown, textAlign: TextAlign.right, style: DsStyle.ui(DsText.eyebrow, color: Ds.low)),
              ),
            ],
          ),
          if (beat.note.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 24, top: 4),
              child: Text(beat.note, style: DsStyle.prose(DsText.body, color: Ds.mid)),
            ),
        ],
      ),
    );
  }
}
