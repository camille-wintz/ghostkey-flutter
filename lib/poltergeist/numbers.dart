import '../core/words.dart';

const List<String> _ones = [
  'zero', 'one', 'two', 'three', 'four', 'five', 'six', 'seven', 'eight', 'nine',
  'ten', 'eleven', 'twelve', 'thirteen', 'fourteen', 'fifteen', 'sixteen',
  'seventeen', 'eighteen', 'nineteen',
];

const List<String> _tens = ['', '', 'twenty', 'thirty', 'forty', 'fifty', 'sixty', 'seventy', 'eighty', 'ninety'];

/// A small count as prose — the dashboard's summary says "sixty-one
/// chapters", not "61 chapters". Past two digits the figure reads better than
/// the words.
String spellNumber(int n) {
  if (n < 0 || n > 99) return formatWords(n);
  if (n < 20) return _ones[n];
  final ones = n % 10;
  return ones == 0 ? _tens[n ~/ 10] : '${_tens[n ~/ 10]}-${_ones[ones]}';
}

/// "1 chapter" / "3 chapters".
String plural(int n, String one, [String? many]) => '$n ${n == 1 ? one : (many ?? '${one}s')}';
