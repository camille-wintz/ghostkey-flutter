import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ghostkey/core/typography.dart';
import 'package:ghostkey/scan/ocr_insert.dart';

void main() {
  OcrInsert plan(String document, int start, int end, String chunk, [TypographyMode mode = TypographyMode.none]) =>
      planOcrInsert(
        document: document,
        selection: TextSelection(baseOffset: start, extentOffset: end),
        chunk: chunk,
        mode: mode,
      );

  group('planOcrInsert', () {
    test('lands at a collapsed caret with a joining space', () {
      final p = plan('The rain fell.', 14, 14, 'It kept falling.');
      expect(p.start, 14);
      expect(p.end, 14);
      expect(p.text, ' It kept falling.');
      expect(p.caret, 14 + ' It kept falling.'.length);
    });

    test('no space at the start of the document', () {
      expect(plan('', 0, 0, 'First words.').text, 'First words.');
    });

    test('no space after whitespace', () {
      expect(plan('The rain ', 9, 9, 'fell.').text, 'fell.');
      expect(plan('The rain\n', 9, 9, 'fell.').text, 'fell.');
    });

    test('no space when the chunk opens on a paragraph break', () {
      expect(plan('The rain fell.', 14, 14, '\nA new scene.').text, '\nA new scene.');
    });

    test('replaces a selection', () {
      final p = plan('Keep this. DROP THIS. And this.', 11, 21, 'Not that.');
      expect(p.start, 11);
      expect(p.end, 21);
      expect(p.isCollapsed, isFalse);
      // The text before ends in a space, so nothing is prepended.
      expect(p.text, 'Not that.');
    });

    test('an invalid selection lands at the end', () {
      final p = planOcrInsert(
        document: 'Some text',
        selection: const TextSelection.collapsed(offset: -1),
        chunk: 'more',
        mode: TypographyMode.none,
      );
      expect(p.start, 9);
      expect(p.text, ' more');
    });

    test('a selection past the end is clamped', () {
      final p = plan('Short', 40, 60, 'tail');
      expect(p.start, 5);
      expect(p.end, 5);
    });

    test('runs the chunk through the project typography with the document as context', () {
      // A quotation opened in the document before the caret closes as one.
      final p = plan('She said, "wait', 15, 15, 'for me," and left.', TypographyMode.curly);
      expect(p.text, ' for me,” and left.');
    });

    test('the joining space is context for French spacing', () {
      final p = plan('Il dit', 6, 6, '« Bonjour ! »', TypographyMode.guillemets);
      expect(p.text, ' « Bonjour ! »');
    });

    test('mode none leaves the chunk as scanned', () {
      expect(plan('x', 1, 1, '"raw" -- text...').text, ' "raw" -- text...');
    });
  });
}
