import 'package:flutter_test/flutter_test.dart';
import 'package:ghostkey/chat/session_title.dart';
import 'package:ghostkey/server/dto/chat.dart';

ChatMessage user(String text, {List<ChatAttachment> attachments = const []}) =>
    ChatMessage(role: ChatRole.user, text: text, attachments: attachments);

void main() {
  group('placeholderTitle', () {
    test('is the first user message on one line', () {
      expect(placeholderTitle(user('  Where does\nthe pacing   sag?  ')), 'Where does the pacing sag?');
    });
    test('caps at 60 characters with an ellipsis', () {
      final title = placeholderTitle(user('x' * 80));
      expect(title.length, 61);
      expect(title.endsWith('…'), isTrue);
    });
    test('falls back to the first attachment when the message was only that', () {
      final chapter = ChapterAttachment(id: 'a1', title: 'Chapter 3', documentId: 'd1');
      expect(placeholderTitle(user('   ', attachments: [chapter])), 'Chapter 3');
    });
    test('is "New chat" when there is nothing to name it by', () {
      expect(placeholderTitle(null), 'New chat');
      expect(placeholderTitle(user('')), 'New chat');
    });
  });
}
