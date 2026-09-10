import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../chat/attachments.dart';
import '../../ds/tokens.dart';
import '../../server/dto/chat.dart';

/// What the assistant changed in the project this turn besides notes: a
/// passage of a chapter, a chapter it wrote, a world-bible card. Receipts, not prompts — each
/// write happened on the author's say-so before the turn resolved.
class EditReceipt extends StatelessWidget {
  const EditReceipt({super.key, required this.edits});
  final ChatTurnEdits edits;

  @override
  Widget build(BuildContext context) {
    if (edits.isEmpty) return const SizedBox.shrink();
    final rows = <(IconData, Color, String, String, String)>[
      for (final e in edits.chapterEdits)
        e.created
            ? (LucideIcons.filePlus, Ds.attention, 'Wrote ', stripMd(e.filename), ' into the manuscript')
            : (LucideIcons.filePen, Ds.attention, 'Edited a passage of ', stripMd(e.filename), ' in the manuscript'),
      for (final e in edits.bibleEdits) (LucideIcons.bookMarked, Ds.done, e.created ? 'Added ' : 'Updated ', e.name, ' in the world bible'),
    ];
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < rows.length; i++)
            Padding(
              padding: EdgeInsets.only(top: i == 0 ? 0 : 4),
              child: Row(
                children: [
                  Icon(rows[i].$1, size: 13, color: rows[i].$2),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text.rich(
                      TextSpan(
                        text: rows[i].$3,
                        children: [
                          TextSpan(text: rows[i].$4, style: TextStyle(color: Ds.hi)),
                          TextSpan(text: rows[i].$5),
                        ],
                      ),
                      style: DsStyle.ui(DsText.ui, color: Ds.mid),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
