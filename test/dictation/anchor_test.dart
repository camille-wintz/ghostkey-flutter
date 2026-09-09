import 'package:flutter_test/flutter_test.dart';
import 'package:ghostkey/core/typography.dart';
import 'package:ghostkey/dictation/anchor.dart';

void main() {
  group('mapAnchor', () {
    // The nine cases the parity plan names: insert / delete / replace, each
    // before, after and across the point. The document is "abcdefgh" with the
    // point at 4 (between d and e).
    const doc = 'abcdefgh';
    const at = 4;

    test('insert before the point shifts it by the insertion', () {
      expect(mapAnchor(doc, 'abXYcdefgh', at), 6);
    });
    test('insert after the point leaves it', () {
      expect(mapAnchor(doc, 'abcdefXYgh', at), at);
    });
    test('insert exactly at the point moves it past the inserted text', () {
      expect(mapAnchor(doc, 'abcdXYefgh', at), 6);
    });
    test('delete before the point shifts it back', () {
      expect(mapAnchor(doc, 'acdefgh', at), 3);
    });
    test('delete after the point leaves it', () {
      expect(mapAnchor(doc, 'abcdegh', at), at);
    });
    test('delete across the point lands it at the cut', () {
      expect(mapAnchor(doc, 'abfgh', at), 2);
    });
    test('replace before the point shifts it by the size difference', () {
      expect(mapAnchor(doc, 'aXYZdefgh', at), 5);
    });
    test('replace after the point leaves it', () {
      expect(mapAnchor(doc, 'abcdeXYZ', at), at);
    });
    test('replace across the point lands it after the replacement', () {
      expect(mapAnchor(doc, 'abXfgh', at), 3);
    });
    test('an unchanged document is a no-op', () {
      expect(mapAnchor(doc, doc, at), at);
    });
  });

  group('planLanding', () {
    test('a leading space keeps chunks from running together', () {
      final p = planLanding('One sentence', 12, 'and another', TypographyMode.none);
      expect(p.mark, '');
      expect(p.insert, ' and another');
      expect(p.insertAt, 12);
      expect(p.point, 24);
    });
    test('no space after whitespace or into an empty document', () {
      expect(planLanding('One ', 4, 'two', TypographyMode.none).insert, 'two');
      expect(planLanding('', 0, 'Two', TypographyMode.none).insert, 'Two');
    });
    test('no space before a chunk opening on a paragraph break', () {
      final p = planLanding('One', 3, '\n\nTwo', TypographyMode.none);
      expect(p.insert, '\n\nTwo');
    });
    test('a break-only chunk lands as itself', () {
      expect(planLanding('One', 3, '\n\n', TypographyMode.none).insert, '\n\n');
    });
    test('a leading closing mark goes on the last word, ahead of the gap', () {
      final p = planLanding('She left\n\n', 10, '. He stayed', TypographyMode.none);
      expect(p.mark, '.');
      expect(p.markAt, 8);
      expect(p.insertAt, 11);
      expect(p.insert, 'He stayed');
      expect(p.point, 'She left.\n\nHe stayed'.length);
    });
    test('the mark is dropped when the word before already carries punctuation', () {
      final p = planLanding('She left,', 9, '. he stayed', TypographyMode.none);
      expect(p.mark, '');
      expect(p.insert, ' he stayed');
    });
    test('the mark is dropped with nothing before it', () {
      final p = planLanding('', 0, '. Start', TypographyMode.none);
      expect(p.mark, '');
      expect(p.insert, 'Start');
    });
    test('typography runs with quote parity read from the text before', () {
      final p = planLanding('She said, "wait', 15, 'for me," he said', TypographyMode.curly);
      expect(p.insert, ' for me,” he said');
    });
    test('the point lands past the text that landed', () {
      final text = 'Head. Tail';
      final p = planLanding(text, 5, 'middle', TypographyMode.none);
      expect(p.insert, ' middle');
      expect(p.point, 12);
    });
    test('a point past the end is clamped', () {
      final p = planLanding('abc', 99, 'd', TypographyMode.none);
      expect(p.insertAt, 3);
      expect(p.insert, ' d');
    });
  });
}
