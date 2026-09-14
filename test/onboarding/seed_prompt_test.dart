import 'package:flutter_test/flutter_test.dart';
import 'package:ghostkey/screens/onboarding/seed_prompt.dart';

// The first message the guided branch sends. It asks for two questions a
// person can answer without having an idea yet, and says nothing about the book
// — the author on this branch has told us they don't know where to start, so
// the conversation asks rather than the form.

void main() {
  group('seedPrompt', () {
    test('asks the two things a person can answer without an idea', () {
      final prompt = seedPrompt();
      expect(prompt, contains('what made me want to write'));
      expect(prompt, contains('what kind of books I love'));
    });

    test("is in the author's voice, not instructions to a model", () {
      // It is the first line of their own transcript and they can scroll back
      // to it, so it has to read like something they said.
      expect(seedPrompt(), startsWith('Ask me'));
    });

    test('names no room, because the chat reads the handbook for that', () {
      final prompt = seedPrompt().toLowerCase();
      for (final room in ['mara', 'apparition', 'veil', 'glamour', 'poltergeist']) {
        expect(prompt, isNot(contains(room)));
      }
    });
  });
}
