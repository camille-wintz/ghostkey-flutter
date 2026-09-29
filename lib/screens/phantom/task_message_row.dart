import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../ds/tokens.dart';
import '../../server/dto/chat_conversation.dart';

/// A change an answer handed to a task — the outline, the waiting chapters,
/// a pass over a chapter — as a line in the conversation: its label while it
/// runs, its own one-line receipt when it lands. The status is the task's
/// job's, read with the conversation; the conversation owner re-reads when
/// that job moves.
class TaskMessageRow extends StatelessWidget {
  const TaskMessageRow({super.key, required this.message});
  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final label = message.label ?? 'A change';
    final (color, line) = switch (message.status) {
      ChatMessageStatus.running || ChatMessageStatus.queued => (Ds.attention, '$label…'),
      ChatMessageStatus.error || ChatMessageStatus.cancelled => (Ds.destructive, "$label didn't land"),
      ChatMessageStatus.done => (Ds.done, message.summary ?? label),
      _ => (Ds.faint, message.summary ?? label),
    };
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          Icon(LucideIcons.scrollText, size: 13, color: color),
          const SizedBox(width: 6),
          Expanded(child: Text(line, style: DsStyle.ui(DsText.ui, color: Ds.mid))),
        ],
      ),
    );
  }
}
