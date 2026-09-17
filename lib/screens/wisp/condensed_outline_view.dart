import 'package:flutter/material.dart';

import '../../core/words.dart';
import '../../ds/tokens.dart';
import '../../server/dto/wisp.dart';
import 'report_card.dart';

/// A synopsis or extended outline: one card of continuous prose, each
/// movement a quiet label over its paragraphs — it reads straight through,
/// the way the chapter cards deliberately don't.
class CondensedOutlineView extends StatelessWidget {
  const CondensedOutlineView({super.key, required this.outline});
  final CondensedOutline outline;

  @override
  Widget build(BuildContext context) => ReportCard(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${formatWords(outline.wordCount)} words', style: DsStyle.ui(DsText.eyebrow, color: Ds.low)),
            for (final section in outline.sections) ...[
              const SizedBox(height: 22),
              Text(section.beat.label.toUpperCase(), style: DsStyle.eyebrow(color: Ds.accent, weight: FontWeight.w600)),
              for (final para in section.text.split(RegExp(r'\n{2,}')).map((p) => p.trim()).where((p) => p.isNotEmpty))
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(para, style: DsStyle.prose(DsText.body, color: Ds.soft)),
                ),
            ],
          ],
        ),
      );
}
