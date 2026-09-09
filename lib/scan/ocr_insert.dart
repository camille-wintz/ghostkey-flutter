import 'package:flutter/services.dart';

import '../core/typography.dart';

// Where a one-shot capture lands in the chapter — the RN `insertAtCursor` in
// `ChapterScreen.tsx`, and the desktop's `insertAtCursor` before it.
//
// The text goes in at the writer's caret, replacing a selection if there is
// one. A leading space keeps it from running into the word before it, except
// where it opens on a paragraph break or the document already ends in
// whitespace. The chunk then goes through the project's typography with the
// document before it as context, so a quotation opened on the page closes as
// one and the French spacing rule sees what it attaches to.

/// One planned edit: replace `[start, end)` with `text`.
class OcrInsert {
  const OcrInsert({required this.start, required this.end, required this.text});
  final int start;
  final int end;
  final String text;

  bool get isCollapsed => start == end;
  int get caret => start + text.length;
}

final RegExp _endsInWhitespace = RegExp(r'\s$');

OcrInsert planOcrInsert({
  required String document,
  required TextSelection selection,
  required String chunk,
  required TypographyMode mode,
}) {
  final length = document.length;
  // An invalid selection (the field never focused) lands at the end, the way
  // the RN app's unset selection ref did.
  int clamp(int v) => v < 0 ? length : (v > length ? length : v);
  final start = selection.isValid ? clamp(selection.start) : length;
  final end = selection.isValid ? clamp(selection.end) : length;

  final before = document.substring(0, start);
  final leading = before.isNotEmpty && !_endsInWhitespace.hasMatch(before) && !chunk.startsWith('\n') ? ' ' : '';
  return OcrInsert(
    start: start,
    end: end,
    text: leading + applyTypography(chunk, before + leading, mode),
  );
}
