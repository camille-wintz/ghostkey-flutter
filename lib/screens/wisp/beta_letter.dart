import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/chapter_title.dart';
import '../../ds/tokens.dart';
import '../../server/dto/wisp.dart';
import '../../ui/press.dart';
import 'quoted_passage.dart';
import 'report_card.dart';

/// A beta reader's letter: the letter itself, their questions answered, the
/// way into the book with their comments in the margin, and where they'd have
/// put the book down. A preview carries only the letter's first paragraph, so
/// the rest simply isn't drawn.
class BetaLetter extends StatelessWidget {
  const BetaLetter({
    super.key,
    required this.report,
    required this.readerName,
    this.commentCount,
    this.onReadBook,
  });
  final AnalysisReport report;
  final String readerName;

  /// Every comment the reader left, held-back ones included; null until known.
  final int? commentCount;

  /// Opens the book with the comments on its pages; null draws no way in.
  final VoidCallback? onReadBook;

  static Widget _heading(String text) => Padding(
        padding: const EdgeInsets.only(top: 24, bottom: 10),
        child: Text(text.toUpperCase(), style: DsStyle.eyebrow()),
      );

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ReportCard(
            padding: const EdgeInsets.fromLTRB(18, 8, 18, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final para in report.letterParagraphs)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(para, style: DsStyle.prose(DsText.body, color: Ds.soft)),
                  ),
              ],
            ),
          ),
          if (report.answers.isNotEmpty) ...[
            _heading('My questions'),
            for (final answer in report.answers)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: ReportCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(answer.question, style: DsStyle.prose(const DsStep(19, 25), color: Ds.hi)),
                      if (answer.answer.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(answer.answer, style: DsStyle.prose(DsText.body, color: Ds.soft)),
                      ],
                      for (final quote in answer.quotes) QuotedPassage(quote),
                    ],
                  ),
                ),
              ),
          ],
          if (onReadBook != null) ...[
            _heading('In the margin'),
            _ReadTheBook(readerName: readerName, commentCount: commentCount, onPressed: onReadBook!),
          ],
          if (report.putDown case final putDown?) ...[
            _heading("Where I'd have put it down"),
            ReportCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    chapterLabel(putDown.chapter),
                    style: DsStyle.ui(DsText.ui, color: Ds.ink, weight: FontWeight.w600),
                  ),
                  if (putDown.why.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(putDown.why, style: DsStyle.prose(DsText.body, color: Ds.soft)),
                  ],
                ],
              ),
            ),
          ],
        ],
      );
}

/// The way from the letter into the book, the reader's comments on its pages.
class _ReadTheBook extends StatelessWidget {
  const _ReadTheBook({required this.readerName, required this.commentCount, required this.onPressed});
  final String readerName;
  final int? commentCount;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final count = commentCount;
    return Press(
      onPressed: onPressed,
      semanticLabel: "Read the book with $readerName's comments",
      builder: (context, pressed) => AnimatedContainer(
        duration: DsMotion.duration,
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(18, 16, 14, 16),
        decoration: BoxDecoration(
          color: pressed ? Ds.surf : Ds.panel,
          border: Border.all(color: pressed ? Ds.edgeHi : Ds.edge),
          borderRadius: BorderRadius.circular(DsGeom.radius),
        ),
        child: Row(
          children: [
            Icon(LucideIcons.bookOpen, size: 18, color: Ds.accent),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Read the book with $readerName's comments",
                    style: DsStyle.prose(const DsStep(17, 23), color: Ds.hi),
                  ),
                  if (count != null && count > 0) ...[
                    const SizedBox(height: 2),
                    Text(
                      count == 1 ? '1 comment' : '$count comments',
                      style: DsStyle.ui(DsText.eyebrow, color: Ds.low),
                    ),
                  ],
                ],
              ),
            ),
            Icon(LucideIcons.chevronRight, size: 18, color: Ds.mid),
          ],
        ),
      ),
    );
  }
}
