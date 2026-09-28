import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../server/errors.dart';
import 'render_id_card.dart';

enum TaglineState { writing, ready, failed }

/// The server's cap on a line, and the card is sized for it.
const int taglineMax = 120;

typedef TaglineAsk = Future<String> Function(List<String> avoid);
typedef PortraitLoad = Future<Uint8List?> Function();
typedef CardDraw = Future<Uint8List> Function(IdCardFace face, Uint8List? portrait);

/// One card of the world bible as a shareable identity card: asks for a
/// tagline, fetches the portrait's bytes, and draws. Everything the file
/// takes is done here, ahead of the tap, so Share goes straight to the sheet.
/// The desk's `useIdCard.ts`.
///
/// Nothing happens until [start] — a card no one opened asks for nothing.
/// The page that owns it keeps it for its own life, so closing the sheet and
/// opening it again shows the same card, not a new line. Every line shown is
/// remembered, so [another] never comes back with one already seen.
class IdCard extends ChangeNotifier {
  IdCard({
    required this._name,
    required this._ask,
    required PortraitLoad portrait,
    this._draw = renderIdCard,
    this._redrawDelay = const Duration(milliseconds: 150),
  }) : _loadPortrait = portrait;

  final TaglineAsk _ask;
  final PortraitLoad _loadPortrait;
  final CardDraw _draw;
  final Duration _redrawDelay;

  String _name;
  String get name => _name;

  /// The line on the card — the model's, or the author's own once edited.
  String get line => _line;
  String _line = '';

  TaglineState get tagline => _tagline;
  TaglineState _tagline = TaglineState.writing;

  /// What went wrong with the tagline, in words, when [tagline] is failed.
  String? get error => _error;
  String? _error;

  /// The card as last drawn — without a line first, then again when one
  /// lands, so there is always something to look at. Null until then.
  Uint8List? get png => _png;
  Uint8List? _png;
  String? _drawnKey;

  /// Whether [png] says what the card says now — false for the beat between
  /// a keystroke and the redraw, so a tap never sends the old line.
  bool get current => _png != null && _drawnKey == _key;

  /// Whether the file is ready to leave: drawn as it reads, no line on its way.
  bool get ready => current && _tagline != TaglineState.writing;

  String get fileName => '${idCardFileStem(_name)}-id-card.png';

  String get _key => '$_name\n${_line.trim()}';

  final List<String> _seen = [];
  int _asked = 0;
  bool _started = false;
  bool _portraitLoaded = false;
  Uint8List? _portrait;
  Timer? _timer;
  bool _disposed = false;

  void start() {
    if (_started) return;
    _started = true;
    another();
    unawaited(_fetchPortrait());
  }

  /// The card was renamed under the page.
  set name(String next) {
    if (next == _name) return;
    _name = next;
    _changed();
  }

  /// Ask for a different line.
  void another() {
    final ticket = ++_asked;
    _tagline = TaglineState.writing;
    _error = null;
    _notify();
    final avoid = _seen.length > 8 ? _seen.sublist(_seen.length - 8) : List.of(_seen);
    _ask(avoid).then((next) {
      if (_disposed || ticket != _asked) return;
      _seen.add(next);
      _line = next;
      _tagline = TaglineState.ready;
      _changed();
    }, onError: (Object e) {
      debugPrint('[idCard] tagline failed: $e');
      if (_disposed || ticket != _asked) return;
      _error = describeTaglineError(e);
      _tagline = TaglineState.failed;
      _notify();
    });
  }

  /// Put the author's own words on the card; a line still being written is
  /// dropped rather than landing over them.
  void edit(String next) {
    _asked++;
    _line = next;
    _error = null;
    _tagline = TaglineState.ready;
    _changed();
  }

  Future<void> _fetchPortrait() async {
    Uint8List? bytes;
    try {
      bytes = await _loadPortrait();
    } catch (e) {
      // Drawn with the initial instead — a card without its picture is
      // still a card.
      debugPrint('[idCard] portrait fetch failed: $e');
    }
    if (_disposed) return;
    _portrait = bytes;
    _portraitLoaded = true;
    _changed();
  }

  /// What the card says changed: redraw a beat after the last change, so
  /// typing a line redraws once rather than per key.
  void _changed() {
    _notify();
    if (!_portraitLoaded) return;
    _timer?.cancel();
    _timer = Timer(_redrawDelay, _redraw);
  }

  Future<void> _redraw() async {
    final key = _key;
    try {
      final png = await _draw(IdCardFace(name: _name, tagline: _line.trim()), _portrait);
      if (_disposed || key != _key) return;
      _png = png;
      _drawnKey = key;
      _notify();
    } catch (e) {
      debugPrint('[idCard] draw failed: $e');
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    super.dispose();
  }
}

String describeTaglineError(Object e) {
  final code = e is ServerError ? e.code : null;
  return switch (code) {
    'rate_limited' => 'Too many at once — give it a minute.',
    'network_error' => "You're offline — the card can go without a line.",
    _ => 'No line came back — try another.',
  };
}

const Map<String, String> _folds = {
  'à': 'a', 'á': 'a', 'â': 'a', 'ã': 'a', 'ä': 'a', 'å': 'a', 'æ': 'ae', 'ç': 'c',
  'è': 'e', 'é': 'e', 'ê': 'e', 'ë': 'e', 'ì': 'i', 'í': 'i', 'î': 'i', 'ï': 'i',
  'ñ': 'n', 'ò': 'o', 'ó': 'o', 'ô': 'o', 'õ': 'o', 'ö': 'o', 'ø': 'o', 'œ': 'oe',
  'ù': 'u', 'ú': 'u', 'û': 'u', 'ü': 'u', 'ý': 'y', 'ÿ': 'y', 'ß': 'ss',
};

/// The name as a file name: accents folded, anything else a dash. Dart has no
/// NFD, so the fold is a table of the Latin letters a name is likely to carry;
/// anything past it becomes a dash, and an empty result is "character".
String idCardFileStem(String name) {
  final folded = name.toLowerCase().split('').map((c) => _folds[c] ?? c).join();
  final stem = folded.replaceAll(RegExp('[^a-z0-9]+'), '-').replaceAll(RegExp(r'^-|-$'), '');
  return stem.isEmpty ? 'character' : stem;
}
