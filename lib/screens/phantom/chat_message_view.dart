import 'package:flutter/material.dart';

import '../../chat/answer_end.dart';
import '../../ds/tokens.dart';
import '../../server/dto/chat.dart';
import '../../server/dto/chat_conversation.dart';
import 'answer_end_note.dart';
import 'attachment_chip.dart';
import 'chat_markdown.dart';
import 'recall_rail.dart';
import 'edit_receipt.dart';
import 'model_switch_note.dart';
import 'question_card.dart';
import 'saved_note_receipt.dart';

/// A message of the author's is a bubble on the right with its attachment
/// chips beneath; a finished answer is prose — the recall rail above,
/// receipts, any questions it stopped on, and a line when it did not finish.
class ChatMessageView extends StatelessWidget {
  const ChatMessageView({super.key, required this.message, this.onAnswer});

  final ChatMessage message;

  /// Set only when this answer's questions are still open to answer — the
  /// newest answer, nothing in flight. Null draws them read-only.
  final ValueChanged<String>? onAnswer;

  @override
  Widget build(BuildContext context) {
    if (message.role == ChatRole.user) return _UserTurn(message: message);
    final result = message.result;
    final edits = result?.edits;
    final ended = answerEndLine(message);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (message.steps.isNotEmpty) RecallRail(steps: message.steps, live: false),
          if (message.text.trim().isNotEmpty) ChatMarkdown(message.text),
          if (result case ChatAnswerResult(:final model?, :final switchedFrom?))
            ModelSwitchNote(modelSwitch: (model: model, from: switchedFrom)),
          if (result != null && result.savedNotes.isNotEmpty) SavedNoteReceipt(notes: result.savedNotes),
          if (edits != null && !edits.isEmpty) EditReceipt(edits: edits),
          if (message.questions.isNotEmpty) QuestionCard(questions: message.questions, onAnswer: onAnswer),
          if (ended != null) AnswerEndNote(line: ended),
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
