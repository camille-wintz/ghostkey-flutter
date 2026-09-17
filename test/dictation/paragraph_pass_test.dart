import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ghostkey/core/typography.dart';
import 'package:ghostkey/dictation/anchor.dart';
import 'package:ghostkey/dictation/paragraph_pass.dart';
import 'package:ghostkey/editor/editor_controller.dart';

class _Call {
  _Call(this.paragraph, this.finished);
  final String paragraph;
  final bool finished;
}

/// A dictation session in miniature: the anchor lands chunks, the pass
/// watches them, and the server is a function the test controls.
class _Rig {
  _Rig(String text, {String Function(String paragraph, bool finished)? answer})
      : editor = EditorController(typography: TypographyMode.none, text: text) {
    anchor = DictationAnchor(editor)..open();
    pass = ParagraphPass(editor, (paragraph, {required finished}) async {
      calls.add(_Call(paragraph, finished));
      return (answer ?? (p, _) => p)(paragraph, finished);
    });
  }

  final EditorController editor;
  late final DictationAnchor anchor;
  late final ParagraphPass pass;
  final List<_Call> calls = [];

  void land(String chunk) {
    pass.beforeLanding(anchor.landingPoint);
    final landed = anchor.insertDictation(chunk);
    if (landed != null) pass.afterLanding(landed.insert, landed.point);
  }

  Future<void> settle() async {
    pass.finish(anchor.landingPoint);
    await pass.idle;
  }
}

void main() {
  group('paragraphEndingAt', () {
    test('runs from the line start, trailing space excluded', () {
      final p = paragraphEndingAt('First.\n\nthe second one ', 24)!;
      expect(p.text, 'the second one');
      expect(p.from, 8);
      expect(p.to, 22);
    });
    test('an empty line is no paragraph', () {
      expect(paragraphEndingAt('First.\n\n', 8), isNull);
    });
  });

  group('narrowestChange', () {
    test('covers only what differs', () {
      final c = narrowestChange(10, 'it was late the rain', 'It was late. The rain');
      expect(c, (from: 10, to: 23, insert: 'It was late. T'));
    });
  });

  group('ParagraphPass', () {
    test('asks nothing under ten words, then a finished pass when it settles', () async {
      final rig = _Rig('', answer: (p, finished) => finished ? 'It was late.' : p);
      rig.land('it was late');
      await rig.pass.idle;
      expect(rig.calls, isEmpty);
      await rig.settle();
      expect(rig.calls.single.finished, isTrue);
      expect(rig.editor.text, 'It was late.');
    });

    test('every ten words asks an unfinished pass over the paragraph so far', () async {
      final rig = _Rig('');
      rig.land('one two three four five');
      rig.land('six seven eight nine ten');
      await rig.pass.idle;
      expect(rig.calls.single.finished, isFalse);
      expect(rig.calls.single.paragraph, 'one two three four five six seven eight nine ten');
    });

    test('a dictated break finishes the paragraph it closes', () async {
      final rig = _Rig('');
      rig.land('the rain came');
      rig.land('\n\nand then it stopped');
      await rig.pass.idle;
      expect(rig.calls.single.paragraph, 'the rain came');
      expect(rig.calls.single.finished, isTrue);
    });

    test('lands the next chunk after a mark the pass added at the point', () async {
      final rig = _Rig('', answer: (p, finished) => finished ? 'The rain came.' : p);
      rig.land('the rain came');
      await rig.settle();
      rig.land('it stopped');
      expect(rig.editor.text, 'The rain came. it stopped');
    });

    test('an answer about a paragraph the writer changed is not written', () async {
      final rig = _Rig('', answer: (p, _) => 'The rain came.');
      rig.land('the rain came');
      rig.pass.finish(rig.anchor.landingPoint);
      rig.editor.insertAt(0, 'x', moveCaret: false);
      await rig.pass.idle;
      expect(rig.editor.text, 'xthe rain came');
    });

    test('keeps a selection outside the change where it was', () async {
      final rig = _Rig('Before.\n', answer: (p, _) => 'The rain came.');
      rig.land('the rain came');
      rig.editor.textController.selection = const TextSelection.collapsed(offset: 3);
      await rig.settle();
      expect(rig.editor.text, 'Before.\nThe rain came.');
      expect(rig.editor.selection.baseOffset, 3);
    });
  });
}
