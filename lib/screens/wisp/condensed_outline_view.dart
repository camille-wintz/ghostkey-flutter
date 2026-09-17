import 'package:flutter/material.dart';

import '../../core/words.dart';
import '../../ds/tokens.dart';
import '../../server/dto/wisp.dart';
import 'report_card.dart';

/// A synopsis or extended outline: one card of continuous prose that reads
/// straight through, the way the chapter cards deliberately don't.
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
            const SizedBox(height: 14),
            for (final para in outline.text.split(RegExp(r'\n{2,}')).map((p) => p.trim()).where((p) => p.isNotEmpty))
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(para, style: DsStyle.prose(DsText.body, color: Ds.soft)),
              ),
          ],
        ),
      );
}
