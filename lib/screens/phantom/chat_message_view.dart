import 'package:flutter/material.dart';

import '../../ds/tokens.dart';
import '../../server/dto/chat.dart';
import 'attachment_chip.dart';
import 'chat_markdown.dart';
import 'recall_rail.dart';
import 'edit_receipt.dart';
import 'saved_note_receipt.dart';

/// A user turn is a bubble on the right with its attachment chips beneath;
/// an assistant turn is prose — the recall rail above, a saved-note receipt
/// below.
class ChatMessageView extends StatelessWidget {
  const ChatMessageView({super.key, required this.message, this.steps, this.savedNotes, this.edits});

  final ChatMessage message;

  /// The recall behind an assistant turn, live transcript only.
  final List<ChatToolStep>? steps;
  final List<ChatSavedNote>? savedNotes;

  /// Chapters and world-bible cards the turn changed. Same receipt shape.
  final ChatTurnEdits? edits;

  @override
  Widget build(BuildContext context) {
    if (message.role == ChatRole.user) return _UserTurn(message: message);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (steps case final s? when s.isNotEmpty) RecallRail(steps: s, live: false),
          ChatMarkdown(message.text),
          if (savedNotes case final n?) SavedNoteReceipt(notes: n),
          if (edits case final e?) EditReceipt(edits: e),
        ],
      ),
    );
  }
}

class _UserTurn extends StatelessWidget {
  const _UserTurn({required this.message});
  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final maxWidth = MediaQuery.sizeOf(context).width * 0.86;
    final text = message.text.trim();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (text.isNotEmpty)
            Container(
              constraints: BoxConstraints(maxWidth: maxWidth),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Ds.accentMix(14),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(DsGeom.radius),
                  topRight: Radius.circular(DsGeom.radius),
                  bottomLeft: Radius.circular(DsGeom.radius),
                  bottomRight: Radius.circular(4),
                ),
              ),
              child: Text(message.text, style: DsStyle.ui(DsText.body, color: Ds.hi)),
            ),
          if (message.attachments.isNotEmpty)
            Padding(
              padding: EdgeInsets.only(top: text.isNotEmpty ? 6 : 0),
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxWidth),
                child: Wrap(
                  alignment: WrapAlignment.end,
                  spacing: 6,
                  runSpacing: 6,
                  children: [for (final a in message.attachments) AttachmentChip(key: ValueKey(a.id), attachment: a)],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
