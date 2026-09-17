import 'package:flutter/material.dart';

import '../../ds/tokens.dart';
import '../../server/dto/wisp.dart';
import 'expectation_status_chip.dart';
import 'report_card.dart';

/// The genres the book sits in, and for each the reader expectations it
/// keeps, turns or leaves alone — primary genre first.
class GenreReport extends StatelessWidget {
  const GenreReport({super.key, required this.report});
  final AnalysisReport report;

  @override
  Widget build(BuildContext context) {
    final genres = [...report.genres.where((g) => g.primary), ...report.genres.where((g) => !g.primary)];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (report.overview.isNotEmpty) ...[
          Text(report.overview, style: DsStyle.prose(DsText.body, color: Ds.soft)),
          const SizedBox(height: 18),
        ],
        for (final genre in genres)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: ReportCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(genre.primary ? 'PRIMARY GENRE' : 'SECONDARY', style: DsStyle.eyebrow()),
                  const SizedBox(height: 4),
                  Text(genre.name, style: DsStyle.prose(const DsStep(22, 28), color: Ds.hi)),
                  if (genre.why.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(genre.why, style: DsStyle.prose(DsText.body, color: Ds.mid)),
                  ],
                  const SizedBox(height: 10),
                  for (final e in genre.expectations)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(border: Border(top: BorderSide(color: Ds.edge))),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ExpectationStatusChip(status: e.status),
                          const SizedBox(height: 6),
                          Text(e.expectation, style: DsStyle.ui(DsText.ui, color: Ds.ink)),
                          if (e.how.isNotEmpty) ...[
                            const SizedBox(height: 3),
                            Text(e.how, style: DsStyle.prose(DsText.body, color: Ds.soft)),
                          ],
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
