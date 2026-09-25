import 'package:flutter/material.dart';

import '../../core/chapter_title.dart';
import '../../ds/tokens.dart';
import '../../server/dto/wisp.dart';
import 'chapter_chips.dart';
import 'report_card.dart';
import 'report_section.dart';

/// The themes, each as what the book says, the machinery that says it, how it
/// moves from the opening to the close, and ways to take it further.
class ThemeReport extends StatelessWidget {
  const ThemeReport({super.key, required this.report});
  final AnalysisReport report;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (report.overview.isNotEmpty) ...[
            Text(report.overview, style: DsStyle.prose(DsText.body, color: Ds.soft)),
            const SizedBox(height: 18),
          ],
          for (final (i, theme) in report.themes.indexed)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: ReportCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('THEME ${i + 1}', style: DsStyle.eyebrow()),
                    const SizedBox(height: 4),
                    Text(theme.name, style: DsStyle.prose(const DsStep(22, 28), color: Ds.hi)),
                    if (theme.statement.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        theme.statement,
                        style: DsStyle.prose(DsText.body, color: Ds.mid).copyWith(fontStyle: FontStyle.italic),
                      ),
                    ],
                    ReportSection(title: 'How it works', text: theme.howItWorks),
                    ReportSection(title: 'How it develops', text: theme.development),
                    if (theme.further.isNotEmpty)
                      Container(
                        margin: const EdgeInsets.only(top: 14),
                        padding: const EdgeInsets.only(left: 12),
                        decoration: BoxDecoration(border: Border(left: BorderSide(color: Ds.accent, width: 2))),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Taking it further', style: DsStyle.ui(DsText.ui, color: Ds.ink, weight: FontWeight.w600)),
                            for (final t in theme.further)
                              Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Text(t, style: DsStyle.prose(DsText.body, color: Ds.soft)),
                              ),
                          ],
                        ),
                      ),
                    if (theme.chapters.isNotEmpty) ChapterChips(labels: theme.chapters.map(chapterLabel).toList()),
                  ],
                ),
              ),
            ),
        ],
      );
}
