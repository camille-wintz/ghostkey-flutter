import 'package:flutter/material.dart';

import '../../chat/live_answer.dart';
import '../../chat/questions.dart';
import '../../ds/tokens.dart';
import '../../server/dto/chat_conversation.dart';
import 'chat_message_view.dart';
import 'pending_turn_view.dart';
import 'task_message_row.dart';

/// The conversation, newest at the bottom: the author's messages, the
/// answers (the one being written drawn live), and the tasks answers handed
/// off — and, between a send and its answer's first word, the wait.
///
/// Reversed on purpose: a reversed list anchors to its end, so a streamed
/// word, a landed answer or a conversation just opened is on screen without a
/// scroll-to-end after every content change — and an author who scrolled up
/// to re-read is not dragged back down by each frame. Offset 0 is the
/// bottom; the screen jumps there when a message lands or a chat opens.
class ChatThread extends StatelessWidget {
  const ChatThread({
    super.key,
    required this.messages,
    required this.live,
    required this.busy,
    required this.loading,
    required this.controller,
    required this.intro,
    required this.onAnswer,
  });

  final List<ChatMessage> messages;

  /// The answer being written, if any. Without an id it has no row yet and
  /// is drawn after everything else.
  final LiveAnswer? live;

  /// Sending or answering: an answer's questions wait.
  final bool busy;

  /// A conversation just opened, not read yet.
  final bool loading;
  final ScrollController controller;

  /// What the empty thread shows instead of nothing.
  final Widget intro;

  /// Sends the answers to the last answer's questions as the next message.
  final ValueChanged<String> onAnswer;

  @override
  Widget build(BuildContext context) {
    final live = this.live;
    final waiting = live != null && live.id == null;
    if (messages.isEmpty && !waiting) {
      if (loading) {
        return Center(
          child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Ds.accent)),
        );
      }
      return SingleChildScrollView(
        controller: controller,
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        child: intro,
      );
    }
    final waitingRows = waiting ? 1 : 0;
    final answerable = busy ? null : openQuestionsAt(messages);
    return ListView.builder(
      controller: controller,
      reverse: true,
      padding: const EdgeInsets.symmetric(vertical: 8),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      itemCount: messages.length + waitingRows,
      itemBuilder: (context, i) {
        if (waiting && i == 0) return PendingTurnView(key: const ValueKey('pending'), live: live);
        final index = messages.length - 1 - (i - waitingRows);
        final message = messages[index];
        final key = ValueKey(message.id);
        return switch (message.role) {
          ChatRole.task => TaskMessageRow(key: key, message: message),
          ChatRole.unknown => SizedBox.shrink(key: key),
          _ when live != null && live.id == message.id => PendingTurnView(key: key, live: live),
          _ => ChatMessageView(key: key, message: message, onAnswer: index == answerable ? onAnswer : null),
        };
      },
    );
  }
}
