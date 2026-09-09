import '../server/dto/chat.dart';

final RegExp _whitespaceRun = RegExp(r'\s+');

/// The title a session is born with: the first user message on one trimmed,
/// length-capped line — or the first attachment's title when the message was
/// an attachment and nothing else. A placeholder, not a second titler: the
/// model names the conversation properly a moment later, and this is what
/// the session keeps if that call fails, which is why it is a readable line
/// rather than "New chat" wherever it can be.
String placeholderTitle(ChatMessage? firstUser) {
  var source = firstUser?.text.trim() ?? '';
  if (source.isEmpty) source = firstUser?.attachments.firstOrNull?.title ?? '';
  final oneLine = source.replaceAll(_whitespaceRun, ' ').trim();
  if (oneLine.isEmpty) return 'New chat';
  return oneLine.length > 60 ? '${oneLine.substring(0, 60)}…' : oneLine;
}
