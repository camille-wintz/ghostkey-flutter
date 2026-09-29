import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../ds/tokens.dart';

/// One quiet line under an answer that did not finish — stopped, cut off,
/// or refused when its turn came up. The error bar's colour, none of its
/// weight: it is part of the conversation, not something to dismiss.
class AnswerEndNote extends StatelessWidget {
  const AnswerEndNote({super.key, required this.line});
  final String line;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Icon(LucideIcons.circleSlash, size: 13, color: Ds.destructive),
            ),
            const SizedBox(width: 6),
            Expanded(child: Text(line, style: DsStyle.ui(DsText.ui, color: Ds.destructive))),
          ],
        ),
      );
}
