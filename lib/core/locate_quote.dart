// Where a line-edit note's quote sits in the text, for REPLACING it — the
// desk's `findUniqueQuoteRange` (ghost-key/src/shared/utils/locateQuote.ts)
// and `resolveSuggestion`. Quotes are model output: usually verbatim, but
// typography drifts (curly vs straight quotes, guillemets, dashes, the
// no-break spaces French puts inside « »). So the match is exact, then
// typography-folded, and only ever unique: a quote that appears twice gives
// no evidence which one the note meant, and applying to the first is a coin
// flip on the author's prose. No prefix tier either — a prefix covers four
// words of a fifteen-word quote, and replacing it would splice the
// suggestion mid-sentence.

typedef QuoteRange = ({int from, int to});

/// Quote glyphs and dashes fold to their ASCII stand-ins; every space variant
/// folds to a plain space. One UTF-16 unit in, one out.
const Map<String, String> _glyphs = {
  '‘': "'",
  '’': "'",
  '‚': "'",
  '‹': "'",
  '›': "'",
  '“': '"',
  '”': '"',
  '„': '"',
  '«': '"',
  '»': '"',
  '–': '-',
  '—': '-',
  ' ': ' ',
  ' ': ' ',
  '\n': ' ',
  '\r': ' ',
  '\t': ' ',
};

/// Marks French spacing puts a no-break space before.
const String _spacedMarks = ';:!?';

/// `map[i]` is the index in the original of folded unit `i`; `map[length]` is
/// the original length, so a range end maps too.
typedef _Folded = ({String text, List<int> map});

/// A run of spaces collapses to one and a space next to a quotation mark, or
/// before ; : ! ?, is dropped, which is what makes the doc's `« Bonjour »` and a model's
/// `"Bonjour"` equal. Nothing else moves, so a folded index maps straight
/// back onto the original.
_Folded _fold(String s) {
  var last = '';
  final chars = <String>[];
  final map = <int>[];
  for (var i = 0; i < s.length; i++) {
    final ch = _glyphs[s[i]] ?? s[i].toLowerCase();
    if (ch == ' ') {
      if (last == ' ' || last == '"' || last == "'") continue;
    } else if (ch == '"' || ch == "'" || _spacedMarks.contains(ch)) {
      if (last == ' ') {
        chars.removeLast();
        map.removeLast();
      }
    }
    chars.add(ch);
    map.add(i);
    last = ch;
  }
  map.add(s.length);
  return (text: chars.join(), map: map);
}

/// 0, 1 or 2 — the callers only ask "exactly one?".
int _countUpToTwo(String haystack, String needle) {
  final first = haystack.indexOf(needle);
  if (first == -1) return 0;
  return haystack.indexOf(needle, first + (needle.isEmpty ? 1 : needle.length)) == -1 ? 1 : 2;
}

/// The unique range of `quote` in `doc`, or null — which is the normal answer
/// for a badly-behaved quote, not an error.
QuoteRange? findUniqueQuoteRange(String doc, String quote) {
  final trimmed = quote.trim();
  if (trimmed.isEmpty) return null;

  if (_countUpToTwo(doc, trimmed) == 1) {
    final at = doc.indexOf(trimmed);
    return (from: at, to: at + trimmed.length);
  }
  final foldedDoc = _fold(doc);
  final foldedQuote = _fold(trimmed).text.trim();
  if (foldedQuote.isEmpty) return null;
  if (_countUpToTwo(foldedDoc.text, foldedQuote) != 1) return null;
  final at = foldedDoc.text.indexOf(foldedQuote);
  // One past the last matched unit, not the start of the next surviving one:
  // a space the fold dropped after the match (after a closing », before a
  // French !) stays outside the range instead of being replaced away.
  return (from: foldedDoc.map[at], to: foldedDoc.map[at + foldedQuote.length - 1] + 1);
}

/// Why a note has no Accept.
enum Unappliable {
  /// The model saw a problem and offered no wording, or offered what is
  /// already there.
  noSuggestion,

  /// The quote is gone from the text, or appears more than once.
  notFound,
}

sealed class ResolvedNote {
  const ResolvedNote();
}

class Applicable extends ResolvedNote {
  const Applicable(this.range, this.proposed);
  final QuoteRange range;
  final String proposed;
}

class NotApplicable extends ResolvedNote {
  const NotApplicable(this.reason);
  final Unappliable reason;
}

/// Resolve one note's quote and suggestion against `doc` as it stands now.
ResolvedNote resolveNote(String doc, String quote, String? suggestion) {
  final proposed = suggestion?.trim() ?? '';
  if (proposed.isEmpty) return const NotApplicable(Unappliable.noSuggestion);
  final range = findUniqueQuoteRange(doc, quote);
  if (range == null) return const NotApplicable(Unappliable.notFound);
  // The model quoting its own proposal back is not a fix, and applying it
  // would bump the version for nothing.
  if (doc.substring(range.from, range.to) == proposed) return const NotApplicable(Unappliable.noSuggestion);
  return Applicable(range, proposed);
}
