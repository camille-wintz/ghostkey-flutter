import 'package:flutter/material.dart';

import '../../core/chapter_title.dart';
import '../../core/words.dart';
import '../../ds/tokens.dart';
import '../../server/dto/wisp.dart';
import 'report_card.dart';

/// One chapter of the detailed outline, numbered on the book's spine: an
/// ordered list, because chapter order is the information.
class ChapterOutlineCard extends StatelessWidget {
  const ChapterOutlineCard({super.key, required this.chapter, required this.index, required this.isLast});
  final ChapterOutline chapter;
  final int index;
  final bool isLast;

  /// The outline marks a chapter's one carried-over line with `*emphasis*`.
  static List<TextSpan> _withEmphasis(String text, TextStyle style) {
    final parts = text.split(RegExp(r'\*([^*\n]+)\*'));
    final matches = RegExp(r'\*([^*\n]+)\*').allMatches(text).toList();
    return [
      for (var i = 0; i < parts.length; i++) ...[
        TextSpan(text: parts[i], style: style),
        if (i < matches.length) TextSpan(text: matches[i].group(1), style: style.copyWith(fontStyle: FontStyle.italic)),
      ],
    ];
  }

  @override
  Widget build(BuildContext context) {
    final heading = chapterTitle(chapter.chapter, index);
    final style = DsStyle.prose(DsText.body, color: Ds.soft);
    final paragraphs = chapter.summary.split(RegExp(r'\n{2,}')).map((p) => p.trim()).where((p) => p.isNotEmpty);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 34,
            child: Column(
              children: [
                const SizedBox(height: 14),
                Container(
                  width: 30,
                  height: 30,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Ds.surf,
                    shape: BoxShape.circle,
                    border: Border.all(color: Ds.edge),
                  ),
                  child: Text('${index + 1}', style: DsStyle.ui(DsText.ui, color: Ds.accent, weight: FontWeight.w600)),
                ),
                if (!isLast) Expanded(child: Container(width: 1, color: Ds.edgeHi)),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: ReportCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(heading.label.toUpperCase(), style: DsStyle.eyebrow(color: Ds.accent, weight: FontWeight.w600)),
                        ),
                        if (chapter.wordCount case final words?)
                          Text('${formatWords(words)} words', style: DsStyle.ui(DsText.eyebrow, color: Ds.low)),
                      ],
                    ),
                    if (heading.title case final title?) ...[
                      const SizedBox(height: 3),
                      Text(title, style: DsStyle.prose(const DsStep(18, 24), color: Ds.hi)),
                    ],
                    if (paragraphs.isEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: Text(
                          'No summary returned for this chapter.',
                          style: DsStyle.ui(DsText.ui, color: Ds.low).copyWith(fontStyle: FontStyle.italic),
                        ),
                      )
                    else
                      for (final para in paragraphs)
                        Padding(
                          padding: const EdgeInsets.only(top: 10),
                          child: Text.rich(TextSpan(children: _withEmphasis(para, style))),
                        ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
