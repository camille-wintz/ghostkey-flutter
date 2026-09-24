import 'dart:async';

import 'package:flutter/widgets.dart';

import '../server/errors.dart';

/// How long after the last keystroke a field goes to the server — the desk's
/// plan pages wait the same.
const Duration fieldSaveDebounce = Duration(milliseconds: 700);

enum FieldSaveStatus { saved, dirty, saving, failed }

/// The one owner of "a typed field reaches the server" for text that is not a
/// manuscript document: debounced on typing, flushed on demand and on
/// dispose. Knows nothing of what it saves — [save] does. The field is never
/// re-read under the author's typing; [reset] is the one way the server's text
/// replaces theirs, for a caller that knows it should.
class FieldAutosave extends ChangeNotifier {
  FieldAutosave({required String initial, required this.save, this.debounce = fieldSaveDebounce})
      : text = TextEditingController(text: initial) {
    _saved = initial;
    text.addListener(_onText);
  }

  final TextEditingController text;

  /// Writes the field's text. Throwing leaves the field dirty and says why.
  final Future<void> Function(String text) save;
  final Duration debounce;

  late String _saved;
  Timer? _timer;
  Future<void>? _inFlight;
  bool _disposed = false;

  FieldSaveStatus status = FieldSaveStatus.saved;
  String? error;

  void _onText() {
    if (text.text == _saved) return;
    _set(FieldSaveStatus.dirty);
    _timer?.cancel();
    _timer = Timer(debounce, flush);
  }

  /// Send what is typed now, if it differs from what was last saved. Resolves
  /// once it has landed (or failed).
  Future<void> flush() async {
    _timer?.cancel();
    await _inFlight;
    final content = text.text;
    if (content == _saved) return;
    _set(FieldSaveStatus.saving);
    final write = _write(content);
    _inFlight = write;
    await write;
    if (identical(_inFlight, write)) _inFlight = null;
  }

  Future<void> _write(String content) async {
    try {
      await save(content);
      _saved = content;
      error = null;
      _set(text.text == content ? FieldSaveStatus.saved : FieldSaveStatus.dirty);
    } catch (e) {
      error = messageFor(e);
      _set(FieldSaveStatus.failed);
    }
  }

  /// Take [value] as the field's text AND as what the server holds — a run
  /// wrote it there. Drops any pending keystroke.
  void reset(String value) {
    _timer?.cancel();
    _saved = value;
    text.text = value;
    error = null;
    _set(FieldSaveStatus.saved);
  }

  void _set(FieldSaveStatus next) {
    status = next;
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    text.removeListener(_onText);
    // The last keystrokes still go; the controller outlives the page until
    // they have.
    unawaited(flush().whenComplete(text.dispose));
    super.dispose();
  }
}
