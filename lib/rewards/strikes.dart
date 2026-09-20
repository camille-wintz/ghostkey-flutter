import 'dart:async';

import 'package:flutter/foundation.dart';

import 'strike.dart';

/// How long a mark holds before it goes. Over the page, so long enough to
/// land and not long enough to be in the way.
const Duration _markDwell = Duration(seconds: 6);

/// A cat holds longer: it is new, and it has a name.
const Duration _catDwell = Duration(seconds: 9);

/// The strike on screen: which one, and whether it is on its way out.
class ShownStrike {
  const ShownStrike({required this.id, required this.strike, required this.leaving});
  final int id;
  final Strike strike;
  final bool leaving;

  ShownStrike get left => ShownStrike(id: id, strike: strike, leaving: true);
}

/// One card at a time. A claim can award more than one thing — a word mark
/// and the day's goal in the same save — and they are struck one after the
/// other rather than stacked: each is a moment, not a list. The host draws
/// [current] and reports [gone] when the card's exit has played.
class RewardStrikes extends ChangeNotifier {
  final List<Strike> _queue = [];
  ShownStrike? _current;
  Timer? _dwell;
  int _nextId = 1;

  ShownStrike? get current => _current;

  void show(Strike strike) {
    _queue.add(strike);
    if (_current == null) _advance();
  }

  /// Send the current card on its way; the next follows once it has gone.
  void dismiss() {
    _dwell?.cancel();
    _dwell = null;
    final shown = _current;
    if (shown == null || shown.leaving) return;
    _current = shown.left;
    notifyListeners();
  }

  /// The card with this id has finished leaving.
  void gone(int id) {
    if (_current?.id != id) return;
    _advance();
  }

  void _advance() {
    _dwell?.cancel();
    _dwell = null;
    if (_queue.isEmpty) {
      _current = null;
      notifyListeners();
      return;
    }
    final strike = _queue.removeAt(0);
    _current = ShownStrike(id: _nextId++, strike: strike, leaving: false);
    notifyListeners();
    _dwell = Timer(strike.cat != null ? _catDwell : _markDwell, dismiss);
  }

  @override
  void dispose() {
    _dwell?.cancel();
    _dwell = null;
    super.dispose();
  }
}
