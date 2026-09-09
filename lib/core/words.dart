final RegExp _word = RegExp(r'\S+');

/// Words in a manuscript string (whitespace-delimited, markdown-naive).
int countWords(String? text) {
  if (text == null || text.isEmpty) return 0;
  return _word.allMatches(text.trim()).length;
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
