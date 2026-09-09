import 'package:flutter_test/flutter_test.dart';
import 'package:ghostkey/editor/inline_markdown.dart';

void main() {
  group('toggleInline', () {
    test('wraps a selection', () {
      final r = toggleInline('hello world', (start: 0, end: 5), InlineMarker.bold);
      expect(r.text, '**hello** world');
      expect((r.start, r.end), (2, 7));
    });

    test('unwraps markers inside the selection', () {
      final r = toggleInline('**hello** world', (start: 0, end: 9), InlineMarker.bold);
      expect(r.text, 'hello world');
      expect((r.start, r.end), (0, 5));
    });

    test('unwraps markers just outside the selection', () {
      final r = toggleInline('**hello** world', (start: 2, end: 7), InlineMarker.bold);
      expect(r.text, 'hello world');
      expect((r.start, r.end), (0, 5));
    });

    test('markers hug the text: surrounding spaces stay outside', () {
      final r = toggleInline('a  b  c', (start: 1, end: 6), InlineMarker.italic);
      expect(r.text, 'a  *b*  c');
    });

    test('a caret gets an empty pair to type into', () {
      final r = toggleInline('ab', (start: 1, end: 1), InlineMarker.italic);
      expect(r.text, 'a**b');
      expect((r.start, r.end), (2, 2));
    });

    test('pressing again on the empty pair removes it', () {
      final r = toggleInline('a****b', (start: 3, end: 3), InlineMarker.bold);
      expect(r.text, 'ab');
      expect((r.start, r.end), (1, 1));
    });

    test('a caret before a closing marker steps over it', () {
      final r = toggleInline('**word**', (start: 6, end: 6), InlineMarker.bold);
      expect(r.text, '**word**');
      expect((r.start, r.end), (8, 8));
    });

    test('a lone half of ** is not an italic marker', () {
      expect(isWrapped('**ab', (start: 3, end: 3), InlineMarker.italic), isFalse);
      expect(isWrapped('**ab', (start: 3, end: 3), InlineMarker.bold), isTrue);
    });

    test('a caret inside an unclosed run reads as wrapped', () {
      expect(isWrapped('one *two thr', (start: 10, end: 10), InlineMarker.italic), isTrue);
      expect(isWrapped('one *two* thr', (start: 12, end: 12), InlineMarker.italic), isFalse);
    });

    test('***both*** counts for bold and italic', () {
      expect(isWrapped('***x***', (start: 3, end: 4), InlineMarker.bold), isTrue);
      expect(isWrapped('***x***', (start: 3, end: 4), InlineMarker.italic), isTrue);
    });
  });
}
