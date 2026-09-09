import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ghostkey/core/typography.dart';
import 'package:ghostkey/editor/editor_controller.dart';

TextEditingValue _typed(String text, int caret) =>
    TextEditingValue(text: text, selection: TextSelection.collapsed(offset: caret));

void main() {
  group('EditorController', () {
    test('the formatter curls a typed quote and places the caret after it', () {
      final editor = EditorController(typography: TypographyMode.curly, text: 'He said ');
      final out = editor.inputFormatter.formatEditUpdate(_typed('He said ', 8), _typed('He said "', 9));
      expect(out.text, 'He said “');
      expect(out.selection.extentOffset, 9);
      expect(out.composing, TextRange.empty);
      editor.dispose();
    });

    test('a second dash collapses into an em dash, one edit of the final length', () {
      final editor = EditorController(typography: TypographyMode.curly, text: 'a-');
      final edits = <TextEdit>[];
      editor.edits.listen(edits.add);
      final out = editor.inputFormatter.formatEditUpdate(_typed('a-', 2), _typed('a--', 3));
      expect(out.text, 'a—');
      expect(out.selection.extentOffset, 2);
      // What the field then sets is reported once, as prev→next.
      editor.textController.value = out;
      expect(edits.length, 1);
      expect(edits.single.prev, 'a-');
      expect(edits.single.next, 'a—');
      editor.dispose();
    });

    test('mode none leaves typed input alone', () {
      final editor = EditorController(typography: TypographyMode.none);
      final next = _typed('"', 1);
      expect(identical(editor.inputFormatter.formatEditUpdate(_typed('', 0), next), next), isTrue);
      editor.dispose();
    });

    test('typography is settable under an open page', () {
      final editor = EditorController(typography: TypographyMode.curly);
      editor.typography = TypographyMode.guillemets;
      final out = editor.inputFormatter.formatEditUpdate(_typed('', 0), _typed('"', 1));
      expect(out.text, '« ');
      editor.dispose();
    });

    test('setText is not reported; inserts and replacements are, in order', () {
      final editor = EditorController(typography: TypographyMode.curly);
      final edits = <TextEdit>[];
      editor.edits.listen(edits.add);
      editor.setText('abc');
      expect(edits, isEmpty);
      expect(editor.caret, 3);
      editor.insertAt(1, 'X');
      editor.replaceRange(0, 1, 'Y');
      expect(edits.map((e) => e.next).toList(), ['aXbc', 'YXbc']);
      expect(edits.first.prev, 'abc');
      expect(editor.caret, 1);
      editor.dispose();
    });

    test('insertAt with moveCaret false keeps the caret on its text', () {
      final editor = EditorController(typography: TypographyMode.curly, text: 'hello world');
      editor.textController.selection = const TextSelection.collapsed(offset: 11);
      editor.insertAt(5, ',', moveCaret: false);
      expect(editor.text, 'hello, world');
      expect(editor.caret, 12);
      editor.textController.selection = const TextSelection.collapsed(offset: 2);
      editor.insertAt(5, '!', moveCaret: false);
      expect(editor.caret, 2);
      editor.dispose();
    });

    test('readOnly notifies; text does not', () {
      final editor = EditorController(typography: TypographyMode.curly);
      var notified = 0;
      editor.addListener(() => notified++);
      editor.insertAt(0, 'typed');
      expect(notified, 0);
      editor.readOnly = true;
      expect(notified, 1);
      expect(editor.readOnly, isTrue);
      editor.dispose();
    });

    test('caret is clamped to the text', () {
      final editor = EditorController(typography: TypographyMode.curly, text: 'abc');
      editor.setText('a', caret: 10);
      expect(editor.caret, 1);
      editor.dispose();
    });
  });
}
