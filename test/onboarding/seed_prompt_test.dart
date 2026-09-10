import 'package:flutter_test/flutter_test.dart';
import 'package:ghostkey/screens/onboarding/seed_prompt.dart';

// The two pure things the first-run flow does with what the author typed: it
// asks the chat with it, and it names the book after it.

void main() {
  group('titleFromIdea', () {
    test('a short premise is the title as typed', () {
      expect(titleFromIdea('The Drowned Orchard'), 'The Drowned Orchard');
    });

    test('nothing typed falls back rather than making an empty book', () {
      expect(titleFromIdea('   '), defaultTitle);
      expect(titleFromIdea(''), defaultTitle);
    });

    test('a long one is cut at a word, never mid-word', () {
      final title = titleFromIdea(
        'A lighthouse keeper who has never seen the sea in daylight, and the winter the lamp goes out',
      );
      expect(title, 'A lighthouse keeper who has never seen the sea in daylight');
      expect(title.length, lessThanOrEqualTo(60));
    });

    test('the punctuation it landed on comes off', () {
      // A spine reading "…in daylight," looks like a bug, not a title.
      expect(titleFromIdea('${'x' * 55} word, and more'), isNot(endsWith(',')));
    });

    test('runs of whitespace collapse, so a pasted premise is one line', () {
      expect(titleFromIdea('A house\n\n  behind a river'), 'A house behind a river');
    });
  });

  group('seedPrompt', () {
    test('asks the three things, and carries what the author said', () {
      final prompt = seedPrompt('A lighthouse keeper');
      expect(prompt, contains('refine my idea'));
      expect(prompt, contains('plotting'));
      expect(prompt, contains('beats'));
      expect(prompt, contains("Here's what I have so far: A lighthouse keeper"));
    });

    test('an empty idea leaves the sentence out rather than trailing a colon', () {
      final prompt = seedPrompt('   ');
      expect(prompt, isNot(contains('what I have so far')));
      expect(prompt, contains('refine my idea'));
    });

    test('a pasted essay is clipped — this is a first message, not a synopsis', () {
      final prompt = seedPrompt('y' * 2000);
      expect(prompt.length, lessThan(1200));
    });
  });
}
