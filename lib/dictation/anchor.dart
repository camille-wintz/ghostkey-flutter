import 'dart:async';
import 'dart:math';

import '../core/dictation_join.dart';
import '../core/typography.dart';
import '../editor/editor_controller.dart';

// Where dictated text lands. Ported from ghostkey-mobile
// `src/components/editor/useDictationAnchor.ts` and the landing rule in
// `ChapterScreen.tsx`.
//
// Dictation does not write at the caret. A chunk's transcript comes back
// seconds after the words were spoken, and whatever had moved the caret in
// between relocated the sentence there (beta report, 2026-09-04: a sentence
// landed mid-paragraph six lines above the end). So the session owns an
// insertion point: taken from the caret when the dock opens, advanced by each
// chunk that lands, mapped through every other edit so text inserted or
// removed above it never shifts where the next chunk goes. It outlives the
// dock on purpose — the chunks still in flight when the writer taps Done land
// where the dictation was.

/// Where `anchor` ends up once the document changes from `prev` to `next`.
/// The edit is recovered as the one contiguous range the two texts differ in
/// — which is what a keystroke, a paste, or a smart-typography substitution
/// each are. Text changed before the point shifts it by the size difference;
/// a point inside the replaced range lands just after the replacement; an
/// insertion exactly at the point moves it past the inserted text (a landing
/// chunk is exactly that, and the next one belongs after it). Same semantics
/// as CodeMirror's mapPos(pos, 1), which the desktop client uses for this.
int mapAnchor(String prev, String next, int anchor) {
  if (prev == next) return anchor;
  final max = min(prev.length, next.length);
  var prefix = 0;
  while (prefix < max && prev.codeUnitAt(prefix) == next.codeUnitAt(prefix)) {
    prefix++;
  }
  var suffix = 0;
  final maxSuffix = max - prefix;
  while (suffix < maxSuffix &&
      prev.codeUnitAt(prev.length - 1 - suffix) == next.codeUnitAt(next.length - 1 - suffix)) {
    suffix++;
  }
  final removedEnd = prev.length - suffix;
  final inserted = next.length - suffix - prefix;
  if (anchor < prefix) return anchor;
  if (anchor >= removedEnd) return anchor + inserted - (removedEnd - prefix);
  return prefix + inserted;
}

/// How one chunk joins the text at the insertion point — the pure half of
/// the landing, so it can be tested without an editor.
///
/// The chunk may open with the mark that closes the sentence the chunk
/// before it was cut in the middle of. It belongs on that last word, so it
/// goes in ahead of the whitespace joining the two, not with the words
/// landing now. A leading space keeps streamed chunks from running together,
/// except where the chunk opens on a paragraph break (a dictated "new line")
/// — that break is the separation, and the space would hang off the previous
/// paragraph. The text is straight-quoted (the server returns the transcript
/// verbatim), so it gets the same typography pass typing gets, with quote
/// parity read from the whole document before the insertion point.
class LandingPlan {
  const LandingPlan({
    required this.markAt,
    required this.mark,
    required this.insertAt,
    required this.insert,
    required this.point,
  });

  /// The end of the last word before the point — where [mark] goes.
  final int markAt;
  final String mark;

  /// Where the chunk proper goes, in the text AFTER the mark is in.
  final int insertAt;
  final String insert;

  /// The insertion point once both are in: the end of what landed.
  final int point;

  bool get isEmpty => mark.isEmpty && insert.isEmpty;
}

final RegExp _trailingSpace = RegExp(r'\s+$');
final RegExp _endsInSpace = RegExp(r'\s$');

LandingPlan planLanding(String text, int at, String chunk, TypographyMode typography) {
  final clamped = min(at, text.length);
  final head = text.substring(0, clamped).replaceFirst(_trailingSpace, '');
  final gap = text.substring(head.length, clamped);
  final split = splitClosingMark(head, chunk);
  final before = head + split.mark + gap;
  final leading =
      before.isNotEmpty && !_endsInSpace.hasMatch(before) && !split.body.startsWith('\n') ? ' ' : '';
  final insert = leading + applyTypography(split.body, before + leading, typography);
  return LandingPlan(
    markAt: head.length,
    mark: split.mark,
    insertAt: clamped + split.mark.length,
    insert: insert,
    point: before.length + insert.length,
  );
}

/// The session's insertion point over an [EditorController].
class DictationAnchor {
  DictationAnchor(this.editor) {
    _edits = editor.edits.listen(_onEdit);
  }

  final EditorController editor;
  late final StreamSubscription<TextEdit> _edits;
  int? _anchor;

  // The landings this class makes come back through `editor.edits` like any
  // other change. They must not be mapped — the anchor is set from the plan
  // — so each one is recognised and dropped: by the flag while a synchronous
  // stream reports during the call, by the queue when the report arrives
  // later. Anything else is the writer's, and moves the point.
  bool _applying = false;
  final List<({String prev, String next})> _own = [];

  /// Where the next chunk lands, or null with no session on record.
  int? get anchor => _anchor;

  /// The dock is opening: take the insertion point from the caret.
  void open() => _anchor = min(editor.caret, editor.text.length);

  /// Forget the session (the chapter changed under it).
  void reset() => _anchor = null;

  /// Sitting on the point means an empty caret exactly there. With no session
  /// on record every chunk falls back to the caret, so the caret is the point.
  bool get isCaretOnPoint {
    final at = _anchor;
    if (at == null) return true;
    final sel = editor.selection;
    return sel.isCollapsed && sel.baseOffset == at;
  }

  /// The manuscript before the insertion point, for the cleanup pass that
  /// needs to know what a chunk is continuing. Read at call time.
  String textBeforeDictation() {
    final text = editor.text;
    final at = min(_anchor ?? editor.caret, text.length);
    return text.substring(0, at);
  }

  /// Land a chunk at the session's own insertion point, never the caret.
  /// Falls back to the caret only if a chunk arrives with no session on
  /// record, and never replaces a selection: a range the writer dragged out
  /// is theirs, not a target. The caret follows the words only when it was
  /// riding the point — a writer who has gone back into an earlier line keeps
  /// their place.
  void insertDictation(String chunk) {
    final text = editor.text;
    final at = min(_anchor ?? editor.caret, text.length);
    final plan = planLanding(text, at, chunk, editor.typography);
    if (plan.isEmpty) return;
    final onPoint = isCaretOnPoint;
    if (plan.mark.isNotEmpty) _apply(() => editor.insertAt(plan.markAt, plan.mark, moveCaret: false));
    if (plan.insert.isNotEmpty) _apply(() => editor.insertAt(plan.insertAt, plan.insert, moveCaret: onPoint));
    _anchor = plan.point;
  }

  void _apply(void Function() edit) {
    final prev = editor.text;
    _applying = true;
    try {
      edit();
    } finally {
      _applying = false;
    }
    _own.add((prev: prev, next: editor.text));
    // A stream that never reports would let the queue grow for the session;
    // nothing in it matters past the next few edits.
    if (_own.length > 8) _own.removeAt(0);
  }

  void _onEdit(TextEdit e) {
    if (_applying) return;
    final i = _own.indexWhere((o) => o.prev == e.prev && o.next == e.next);
    if (i >= 0) {
      _own.removeRange(0, i + 1);
      return;
    }
    final at = _anchor;
    if (at == null) return;
    _anchor = mapAnchor(e.prev, e.next, at);
  }

  void dispose() {
    unawaited(_edits.cancel());
  }
}
