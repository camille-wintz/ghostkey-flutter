import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../chat/attachments.dart';
import '../../ds/tokens.dart';
import '../../server/dto/chat.dart';

/// "Saved to your notes as …" under an answer that wrote one. The note is a
/// real document already; Apparition's drawer lists it.
class SavedNoteReceipt extends StatelessWidget {
  const SavedNoteReceipt({super.key, required this.notes});
  final List<ChatSavedNote> notes;

  @override
  Widget build(BuildContext context) {
    if (notes.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < notes.length; i++)
            Padding(
              padding: EdgeInsets.only(top: i == 0 ? 0 : 4),
              child: Row(
                children: [
                  Icon(LucideIcons.stickyNote, size: 13, color: Ds.attention),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text.rich(
                      TextSpan(
                        text: 'Saved to your notes as ',
                        children: [TextSpan(text: stripMd(notes[i].filename), style: TextStyle(color: Ds.hi))],
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
