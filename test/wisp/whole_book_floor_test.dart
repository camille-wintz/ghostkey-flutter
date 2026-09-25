import 'package:flutter_test/flutter_test.dart';
import 'package:ghostkey/server/dto/projects.dart';
import 'package:ghostkey/wisp/access.dart';

DocumentSummary _chapter(String id, int? words) => DocumentSummary(
      id: id,
      kind: DocumentKind.chapter,
      filename: '$id.md',
      version: 1,
      wordCount: words,
      updatedAt: '',
    );

void main() {
  test('the book is the sum of its chapters, folders included', () {
    final tree = <ChaptersListEntry>[
      _chapter('one', 200),
      ChapterGroup(id: 'g', name: 'Part One', chapters: [_chapter('two', 150), _chapter('three', 50)]),
    ];
    expect(manuscriptWords(tree), 400);
  });

  test('a chapter with no count yet makes the length unknown, not zero', () {
    expect(manuscriptWords([_chapter('one', 900), _chapter('two', null)]), isNull);
  });

  test('empty chapters are a book of zero words', () {
    expect(manuscriptWords([for (var i = 0; i < 86; i++) _chapter('c$i', 0)]), 0);
  });

  test('the floor is the server\'s', () => expect(wholeBookMinWords, 500));
}
