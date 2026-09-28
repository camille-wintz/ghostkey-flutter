import 'package:flutter_test/flutter_test.dart';
import 'package:ghostkey/screens/apparition/nav/tree_edits.dart';
import 'package:ghostkey/server/dto/projects.dart';

DocumentSummary _doc(String id) =>
    DocumentSummary(id: id, kind: DocumentKind.chapter, filename: '$id.md', version: 1, wordCount: 0, updatedAt: '');

void main() {
  test('nextChapterFilename fills the first gap', () {
    expect(nextChapterFilename(const []), 'chapter-1.md');
    expect(nextChapterFilename(const ['chapter-1.md', 'chapter-3.md']), 'chapter-2.md');
  });

  test('nextNoteFilename matches the desktop naming', () {
    expect(nextNoteFilename(const ['Note 1.md']), 'Note 2.md');
  });

  test('removeDocumentFromTree drops the document and keeps an emptied folder', () {
    final tree = <ChaptersListEntry>[
      _doc('a'),
      ChapterGroup(id: 'g1', name: 'Part', chapters: [_doc('b')]),
    ];
    final next = removeDocumentFromTree(tree, 'b');
    expect(next.length, 2);
    expect((next[1] as ChapterGroup).chapters, isEmpty);
    expect(chapterFilenamesInTree(removeDocumentFromTree(tree, 'a')), ['b.md']);
  });

  test('appendChapterToFolder puts the chapter last in that folder only', () {
    final tree = <ChaptersListEntry>[
      ChapterGroup(id: 'g1', name: 'Part One', chapters: [_doc('a')]),
      ChapterGroup(id: 'g2', name: 'Part Two', chapters: [_doc('b')]),
      _doc('c'),
    ];
    final next = appendChapterToFolder(tree, 'g1', _doc('n'));
    expect(chapterFilenamesInTree(next), ['a.md', 'n.md', 'b.md', 'c.md']);
    expect((next[0] as ChapterGroup).chapters.map((d) => d.id), ['a', 'n']);
  });

  test('appendChapterToFolder puts it last in the book when the folder is gone', () {
    final next = appendChapterToFolder([_doc('a')], 'gone', _doc('n'));
    expect(chapterFilenamesInTree(next), ['a.md', 'n.md']);
  });
}
