// A long series note, as the phone draws it: the text cut into pieces a lazy
// list can build one at a time. A note runs to millions of characters, so one
// Text of the whole body would lay out all of it before the first frame. Pure:
// pinned by test/media/note_pieces_test.dart.

/// One run of the body, `[start, end)`.
typedef NotePiece = ({int start, int end});

/// The longest piece; a longer run is cut again, at a line break where there
/// is one.
const int pieceMaxChars = 6000;

/// The body cut into pieces of at most [maxChars], at line breaks where it
/// can be. Offsets are UTF-16, as Dart's are.
List<NotePiece> cutNote(String body, {int maxChars = pieceMaxChars}) {
  final length = body.length;
  if (length == 0) return const [(start: 0, end: 0)];
  final pieces = <NotePiece>[];
  var start = 0;
  while (length - start > maxChars) {
    final cut = _cutPoint(body, start, start + maxChars);
    pieces.add((start: start, end: cut));
    start = cut;
  }
  pieces.add((start: start, end: length));
  return pieces;
}

/// Just past the last line break in `(start, limit]`, else [limit] — moved
/// back off a surrogate pair's second half, so no piece splits a character.
int _cutPoint(String body, int start, int limit) {
  final newline = body.lastIndexOf('\n', limit - 1);
  if (newline > start) return newline + 1;
  final unit = body.codeUnitAt(limit);
  return unit >= 0xDC00 && unit <= 0xDFFF && limit - 1 > start ? limit - 1 : limit;
}
