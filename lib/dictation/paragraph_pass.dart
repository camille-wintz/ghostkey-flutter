import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/typography.dart';
import '../editor/editor_controller.dart';
import 'policy.dart';

// The paragraph pass over dictated text. Ported from ghost-key
// `src/apparition/components/editor/useParagraphPass.ts`.
//
// Each chunk is cleaned on its own, cut where the writer paused for breath —
// not where their sentences end — so the seams come out wrong in ways no chunk
// can see: a sentence left without its full stop, a new sentence left
// lowercase. The server's paragraph pass (POST /api/transcribe/paragraph)
// reads the paragraph those chunks built and repairs its marks, capitals and
// any word that makes no sense where it stands. This class decides WHEN to
// ask and lands the answer:
//
//   - every `wordsPerParagraphPass` dictated words, over the paragraph so far
//     — its last sentence is still being spoken, so the server leaves its
//     ending alone;
//   - once the paragraph ends — a break the writer dictated, a break they
//     typed at the landing point, or the recording settling — with
//     `finished`, which lets it close the last sentence.
//
// The answer is written back only while the manuscript still holds exactly
// the paragraph that was sent. The writer may have typed into it meanwhile,
// and their words win: that paragraph just keeps its seams.

/// Asks the server for one paragraph. Injected so tests need no network.
typedef CleanParagraph = Future<String> Function(String paragraph, {required bool finished});

final RegExp _word = RegExp(r'[\p{L}\p{N}]+', unicode: true);
final RegExp _trailingSpace = RegExp(r'\s+$');
final RegExp _trailingInlineSpace = RegExp(r'[^\S\n]+$');
final RegExp _opensOnMark = RegExp(r'^[.!?]');
final RegExp _endsOnMark = RegExp(r'[.!?]$');

int countDictatedWords(String text) => _word.allMatches(text).length;

/// The paragraph ending at `to`: from the line start, trailing space excluded.
/// Null when it holds no words.
({int from, int to, String text})? paragraphEndingAt(String doc, int to) {
  final end = to.clamp(0, doc.length);
  final from = doc.lastIndexOf('\n', end - 1) + 1;
  final text = doc.substring(from, end).replaceFirst(_trailingSpace, '');
  if (countDictatedWords(text) == 0) return null;
  return (from: from, to: from + text.length, text: text);
}

/// One change covering only what differs, so a caret or selection elsewhere in
/// the paragraph stays where the writer left it.
({int from, int to, String insert}) narrowestChange(int from, String before, String after) {
  var start = 0;
  while (start < before.length && start < after.length && before.codeUnitAt(start) == after.codeUnitAt(start)) {
    start++;
  }
  var end = 0;
  while (end < before.length - start &&
      end < after.length - start &&
      before.codeUnitAt(before.length - 1 - end) == after.codeUnitAt(after.length - 1 - end)) {
    end++;
  }
  return (from: from + start, to: from + before.length - end, insert: after.substring(start, after.length - end));
}

class _PassRequest {
  const _PassRequest(this.from, this.to, this.text, this.finished);
  final int from;
  final int to;
  final String text;
  final bool finished;
}

class ParagraphPass {
  ParagraphPass(this.editor, this.clean);

  final EditorController editor;
  final CleanParagraph clean;

  // Dictated words in the current paragraph since the last pass over it, and
  // whether anything was dictated into it since its last FINISHED pass — a
  // mid-paragraph pass does not settle the last sentence, so stopping right
  // after one still owes the finished pass.
  int _wordsSince = 0;
  bool _open = false;

  // One pass at a time: a paragraph read while an answer about it is in
  // flight would be refused on landing anyway. What queues behind it is
  // re-checked against the manuscript when its turn comes.
  final List<_PassRequest> _queue = [];
  bool _busy = false;
  Future<void> _idle = Future<void>.value();
  bool _disposed = false;

  /// Resolves once every pass asked for so far has answered or been dropped.
  Future<void> get idle => _idle;

  /// Dictated text is about to land at `at`: a paragraph the writer ended
  /// with a break since the last landing is finished now.
  void beforeLanding(int at) {
    if (!_open) return;
    final text = editor.text;
    final head = text.substring(0, at.clamp(0, text.length)).replaceFirst(_trailingInlineSpace, '');
    if (!head.endsWith('\n')) return;
    _request(head.replaceFirst(_trailingSpace, '').length, finished: true);
  }

  /// Dictated text just landed: `inserted` exactly as written, ending at `end`.
  void afterLanding(String inserted, int end) {
    final lastBreak = inserted.lastIndexOf('\n');
    if (lastBreak != -1) {
      // The text before its first break completes the paragraph it landed
      // in; the paragraphs wholly inside the chunk were cleaned whole by the
      // chunk pass, so only what follows the last break is still open.
      final firstBreak = inserted.indexOf('\n');
      if (_open || countDictatedWords(inserted.substring(0, firstBreak)) > 0) {
        _request(end - inserted.length + firstBreak, finished: true);
      }
      _wordsSince = countDictatedWords(inserted.substring(lastBreak + 1));
      _open = _wordsSince > 0;
    } else {
      _wordsSince += countDictatedWords(inserted);
      _open = _open || _wordsSince > 0;
    }
    if (_wordsSince >= DictationPolicy.wordsPerParagraphPass) _request(end, finished: false);
  }

  /// The recording settled — stopped or paused, everything it sent landed:
  /// the paragraph being dictated is finished.
  void finish(int end) {
    if (_open) _request(end, finished: true);
  }

  void dispose() {
    _disposed = true;
    _queue.clear();
  }

  void _request(int to, {required bool finished}) {
    final paragraph = paragraphEndingAt(editor.text, to);
    _wordsSince = 0;
    if (finished) _open = false;
    if (paragraph == null || _disposed) return;
    _queue.add(_PassRequest(paragraph.from, paragraph.to, paragraph.text, finished));
    if (!_busy) _idle = _drain();
  }

  Future<void> _drain() async {
    _busy = true;
    try {
      while (_queue.isNotEmpty && !_disposed) {
        final next = _queue.removeAt(0);
        // A newer request over the same paragraph supersedes an unfinished one.
        if (!next.finished && _queue.any((r) => r.from == next.from)) continue;
        if (!_holds(next)) continue;
        try {
          final answer = await clean(next.text, finished: next.finished);
          if (!_disposed) _land(next, answer);
        } catch (e) {
          // Best-effort: the paragraph keeps the seams the chunks gave it.
          debugPrint('[dictation] paragraph pass failed — paragraph left as dictated: $e');
        }
      }
    } finally {
      _busy = false;
    }
  }

  bool _holds(_PassRequest r) {
    final text = editor.text;
    return r.to <= text.length && text.substring(r.from, r.to) == r.text;
  }

  void _land(_PassRequest sent, String answer) {
    if (!_holds(sent)) return;
    final text = editor.text;
    var revised = applyTypography(answer, text.substring(0, sent.from), editor.typography);
    // A chunk that landed meanwhile may already have put the closing mark
    // right after this paragraph's last word (see dictation_join.dart); the
    // pass must not add a second.
    final after = text.substring(sent.to, (sent.to + 1).clamp(0, text.length));
    if (_opensOnMark.hasMatch(after) && !_endsOnMark.hasMatch(sent.text)) {
      revised = revised.replaceFirst(_endsOnMark, '');
    }
    if (revised == sent.text) return;
    final change = narrowestChange(sent.from, sent.text, revised);
    editor.replaceRange(change.from, change.to, change.insert, moveCaret: false);
  }
}
