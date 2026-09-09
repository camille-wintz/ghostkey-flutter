import 'package:flutter_test/flutter_test.dart';
import 'package:ghostkey/screens/apparition/drawer/tree_edits.dart';
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
      ChapterGroup(name: 'Part', chapters: [_doc('b')]),
    ];
    final next = removeDocumentFromTree(tree, 'b');
    expect(next.length, 2);
    expect((next[1] as ChapterGroup).chapters, isEmpty);
    expect(chapterFilenamesInTree(removeDocumentFromTree(tree, 'a')), ['b.md']);
  });
}
