import 'package:flutter_test/flutter_test.dart';
import 'package:ghostkey/core/chapter_reorder.dart';
import 'package:ghostkey/core/chapter_search.dart';
import 'package:ghostkey/core/dictation_join.dart';
import 'package:ghostkey/core/words.dart';
import 'package:ghostkey/server/dto/projects.dart';

DocumentSummary doc(String id, String filename) => DocumentSummary(
      id: id,
      kind: DocumentKind.chapter,
      filename: filename,
      version: 1,
      wordCount: 0,
      updatedAt: '',
    );

void main() {
  group('words', () {
    test('counts whitespace-delimited words', () {
      expect(countWords(null), 0);
      expect(countWords('  '), 0);
      expect(countWords('one two  three\nfour'), 4);
    });
    test('formats with space groups', () {
      expect(formatWords(0), '0');
      expect(formatWords(999), '999');
      expect(formatWords(12345), '12 345');
      expect(formatWords(1234567), '1 234 567');
    });
  });

  group('chapter search', () {
    test('matches case- and accent-blind', () {
      expect(matchesQuery('Épilogue', 'epi'), isTrue);
      expect(matchesQuery('Chapitre Dix', 'DIX'), isTrue);
      expect(matchesQuery('Où est Ægir', 'aegir'), isTrue);
      expect(matchesQuery('Chapter', 'x'), isFalse);
      expect(matchesQuery('Anything', '   '), isTrue);
    });

    test('flattens the tree and hides collapsed folders', () {
      final tree = <ChaptersListEntry>[
        doc('a', 'Prologue.md'),
        ChapterGroup(name: 'Part One', chapters: [doc('b', 'One.md'), doc('c', 'Two.md')]),
        doc('d', 'Epilogue.md'),
      ];
      final open = filterChapterTree(tree, '', (_) => false);
      expect(open.length, 5);
      expect(open[1], isA<FolderRow>());
      expect((open[2] as ChapterRow).nested, isTrue);

      final collapsed = filterChapterTree(tree, '', (f) => f == 'Part One');
      expect(collapsed.length, 3);

      final searched = filterChapterTree(tree, 'two', (_) => true);
      expect(searched.length, 1);
      expect((searched.single as ChapterRow).nested, isFalse);
    });
  });

  group('chapter reorder', () {
    final tree = <ChaptersListEntry>[
      doc('a', 'A.md'),
      ChapterGroup(name: 'F', chapters: [doc('b', 'B.md'), doc('c', 'C.md')]),
      doc('d', 'D.md'),
    ];
    List<ChapterListRow> rows(bool Function(String) collapsed) => filterChapterTree(tree, '', collapsed);

    test('a chapter dropped under an open folder heading joins the folder', () {
      final next = moveChapterRow(tree, rows((_) => false), 0, 1, (_) => false);
      expect(next.length, 2);
      final folder = next[0] as ChapterGroup;
      expect(folder.chapters.map((c) => c.id), ['a', 'b', 'c']);
    });

    test('a chapter dropped under a top-level chapter leaves the folder', () {
      // rows: A, F, B, C, D → move B (index 2) to the end (index 4)
      final next = moveChapterRow(tree, rows((_) => false), 2, 4, (_) => false);
      expect(next.last, isA<DocumentSummary>());
      expect((next.last as DocumentSummary).id, 'b');
      expect((next[1] as ChapterGroup).chapters.map((c) => c.id), ['c']);
    });

    test('a collapsed folder travels as a unit and keeps its chapters', () {
      // rows: A, F, D → move D (2) above F (1)
      final next = moveChapterRow(tree, rows((f) => f == 'F'), 2, 1, (f) => f == 'F');
      expect(next.map((e) => e is ChapterGroup ? 'F' : (e as DocumentSummary).id), ['a', 'd', 'F']);
      expect((next[2] as ChapterGroup).chapters.length, 2);
    });

    test('a folder row is never moved', () {
      final next = moveChapterRow(tree, rows((_) => false), 1, 0, (_) => false);
      expect(next.length, tree.length);
    });
  });

  group('dictation join', () {
    test('hands the mark back to a word', () {
      final s = splitClosingMark('the end', '. Next sentence');
      expect(s.mark, '.');
      expect(s.body, 'Next sentence');
    });
    test('drops the mark after punctuation or nothing', () {
      expect(splitClosingMark('the end,', '. Next').mark, '');
      expect(splitClosingMark('', '? Next').mark, '');
      expect(splitClosingMark('done”', '! Next').mark, '');
    });
    test('no mark is the ordinary case', () {
      final s = splitClosingMark('the end', 'Next sentence');
      expect(s.mark, '');
      expect(s.body, 'Next sentence');
    });
  });
}
