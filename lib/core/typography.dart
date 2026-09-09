// Smart-typography transform, mirrored from the desktop
// (`ghost-key/core/ghostFile/typography.ts`), the server
// (`ghostkey-server/src/lib/projects/publish/typography.ts`) and the RN app
// (`ghostkey-mobile/src/lib/typography.ts`) — four copies, ONE text: edit all
// together. `test/core/typography_test.dart` pins this copy to the same
// fixture table the others answer.
//
// The mode is a QUOTE STYLE the project chooses, not a language.
//
//   curly       “double” and ‘single’ — the English-language convention
//   guillemets  « double » with a narrow no-break space inside, and the
//               French spacing rule: a no-break space before ; ! ? and :
//   german      „double“ and ‚single‘
//   none        the text as typed — nothing touched
//
// Every mode but `none` also turns `--` into an em dash and `...` into an
// ellipsis, and curls an apostrophe to ’. No-break spaces are written as
// escapes throughout: the characters are invisible.

import '../server/dto/projects.dart';

export '../server/dto/projects.dart' show TypographyMode;

const TypographyMode defaultTypography = TypographyMode.curly;

const String _nbsp = '\u00A0';
const String _nnbsp = '\u202F';

class _QuoteStyle {
  const _QuoteStyle({
    required this.open,
    required this.close,
    required this.openers,
    required this.closers,
    required this.singleOpen,
    required this.singleClose,
    required this.singleOpeners,
    required this.singleClosers,
    required this.spaceBefore,
  });

  final String open;
  final String close;
  final String openers;
  final String closers;
  final String singleOpen;
  final String singleClose;
  final String singleOpeners;
  final String singleClosers;
  final Map<String, String> spaceBefore;
}

const Map<TypographyMode, _QuoteStyle> _styles = {
  TypographyMode.curly: _QuoteStyle(
    open: '“',
    close: '”',
    openers: '“',
    closers: '”',
    singleOpen: '‘',
    singleClose: '’',
    singleOpeners: '‘',
    singleClosers: '’',
    spaceBefore: {},
  ),
  TypographyMode.guillemets: _QuoteStyle(
    open: '«$_nnbsp',
    close: '$_nnbsp»',
    openers: '«“',
    closers: '»”',
    singleOpen: '‘',
    singleClose: '’',
    singleOpeners: '‘',
    singleClosers: '’',
    spaceBefore: {';': _nnbsp, '!': _nnbsp, '?': _nnbsp, ':': _nbsp},
  ),
  TypographyMode.german: _QuoteStyle(
    open: '„',
    close: '“',
    openers: '„',
    closers: '“',
    singleOpen: '‚',
    singleClose: '‘',
    singleOpeners: '‚',
    singleClosers: '‘',
    spaceBefore: {},
  ),
};

/// The characters whose arrival can change the text under any mode — what an
/// input handler checks before paying for a parity scan of the document.
final RegExp _triggers = RegExp('["\'‘’‚“”„«».\\-;:!? ]');

final RegExp _wordChar = RegExp(r'[\p{L}\p{N}]', unicode: true);
final RegExp _takesSpace = RegExp(r'[\p{L}\p{N}»”’)\]]', unicode: true);

bool _isWordChar(String? ch) => ch != null && _wordChar.hasMatch(ch);

/// What French spacing attaches to: a word, a digit, or the closing mark of
/// something — never another punctuation mark or a space.
bool _takesSpaceBefore(String? ch) => ch != null && _takesSpace.hasMatch(ch);

bool _isNoBreakSpace(String? ch) => ch == _nbsp || ch == _nnbsp;

String? _lastChar(String text) => text.isEmpty ? null : text[text.length - 1];

String? _charAt(String text, int i) => i >= 0 && i < text.length ? text[i] : null;

class _QuoteState {
  bool doubleOpen = false;
  bool singleOpen = false;
}

_QuoteState _quoteStateFor(String text, _QuoteStyle style) {
  final state = _QuoteState();
  String? prev;
  for (var i = 0; i < text.length; i++) {
    final ch = text[i];
    final next = _charAt(text, i + 1);
    if (ch == '"') {
      state.doubleOpen = !state.doubleOpen;
    } else if (style.openers.contains(ch)) {
      state.doubleOpen = true;
    } else if (style.closers.contains(ch)) {
      state.doubleOpen = false;
    } else if (ch == "'") {
      if (!(_isWordChar(prev) && _isWordChar(next))) state.singleOpen = !state.singleOpen;
    } else if (style.singleOpeners.contains(ch)) {
      state.singleOpen = true;
    } else if (style.singleClosers.contains(ch)) {
      if (!(_isWordChar(prev) && _isWordChar(next))) state.singleOpen = false;
    }
    prev = ch;
  }
  return state;
}

