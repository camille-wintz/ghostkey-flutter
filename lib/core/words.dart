final RegExp _token = RegExp(r'\S+');

/// The marks a token made only of is not a word. Mirrors the server's
/// `src/lib/text/words.ts` and the desktop's `countWords` — edit them
/// together. French spacing is why: its no-break spaces set « » and ; : ! ?
/// apart, and a plain whitespace split counts each of them as a word.
final Set<int> _punctuation = "!\"#\$%&'()*+,-./:;<=>?@[\\]^_`{|}~«»‹›“”‘’„‚—–…¡¿•·".runes.toSet();

/// Words in a manuscript string: whitespace-delimited tokens holding
/// something other than punctuation — l'homme and dit-il are one word each,
/// a lone « or — is none.
int countWords(String? text) {
  if (text == null || text.isEmpty) return 0;
  return _token.allMatches(text).where((m) => m[0]!.runes.any((r) => !_punctuation.contains(r))).length;
}

/// Space-grouped display form ("12 345"), matching the editor's title block.
String formatWords(int count) {
  final digits = count.abs().toString();
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(' ');
    buffer.write(digits[i]);
  }
  return count < 0 ? '-$buffer' : buffer.toString();
}
