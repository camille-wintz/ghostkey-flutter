/// Where the chat room opens when a door elsewhere sends the author into it:
/// a conversation, and the first thing said in it. The desk's generic
/// `?session=…&ask=…` — the chat does not know who asked.
class ChatArrival {
  const ChatArrival({required this.sessionId, this.ask});
  final String sessionId;

  /// Sent as the author's message once the conversation is open.
  final String? ask;
}