/// Apply the project's typography to `text`, seeding quote parity from
/// `contextBefore` (the document up to the insertion point) so a quotation
/// opened earlier closes as one. `contextBefore` is read, never rewritten.
String applyTypography(String text, String contextBefore, TypographyMode mode) {
  if (mode == TypographyMode.none) return text;
  final style = _styles[mode]!;
  final state = _quoteStateFor(contextBefore, style);
  final result = StringBuffer();
  String out() => result.toString();

  // The TS original slices a possibly-empty string, which is a no-op there
  // and a range error here.
  void dropLast([int n = 1]) {
    final s = out();
    result
      ..clear()
      ..write(s.length > n ? s.substring(0, s.length - n) : '');
  }

  for (var i = 0; i < text.length; i++) {
    final ch = text[i];
    final current = out();
    final prev = _lastChar(current) ?? _lastChar(contextBefore);
    final next = _charAt(text, i + 1);

    if (ch == '"') {
      if (state.doubleOpen) {
        // A plain space typed before the closing mark becomes the mark's own
        // no-break space (« Bonjour » is the spaced form, not « Bonjour  »).
        if (mode == TypographyMode.guillemets && _lastChar(current) == ' ') dropLast();
        result.write(style.close);
      } else {
        result.write(style.open);
        // …and one typed after the opening mark is swallowed the same way.
        if (mode == TypographyMode.guillemets && next == ' ') i++;
      }
      state.doubleOpen = !state.doubleOpen;
    } else if (mode == TypographyMode.guillemets && ch == '«') {
      result.write(style.open);
      if (next == ' ') i++;
      state.doubleOpen = true;
    } else if (mode == TypographyMode.guillemets && ch == '»') {
      if (_lastChar(current) == ' ') dropLast();
      result.write(_isNoBreakSpace(_lastChar(out())) ? '»' : style.close);
      state.doubleOpen = false;
    } else if (mode == TypographyMode.guillemets && ch == ' ' && prev == _nnbsp) {
      // The space after « is already there — a second one is a typo.
      continue;
    } else if (ch == "'" || ch == '‘' || ch == '’') {
      if (_isWordChar(prev) && (next == null || _isWordChar(next))) {
        result.write('’');
      } else {
        result.write(state.singleOpen ? style.singleClose : style.singleOpen);
        state.singleOpen = !state.singleOpen;
      }
    } else if (ch == '-' && prev == '-') {
      dropLast();
      result.write('—');
    } else if (ch == '.' && current.length >= 2 && current.endsWith('..')) {
      dropLast(2);
      result.write('…');
    } else if (style.spaceBefore.containsKey(ch)) {
      final space = style.spaceBefore[ch]!;
      final beforeSpace = current.length >= 2 ? current[current.length - 2] : _lastChar(contextBefore);
      if (_lastChar(current) == ' ' && _takesSpaceBefore(beforeSpace)) {
        dropLast();
        result.write('$space$ch');
      } else if (_takesSpaceBefore(prev)) {
        result.write('$space$ch');
      } else {
        result.write(ch);
      }
    } else {
      result.write(ch);
    }
  }
  return out();
}

/// The text after a substitution, and where the caret lands.
class SmartEdit {
  const SmartEdit(this.text, this.cursor);
  final String text;
  final int cursor;
}

/// Recover the edit between two editor values and apply the project's
/// typography to it. Re-consumes whatever prefix already in the document the
/// keystroke completes — the ".." before a third dot, the "-" before a second
/// dash, the plain space before a quotation mark or a spaced punctuation mark
/// — so the sequence collapses across keystrokes. Returns null when the edit
/// needs no substitution.
SmartEdit? applySmartEdit(String prev, String next, TypographyMode mode) {
  if (mode == TypographyMode.none || next == prev) return null;

  var prefix = 0;
  final maxPrefix = prev.length < next.length ? prev.length : next.length;
  while (prefix < maxPrefix && prev[prefix] == next[prefix]) {
    prefix++;
  }

  var suffix = 0;
  final maxSuffix = maxPrefix - prefix;
  while (suffix < maxSuffix && prev[prev.length - 1 - suffix] == next[next.length - 1 - suffix]) {
    suffix++;
  }

  var insertion = next.substring(prefix, next.length - suffix);
  if (!_triggers.hasMatch(insertion)) return null;

  var replaceFrom = prefix;
  String before(int n) => replaceFrom >= n ? next.substring(replaceFrom - n, replaceFrom) : '';

  // A plain space typed straight after « is already there as the mark's own
  // no-break space — swallow it without paying for the parity scan.
  if (insertion == ' ') {
    if (mode != TypographyMode.guillemets || before(1) != _nnbsp) return null;
    return SmartEdit(next.substring(0, replaceFrom) + next.substring(replaceFrom + 1), replaceFrom);
  }

  if (insertion.startsWith('.') && before(2) == '..') {
    replaceFrom -= 2;
    insertion = '..$insertion';
  }
  if (insertion.startsWith('-') && replaceFrom == prefix && before(1) == '-') {
    replaceFrom -= 1;
    insertion = '-$insertion';
  }
  // The space before a closing » or a French ; : ! ? becomes the no-break
  // one, which the transform can only do if it sees that space.
  if (RegExp('^["»;:!?]').hasMatch(insertion) && replaceFrom == prefix && before(1) == ' ') {
    replaceFrom -= 1;
    insertion = ' $insertion';
  }

  final contextBefore = next.substring(0, replaceFrom);
  final replacement = applyTypography(insertion, contextBefore, mode);
  if (replacement == insertion) return null;

  return SmartEdit(
    contextBefore + replacement + next.substring(next.length - suffix),
    replaceFrom + replacement.length,
  );
}
