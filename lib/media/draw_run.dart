import 'package:flutter/widgets.dart';

import '../server/media/api.dart';
import 'library.dart';

// A draw, as state the picker holds rather than state its Draw tab holds.
// That is the whole reason it is its own object: a draw takes minutes, and
// the author must be free to go to the library tab, look through the shelf
// and come back without the run — or the words they wrote — going with the
// tab. The desk's `useImageDraw`, less the gates, which are `drawPicture`'s.

class DrawRun extends ChangeNotifier {
  DrawRun({String prompt = '', this.size = DrawSize.square}) : prompt = TextEditingController(text: prompt.trim()) {
    this.prompt.addListener(notifyListeners);
  }

  /// The author's words. A caller's prompt only seeds it; they can rewrite
  /// every word before spending a draw. Kept after a draw, so Draw again
  /// asks for another of the same.
  final TextEditingController prompt;
  DrawSize size;

  bool _disposed = false;
  bool _busy = false;
  bool get busy => _busy;

  String? _error;
  String? get error => _error;

  /// Pictures this run has drawn, so the button can say Draw again.
  int _drawn = 0;
  bool get hasDrawn => _drawn > 0;

  bool get canStart => !_busy && prompt.text.trim().isNotEmpty;

  void setSize(DrawSize next) {
    if (next == size) return;
    size = next;
    notifyListeners();
  }

  /// Run one draw through [draw] and answer how it ended; null when there
  /// was nothing to draw or one is already running. A failure is kept as
  /// [error], said over the prompt until the next try.
  Future<DrawOutcome?> start(Future<DrawOutcome> Function(String prompt, DrawSize size) draw) async {
    if (!canStart) return null;
    _busy = true;
    _error = null;
    notifyListeners();
    try {
      final outcome = await draw(prompt.text.trim(), size);
      switch (outcome) {
        case DrawDone():
          _drawn++;
        case DrawFailed(:final message):
          _error = message;
        case DrawLocked() || DrawSpent():
          break;
      }
      return outcome;
    } finally {
      _busy = false;
      // The picker may have closed while the server drew; the picture is in
      // the library all the same.
      if (!_disposed) notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    prompt.dispose();
    super.dispose();
  }
}
