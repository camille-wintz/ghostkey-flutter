import 'dart:async';

import 'package:flutter/widgets.dart';

import '../../server/errors.dart';
import '../../server/plan/api.dart';

/// How long after the last keystroke the outline goes to the server — the
/// desk's Outline page waits the same.
const Duration _debounce = Duration(milliseconds: 700);

enum OutlineSaveStatus { saved, dirty, saving, failed }

/// The one owner of "the outline's text reaches the server" while the Review
/// has it open: debounced on typing, flushed on dispose. The route is
/// last-write-wins with no version, so this never re-reads under the author.
class OutlineAutosave extends ChangeNotifier {
  OutlineAutosave({required this.projectId, required String initial}) : text = TextEditingController(text: initial) {
    _saved = initial;
    text.addListener(_onText);
  }

  final String projectId;
  final TextEditingController text;
  late String _saved;
  Timer? _timer;

  OutlineSaveStatus status = OutlineSaveStatus.saved;
  String? error;

  void _onText() {
    if (text.text == _saved) return;
    _set(OutlineSaveStatus.dirty);
    _timer?.cancel();
    _timer = Timer(_debounce, flush);
  }

  Future<void> flush() async {
    _timer?.cancel();
    final content = text.text;
    if (content == _saved) return;
    _set(OutlineSaveStatus.saving);
    try {
      await putAuthoredOutlineText(projectId, content);
      _saved = content;
      error = null;
      _set(text.text == content ? OutlineSaveStatus.saved : OutlineSaveStatus.dirty);
    } catch (e) {
      error = messageFor(e);
      _set(OutlineSaveStatus.failed);
    }
  }

  bool _disposed = false;

  void _set(OutlineSaveStatus next) {
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
