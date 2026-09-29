import '../server/dto/chat_conversation.dart';

/// The line under an answer that did not finish: stopped, cut off, refused.
/// Null for one that did. Never the wire code — the author did nothing wrong
/// and needs only to know the words above are all there is.
String? answerEndLine(ChatMessage answer) {
  if (answer.role != ChatRole.assistant) return null;
  return switch (answer.status) {
    ChatMessageStatus.stopped => answer.text.trim().isEmpty ? 'Stopped before it said anything.' : 'Stopped here.',
    ChatMessageStatus.error => switch (answer.error) {
        'interrupted' => 'This answer was cut off. Ask again to pick it up.',
        'quota_exceeded' => "This week's chat messages ran out before this one was answered.",
        'plan_insufficient' => "This one wasn't answered: that model isn't part of your plan.",
        _ => answer.text.trim().isEmpty ? "This one wasn't answered. Ask again." : 'This answer stopped short.',
      },
    _ => null,
  };
}
