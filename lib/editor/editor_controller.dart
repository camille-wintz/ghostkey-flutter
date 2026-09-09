import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../core/typography.dart';

/// One change to the document: the text before and the text after. Consumers
/// that keep a position in the text (the dictation insertion point) map it
/// through these, in order.
class TextEdit {
  const TextEdit(this.prev, this.next);
  final String prev;
  final String next;
}

/// The page's text, owned once.
///
/// The [textController] is what the page's `TextField` is bound to; every
/// other party (dictation, scan, the format bar) goes through the methods
/// here and is reported on [edits] like a keystroke is. Smart typography runs
/// on every USER change through [inputFormatter] — the page's field must carry
/// it — so a `--` that became a dash is one edit of its final length.
/// Programmatic inserts land raw; a caller wanting the project's typography
/// applies `applyTypography` itself before calling [insertAt].
///
/// This notifier fires for [readOnly] changes only — never per keystroke —
/// so a widget listening to it can hold the field without rebuilding it on
/// every character. Text listeners belong on [textController] or [edits].
class EditorController extends ChangeNotifier {
  EditorController({required this.typography, String text = ''})
      : _textController = TextEditingController.fromValue(
          TextEditingValue(text: text, selection: TextSelection.collapsed(offset: text.length)),
        ),
        _lastText = text {
    _textController.addListener(_onValue);
    inputFormatter = _SmartTypographyFormatter(this);
  }

  /// The project's quote style. Settable: a project setting can change under
  /// an open page.
  TypographyMode typography;

  /// The formatter that runs smart typography on typed input. The page's
  /// `TextField` passes it in `inputFormatters`; programmatic changes never
  /// go through it.
  late final TextInputFormatter inputFormatter;

  final TextEditingController _textController;
  final StreamController<TextEdit> _edits = StreamController.broadcast(sync: true);
  String _lastText;
  bool _readOnly = false;
  bool _disposed = false;

  TextEditingController get textController => _textController;

  String get text => _textController.text;

  TextSelection get selection => _textController.selection;

  /// The caret, clamped to the text.
  int get caret => _textController.selection.extentOffset.clamp(0, text.length);

  /// Dictation sets this while its dock is open; the field honours it.
  bool get readOnly => _readOnly;
  set readOnly(bool value) {
    if (_readOnly == value) return;
    _readOnly = value;
    notifyListeners();
  }

  /// Every change to the text, after it is applied.
  Stream<TextEdit> get edits => _edits.stream;

  /// Replace the whole document — a load, a restore. NOT reported on [edits]:
  /// nothing that held a position in the old text can keep it.
  void setText(String text, {int? caret}) {
    _checkAlive();
    final offset = (caret ?? text.length).clamp(0, text.length);
    _lastText = text;
    _textController.value = TextEditingValue(text: text, selection: TextSelection.collapsed(offset: offset));
  }

  /// Insert at `offset`, raw. With `moveCaret` the caret lands after the
  /// insert; without, the selection keeps its place in the text around it.
  void insertAt(int offset, String insert, {bool moveCaret = true}) {
    _checkAlive();
    final current = text;
    final at = offset.clamp(0, current.length);
    final next = current.replaceRange(at, at, insert);
    final selection = moveCaret
        ? TextSelection.collapsed(offset: at + insert.length)
        : _shifted(_textController.selection, at, insert.length);
    _textController.value = TextEditingValue(text: next, selection: selection);
  }

  /// Replace `[start, end)` with `replacement`; the caret lands after it.
  void replaceRange(int start, int end, String replacement) {
    _checkAlive();
    final current = text;
    final from = start.clamp(0, current.length);
    final to = end.clamp(from, current.length);
    final next = current.replaceRange(from, to, replacement);
    _textController.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: from + replacement.length),
    );
  }

  void _onValue() {
    final next = _textController.text;
    if (identical(next, _lastText) || next == _lastText) return;
    final prev = _lastText;
    _lastText = next;
    _edits.add(TextEdit(prev, next));
  }

  void _checkAlive() {
    if (_disposed) throw StateError('EditorController used after dispose');
  }

  @override
  void dispose() {
    _disposed = true;
    _textController.removeListener(_onValue);
    _textController.dispose();
    unawaited(_edits.close());
    super.dispose();
  }
}

/// A selection with every position at or past `at` moved by `by`.
TextSelection _shifted(TextSelection selection, int at, int by) {
  if (!selection.isValid) return selection;
  int move(int p) => p < at ? p : p + by;
  return selection.copyWith(baseOffset: move(selection.baseOffset), extentOffset: move(selection.extentOffset));
}

/// Smart typography as Flutter means it to be done: the formatter sees the
/// value before and after a user edit and answers with the value to keep,
/// caret included — so a substitution places the caret itself, with no
/// second round trip to the IME. `applySmartEdit` is the same transform the
/// desktop, the server and the RN app run; it recovers the edit from the two
/// texts, which keeps the four copies answering one fixture table.
class _SmartTypographyFormatter extends TextInputFormatter {
  _SmartTypographyFormatter(this.controller);
  final EditorController controller;

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final edit = applySmartEdit(oldValue.text, newValue.text, controller.typography);
    if (edit == null) return newValue;
    // The composing region is dropped: a substitution has rewritten what the
    // IME was composing, and a stale range over new text is what Gboard
    // fights over.
    return TextEditingValue(text: edit.text, selection: TextSelection.collapsed(offset: edit.cursor));
  }
}
