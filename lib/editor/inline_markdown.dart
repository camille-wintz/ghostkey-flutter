// Inline markdown emphasis on a selection — the B and I buttons. Mirrored
// from the RN app's `src/lib/markdown.ts`; pure, so `test/editor/` pins it.

/// `**` for bold, `*` for italic.
enum InlineMarker {
  bold('**'),
  italic('*');

  const InlineMarker(this.text);
  final String text;
  int get length => text.length;
}

/// A half-open range of the text, in code units.
typedef InlineRange = ({int start, int end});

/// The text after a toggle, and where the selection lands in it.
class InlineToggle {
  const InlineToggle(this.text, this.start, this.end);
  final String text;
  final int start;
  final int end;
}

final RegExp _space = RegExp(r'\s');

/// Length of the contiguous `*` run touching `from` (backward when `dir` is -1).
int _starRun(String text, int from, int dir) {
  var n = 0;
  var i = dir == -1 ? from - 1 : from;
  while (i >= 0 && i < text.length && text[i] == '*') {
    n++;
    i += dir;
  }
  return n;
}

// A run of `*` reads as bold when it is 2+ long, and as italic when it
// contributes an odd asterisk (1, or 3 for bold+italic). This keeps a lone
// half of a `**` from being mistaken for an italic marker.
bool _runMatches(int run, InlineMarker marker) =>
    marker == InlineMarker.bold ? run >= 2 : run == 1 || run >= 3;

InlineRange _clamp(String text, InlineRange sel) {
  final start = sel.start.clamp(0, text.length);
  final end = sel.end.clamp(start, text.length);
  return (start: start, end: end);
}

/// Shrink the selection so markers hug the text — `** text**` doesn't render.
InlineRange _trimEdges(String text, InlineRange sel) {
  var start = sel.start;
  var end = sel.end;
  while (start < end && _space.hasMatch(text[start])) {
    start++;
  }
  while (end > start && _space.hasMatch(text[end - 1])) {
    end--;
  }
  return (start: start, end: end);
}

({bool inside, bool outside}) _wrapState(String text, int start, int end, InlineMarker marker) {
  final len = marker.length;
  final inner = text.substring(start, end);
  final inside = inner.length >= 2 * len &&
      _runMatches(_starRun(inner, 0, 1), marker) &&
      _runMatches(_starRun(inner, inner.length, -1), marker);
  final outside = _runMatches(_starRun(text, start, -1), marker) && _runMatches(_starRun(text, end, 1), marker);
  return (inside: inside, outside: outside);
}

/// True when the selection (or a collapsed caret) sits in text formatted with
/// `marker`. For a caret this counts marker runs from the start of the line —
/// an unclosed run means the caret is inside the span.
bool isWrapped(String text, InlineRange sel, InlineMarker marker) {
  final clamped = _trimEdges(text, _clamp(text, sel));
  final start = clamped.start;
  final end = clamped.end;
  if (start != end) {
    final state = _wrapState(text, start, end, marker);
    return state.inside || state.outside;
  }
  final lineStart = text.lastIndexOf('\n', start - 1) + 1;
  var bold = false;
  var italic = false;
  var i = lineStart;
  while (i < start) {
    if (text[i] != '*') {
      i++;
      continue;
    }
    var run = 0;
    while (i < start && text[i] == '*') {
      run++;
      i++;
    }
    if (run >= 2) bold = !bold;
    if (run.isOdd) italic = !italic;
  }
  return marker == InlineMarker.bold ? bold : italic;
}

/// Toggle `marker` around the selection. Wraps an unformatted selection,
/// unwraps a formatted one (markers inside or just outside the selection).
/// A collapsed caret gets an empty pair to type into; pressing again on the
/// empty pair removes it, and a caret right before a closing marker steps
/// over it instead of nesting a new pair.
InlineToggle toggleInline(String text, InlineRange sel, InlineMarker marker) {
  final len = marker.length;
  final trimmed = _trimEdges(text, _clamp(text, sel));
  final start = trimmed.start;
  final end = trimmed.end;

  if (start == end) return _toggleAtCaret(text, start, marker);

  final inner = text.substring(start, end);
  final state = _wrapState(text, start, end, marker);
  if (state.inside) {
    final next = text.substring(0, start) + inner.substring(len, inner.length - len) + text.substring(end);
    return InlineToggle(next, start, end - 2 * len);
  }
  if (state.outside) {
    final next = text.substring(0, start - len) + inner + text.substring(end + len);
    return InlineToggle(next, start - len, end - len);
  }
  final next = text.substring(0, start) + marker.text + inner + marker.text + text.substring(end);
  return InlineToggle(next, start + len, end + len);
}

InlineToggle _toggleAtCaret(String text, int pos, InlineMarker marker) {
  final len = marker.length;
  final runBefore = _starRun(text, pos, -1);
  final runAfter = _starRun(text, pos, 1);

  // `**|**` — an empty pair the user backed out of: remove it.
  if (_runMatches(runBefore, marker) && _runMatches(runAfter, marker)) {
    final next = text.substring(0, pos - len) + text.substring(pos + len);
    return InlineToggle(next, pos - len, pos - len);
  }

  // `**word|**` — pressing the button again exits the span instead of nesting.
  if (_runMatches(runAfter, marker) && isWrapped(text, (start: pos, end: pos), marker)) {
    return InlineToggle(text, pos + len, pos + len);
  }

  final next = text.substring(0, pos) + marker.text + marker.text + text.substring(pos);
  return InlineToggle(next, pos + len, pos + len);
}
