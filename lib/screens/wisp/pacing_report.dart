import 'package:flutter/material.dart';

import '../../core/chapter_title.dart';
import '../../ds/tokens.dart';
import '../../server/dto/wisp.dart';
import 'pacing_beat_row.dart';
import 'pacing_wave.dart';
import 'report_card.dart';

/// The wave, what it adds up to, the stretches it falls into, and every
/// chapter's place on it.
class PacingReport extends StatelessWidget {
  const PacingReport({super.key, required this.report});
  final AnalysisReport report;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (report.beats.isNotEmpty) ...[PacingWave(beats: report.beats), const SizedBox(height: 18)],
          if (report.overview.isNotEmpty) ...[
            Text(report.overview, style: DsStyle.prose(DsText.body, color: Ds.soft)),
            const SizedBox(height: 22),
          ],
          if (report.stretches.isNotEmpty) ...[
            Text('THE STRETCHES', style: DsStyle.eyebrow()),
            const SizedBox(height: 10),
            for (final s in report.stretches)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: ReportCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(s.shape, style: DsStyle.prose(const DsStep(18, 24), color: Ds.hi)),
                      const SizedBox(height: 2),
                      Text(
                        '${chapterLabel(s.from)} → ${chapterLabel(s.to)}',
                        style: DsStyle.ui(DsText.eyebrow, color: Ds.low),
                      ),
                      const SizedBox(height: 8),
                      Text(s.description, style: DsStyle.prose(DsText.body, color: Ds.soft)),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 12),
          ],
          if (report.beats.isNotEmpty) ...[
            Text('CHAPTER BY CHAPTER', style: DsStyle.eyebrow()),
            const SizedBox(height: 10),
            ReportCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  for (final (i, beat) in report.beats.indexed)
                    PacingBeatRow(index: i, beat: beat, divider: i > 0),
                ],
              ),
            ),
          ],
        ],
      );
}
