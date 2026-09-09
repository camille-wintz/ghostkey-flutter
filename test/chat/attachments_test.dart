import 'package:flutter_test/flutter_test.dart';
import 'package:ghostkey/chat/attachments.dart';

String words(int n) => List.generate(n, (i) => 'w$i').join(' ');

void main() {
  group('mintAttachmentId', () {
    test('starts at a1', () => expect(mintAttachmentId(const []), 'a1'));
    test('skips every handle the session has spent', () {
      expect(mintAttachmentId(['a1', 'a2']), 'a3');
      expect(mintAttachmentId(['a2']), 'a1');
      expect(mintAttachmentId(['a1', 'a3']), 'a2');
    });
  });

  group('the paste rule', () {
    test('is a word threshold', () {
      expect(isLongPaste(words(pasteAttachmentMinWords - 1)), isFalse);
      expect(isLongPaste(words(pasteAttachmentMinWords)), isTrue);
    });
    test('names a paste after its first non-empty line, capped', () {
      expect(pasteTitle('\n\n  Chapter Nine  \nmore'), 'Chapter Nine');
      expect(pasteTitle('   '), 'Pasted text');
      final long = pasteTitle('${'x' * 60}\nrest');
      expect(long.length, 49);
      expect(long.endsWith('…'), isTrue);
      expect(pasteTitle('many   spaces\there'), 'many spaces here');
    });
    test('caps a paste and marks the cut', () {
      final short = 'a' * 10;
      expect(capPasteText(short), short);
      final capped = capPasteText('b' * (pasteAttachmentMaxChars + 5));
      expect(capped.startsWith('b' * pasteAttachmentMaxChars), isTrue);
      expect(capped.contains('truncated'), isTrue);
      expect(capped.contains('b' * (pasteAttachmentMaxChars + 1)), isFalse);
    });
  });

  group('insertedRun', () {
    test('finds a run inserted in the middle and takes it back out', () {
      final run = insertedRun('hello world', 'hello BIG world');
      expect(run, isNotNull);
      expect(run!.inserted, 'BIG ');
      expect(run.without, 'hello world');
      expect(run.start, 6);
    });
    test('is null for a deletion or an unchanged value', () {
      expect(insertedRun('abc', 'ab'), isNull);
      expect(insertedRun('abc', 'abc'), isNull);
    });
    test('an appended run keeps the caret at its start', () {
      final run = insertedRun('ab', 'abcd');
      expect(run!.inserted, 'cd');
      expect(run.without, 'ab');
      expect(run.start, 2);
    });
    test('a replaced selection drops the replaced text from `without`', () {
      // "cat" selected and replaced by a long run: the run is the insertion,
      // and what remains is the text minus the selection.
      final run = insertedRun('the cat sat', 'the LONG RUN HERE sat');
      expect(run!.inserted, 'LONG RUN HERE');
      expect(run.without, 'the  sat');
    });
  });

  test('stripMd drops only a trailing .md', () {
    expect(stripMd('Chapter 1.md'), 'Chapter 1');
    expect(stripMd('Chapter 1.MD'), 'Chapter 1');
    expect(stripMd('notes.md.bak'), 'notes.md.bak');
  });
}
