import 'package:flutter_test/flutter_test.dart';
import 'package:ghostkey/core/locate_quote.dart';

void main() {
  group('findUniqueQuoteRange', () {
    test('an exact, unique quote', () {
      const doc = 'She opened the door. The hall was dark.';
      expect(findUniqueQuoteRange(doc, 'The hall was dark'), (from: 21, to: 38));
    });

    test('a repeated quote is ambiguous', () {
      expect(findUniqueQuoteRange('She smiled. He left. She smiled.', 'She smiled'), isNull);
    });

    test('typography folds both ways and maps back onto the original', () {
      const doc = 'Il dit : « Bonjour » et partit.';
      final range = findUniqueQuoteRange(doc, '"Bonjour" et partit');
      expect(range, isNotNull);
      expect(doc.substring(range!.from, range.to), '« Bonjour » et partit');
    });

    test('curly apostrophes and em dashes match straight ones', () {
      const doc = 'It’s late — too late.';
      final range = findUniqueQuoteRange(doc, "It's late - too");
      expect(doc.substring(range!.from, range.to), 'It’s late — too');
    });

    test('a quote that is not there', () {
      expect(findUniqueQuoteRange('Nothing here.', 'something else'), isNull);
    });
  });

  group('resolveNote', () {
    test('no suggestion', () {
      expect((resolveNote('A cat.', 'cat', null) as NotApplicable).reason, Unappliable.noSuggestion);
    });

    test('a suggestion identical to the text', () {
      expect((resolveNote('A cat.', 'cat', 'cat') as NotApplicable).reason, Unappliable.noSuggestion);
    });

    test('a quote gone from the text', () {
      expect((resolveNote('A dog.', 'cat', 'kitten') as NotApplicable).reason, Unappliable.notFound);
    });

    test('an applicable note', () {
      final resolved = resolveNote('A cat sat.', 'cat', ' kitten ') as Applicable;
      expect(resolved.range, (from: 2, to: 5));
      expect(resolved.proposed, 'kitten');
    });
  });
}
