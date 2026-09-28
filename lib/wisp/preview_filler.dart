import '../server/dto/wisp.dart';

// What a preview draws under its blur: stand-in words, never the report's.
// The server never sends the rest (`lib/wisp/preview.ts`), so there is nothing
// real to blur; this only gives the blur the rough size of what is missing.

const List<String> _words = [
  'lorem', 'ipsum', 'dolor', 'sit', 'amet', 'consectetur', 'adipiscing', 'elit', 'sed', 'do', //
  'eiusmod', 'tempor', 'incididunt', 'ut', 'labore', 'et', 'dolore', 'magna', 'aliqua', 'enim', //
  'ad', 'minim', 'veniam', 'quis', 'nostrud', 'exercitation', 'ullamco', 'laboris', 'nisi', 'aliquip', //
  'ex', 'ea', 'commodo', 'consequat', 'duis', 'aute', 'irure', 'in', 'reprehenderit', 'voluptate',
];

/// Enough to read as more report; past it the blur is just a longer scroll.
const int previewFillerMaxWords = 400;

/// Below this the upgrade card would sit over nothing.
const int _minWords = 60;

const int _minParagraph = 25;
const int _maxParagraphs = 8;

/// Filler paragraphs roughly the size of [cut]: its hidden words, capped,
/// split into about its hidden units. The same cut always gives the same text,
/// so a rebuild does not reshuffle the blur.
List<String> previewFiller(PreviewCut cut) {
  final total = cut.hiddenWords.clamp(_minWords, previewFillerMaxWords);
  final count = cut.hiddenUnits.clamp(1, _maxParagraphs).clamp(1, total ~/ _minParagraph);
  final base = total ~/ count;
  var at = cut.hiddenWords;
  String word() => _words[(at = (at * 31 + 7) % 104729) % _words.length];
  return [
    for (var p = 0; p < count; p++)
      () {
        final n = base + (p < total % count ? 1 : 0);
        final text = List.generate(n, (_) => word()).join(' ');
        return '${text[0].toUpperCase()}${text.substring(1)}.';
      }(),
  ];
}
