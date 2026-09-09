import 'package:flutter_test/flutter_test.dart';
import 'package:ghostkey/core/chapter_search.dart';
import 'package:ghostkey/ds/tokens.dart';
import 'package:ghostkey/screens/apparition/drawer/drawer_items.dart';
import 'package:ghostkey/server/dto/projects.dart';

DocumentSummary _doc(String id, {DocumentKind kind = DocumentKind.chapter}) => DocumentSummary(
      id: id,
      kind: kind,
      filename: '$id.md',
      version: 1,
      wordCount: 0,
      updatedAt: '',
    );

void main() {
  final tree = <ChaptersListEntry>[
    _doc('one'),
    ChapterGroup(name: 'Part 2', chapters: [_doc('two'), _doc('three')]),
    _doc('four'),
  ];
  final notes = [_doc('n1', kind: DocumentKind.note), _doc('n2', kind: DocumentKind.note)];

  group('layoutDrawer', () {
    test('offsets are arithmetic on the tokens', () {
      final rows = filterChapterTree(tree, '', (_) => false);
      final layout = layoutDrawer(rows, notes, '');
      // header, one, Part 2, two, three, four, gap, header, n1, n2
      expect(layout.items.length, 10);
      expect(layout.offsets[1], DsGeom.row);
      expect(layout.offsets[6], 6 * DsGeom.row);
      expect(layout.offsets[7], 6 * DsGeom.row + drawerGapHeight);
      expect(layout.offsets[8], 7 * DsGeom.row + drawerGapHeight);
      expect(layout.chaptersMessage, isNull);
      expect(layout.showNotes, isTrue);
    });

    test('draggable rows carry their index in their OWN group', () {
      final rows = filterChapterTree(tree, '', (_) => false);
      final layout = layoutDrawer(rows, notes, '');
      final two = layout.items.whereType<ChapterItem>().firstWhere((c) => c.doc.id == 'two');
      expect(two.index, 2);
      expect(two.nested, isTrue);
      final n2 = layout.items.whereType<NoteItem>().last;
      expect(n2.index, 1);
      expect(layout.items.whereType<FolderItem>().single.index, 1);
    });

    test('the active chapter is found by offset even inside a folder', () {
      final rows = filterChapterTree(tree, '', (_) => false);
      final layout = layoutDrawer(rows, notes, '');
      expect(layout.offsetOfChapter('three.md'), 4 * DsGeom.row);
      expect(layout.offsetOfChapter('n1.md'), isNull);
      expect(layout.offsetOfChapter(null), isNull);
    });

    test('a collapsed folder contributes only its heading', () {
      final rows = filterChapterTree(tree, '', (name) => name == 'Part 2');
      final layout = layoutDrawer(rows, notes, '');
      expect(layout.offsetOfChapter('four.md'), 3 * DsGeom.row);
    });

    test('an empty book says so, at the message height', () {
      final layout = layoutDrawer(const [], const [], '');
      expect(layout.chaptersMessage, 'No chapters yet.');
      expect(layout.items[1], isA<MessageItem>());
      expect(layout.offsets[2], DsGeom.row + drawerMessageHeight);
    });

    test('a search that matches no chapter but a note keeps the notes', () {
      final rows = filterChapterTree(tree, 'n1', (_) => false);
      final layout = layoutDrawer(rows, [notes.first], 'n1');
      expect(layout.chaptersMessage, 'No chapter by that name.');
      expect(layout.showNotes, isTrue);
      expect(layout.items.whereType<HeaderItem>().last.addable, isFalse);
    });

    test('a search that matches no note hides the section', () {
      final rows = filterChapterTree(tree, 'one', (_) => false);
      final layout = layoutDrawer(rows, const [], 'one');
      expect(layout.showNotes, isFalse);
      expect(layout.items.whereType<GapItem>(), isEmpty);
    });
  });

  group('revealOffset', () {
    test('keeps three rows of neighbours above the active one', () {
      expect(revealOffset(10 * DsGeom.row), 7 * DsGeom.row);
    });

    test('never scrolls before the top', () {
      expect(revealOffset(DsGeom.row), 0);
    });
  });
}
