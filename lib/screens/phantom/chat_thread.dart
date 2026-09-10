import 'package:flutter/material.dart';

import '../../chat/turn.dart';
import '../../server/dto/chat.dart';
import 'chat_message_view.dart';
import 'pending_turn_view.dart';

/// The transcript, newest at the bottom, with the in-flight turn after it.
///
/// Reversed on purpose: a reversed list anchors to its end, so a streamed
/// token, a landed answer or a session just opened is on screen without a
/// scroll-to-end after every content change — and an author who scrolled up
/// to re-read is not dragged back down by each frame. Offset 0 is the
/// bottom; the screen jumps there when a turn starts or a session opens.
class ChatThread extends StatelessWidget {
  const ChatThread({
    super.key,
    required this.messages,
    required this.stepsByIndex,
    required this.notesByIndex,
    required this.editsByIndex,
    required this.pending,
    required this.controller,
    required this.intro,
  });

  final List<ChatMessage> messages;
  final Map<int, List<ChatToolStep>> stepsByIndex;
  final Map<int, List<ChatSavedNote>> notesByIndex;
  final Map<int, ChatTurnEdits> editsByIndex;
  final PendingTurn? pending;
  final ScrollController controller;

  /// What the empty thread shows instead of nothing.
  final Widget intro;

  @override
  Widget build(BuildContext context) {
    final pending = this.pending;
    if (messages.isEmpty && pending == null) {
      return SingleChildScrollView(
        controller: controller,
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        child: intro,
      );
    }
    final pendingRows = pending == null ? 0 : 1;
    return ListView.builder(
      controller: controller,
      reverse: true,
      padding: const EdgeInsets.symmetric(vertical: 8),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      itemCount: messages.length + pendingRows,
      itemBuilder: (context, i) {
        if (pending != null && i == 0) return PendingTurnView(key: const ValueKey('pending'), pending: pending);
        final index = messages.length - 1 - (i - pendingRows);
        return ChatMessageView(
          key: ValueKey(index),
          message: messages[index],
          steps: stepsByIndex[index],
          savedNotes: notesByIndex[index],
          edits: editsByIndex[index],
        );
      },
    );
  }
}
