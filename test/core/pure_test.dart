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
    test('punctuation alone is not a word', () {
      expect(countWords('\u00ab\u202fViens\u202f!\u202f\u00bb \u2014 dit-il.'), 2);
      expect(countWords("l'homme qu\u2019il aime"), 3);
      expect(countWords('# Chapitre un\n\n---\n\n* item'), 3);
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
        ChapterGroup(id: 'g1', name: 'Part One', chapters: [doc('b', 'One.md'), doc('c', 'Two.md')]),
        doc('d', 'Epilogue.md'),
      ];
      final open = filterChapterTree(tree, '', (_) => false);
      expect(open.length, 5);
      expect(open[1], isA<FolderRow>());
      expect((open[2] as ChapterRow).nested, isTrue);

      final collapsed = filterChapterTree(tree, '', (f) => f == 'g1');
      expect(collapsed.length, 3);

      final searched = filterChapterTree(tree, 'two', (_) => true);
      expect(searched.length, 1);
      expect((searched.single as ChapterRow).nested, isFalse);
    });
  });

  group('chapter reorder', () {
    final tree = <ChaptersListEntry>[
      doc('a', 'A.md'),
      ChapterGroup(id: 'gF', name: 'F', chapters: [doc('b', 'B.md'), doc('c', 'C.md')]),
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
      final next = moveChapterRow(tree, rows((f) => f == 'gF'), 2, 1, (f) => f == 'gF');
      expect(next.map((e) => e is ChapterGroup ? 'F' : (e as DocumentSummary).id), ['a', 'd', 'F']);
      expect((next[2] as ChapterGroup).chapters.length, 2);
    });

    test('a folder row is never moved', () {
      final next = moveChapterRow(tree, rows((_) => false), 1, 0, (_) => false);
      expect(next.length, tree.length);
    });

    group('two folders with the same name', () {
      final twins = <ChaptersListEntry>[
        ChapterGroup(id: 'g1', name: 'Part', chapters: [doc('a', 'A.md'), doc('b', 'B.md')]),
        doc('x', 'X.md'),
        ChapterGroup(id: 'g2', name: 'Part', chapters: [doc('c', 'C.md')]),
      ];
      bool firstCollapsed(String id) => id == 'g1';

      test('carry their ids through the wire', () {
        final entry = chaptersListEntryFromJson({'id': 'g2', 'name': 'Part', 'chapters': <Object>[]});
        expect(entry, isA<ChapterGroup>());
        expect((entry as ChapterGroup).id, 'g2');
        expect(entry.toJson(), {'id': 'g2', 'name': 'Part', 'chapters': <Object>[]});
      });

      test('collapse independently', () {
        // rows: Part(g1), X, Part(g2), C
        final drawn = filterChapterTree(twins, '', firstCollapsed);
        expect(drawn.map((r) => r is FolderRow ? r.id : (r as ChapterRow).doc.id), ['g1', 'x', 'g2', 'c']);
      });

      test('reorder independently, keeping their ids', () {
        // rows: Part(g1), X, Part(g2), C → move X (1) under the open g2 heading (2)
        final drawn = filterChapterTree(twins, '', firstCollapsed);
        final next = moveChapterRow(twins, drawn, 1, 2, firstCollapsed);
        expect(next.length, 2);
        final first = next[0] as ChapterGroup;
        final second = next[1] as ChapterGroup;
        expect(first.id, 'g1');
        expect(first.chapters.map((c) => c.id), ['a', 'b']);
        expect(second.id, 'g2');
        expect(second.chapters.map((c) => c.id), ['x', 'c']);
      });

      test('a collapsed twin keeps its own chapters, not its namesake\'s', () {
        bool secondCollapsed(String id) => id == 'g2';
        // rows: Part(g1), A, B, X, Part(g2) → move X (3) to the top (0)
        final drawn = filterChapterTree(twins, '', secondCollapsed);
        final next = moveChapterRow(twins, drawn, 3, 0, secondCollapsed);
        expect(next.map((e) => e is ChapterGroup ? e.id : (e as DocumentSummary).id), ['x', 'g1', 'g2']);
        expect((next[2] as ChapterGroup).chapters.map((c) => c.id), ['c']);
      });
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
