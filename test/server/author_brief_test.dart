import 'package:flutter_test/flutter_test.dart';
import 'package:ghostkey/server/dto/projects.dart';

void main() {
  test('a brief reads as its context', () {
    expect(
      authorBriefText({'context': '  Cozy fantasy, first draft. ', 'updated_at': ''}),
      'Cozy fantasy, first draft.',
    );
  });

  test('no brief reads as empty', () {
    expect(authorBriefText(null), '');
  });

  test('a structured brief from before July 2026 reads as labelled lines', () {
    expect(
      authorBriefText({
        'manuscript_state': 'second draft',
        'focus': ['pacing', 'voice'],
        'genre': 'thriller',
        'audience': ' ',
      }),
      'Stage: second draft\nWants feedback on: pacing, voice\nGenre: thriller',
    );
  });
}
