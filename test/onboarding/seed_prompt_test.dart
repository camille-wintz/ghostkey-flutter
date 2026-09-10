import 'package:flutter_test/flutter_test.dart';
import 'package:ghostkey/screens/onboarding/seed_prompt.dart';

// The first message the guided branch sends. It asks for three things and says
// nothing about the book — the author on this branch has told us they don't
// know where to start, so the conversation asks rather than the form.

void main() {
  group('seedPrompt', () {
    test('asks the three things the branch exists for', () {
      final prompt = seedPrompt();
      expect(prompt, contains('refine my idea'));
      expect(prompt, contains('genre'));
      expect(prompt, contains('plotting'));
      expect(prompt, contains('beats'));
      expect(prompt, contains('chapters'));
    });

    test("is in the author's voice, not instructions to a model", () {
      // It is the first line of their own transcript and they can scroll back
      // to it, so it has to read like something they said.
      expect(seedPrompt(), startsWith('I want to write a book'));
    });

    test('names no room, because the chat reads the handbook for that', () {
      final prompt = seedPrompt().toLowerCase();
      for (final room in ['mara', 'apparition', 'veil', 'glamour', 'poltergeist']) {
        expect(prompt, isNot(contains(room)));
      }
    });
  });
}
