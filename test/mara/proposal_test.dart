import 'package:flutter_test/flutter_test.dart';
import 'package:ghostkey/mara/changeset.dart';
import 'package:ghostkey/mara/proposal.dart';
import 'package:ghostkey/server/dto/plan.dart';
import 'package:ghostkey/server/dto/projects.dart';

ProposalChapter chapter(String id, {String origin = 'outline', bool matched = false, bool copy = false}) =>
    ProposalChapter.fromJson({
      'id': id,
      'title': id,
      'notes': '',
      'origin': origin,
      'match': matched
          ? {'document_id': 'doc-$id', 'filename': '$id.md', 'words': 10, 'confidence': 'strong', 'reason': ''}
          : null,
      'use_as_reference': false,
      'copy_prose': copy,
    });

ProposalPart part(String id, List<ProposalChapter> chapters) =>
    ProposalPart(id: id, name: id, chapters: chapters, raw: {'id': id, 'name': id, 'chapters': const <Object>[]});

List<String> shape(List<ProposalEntry> entries) => [
      for (final e in entries)
        switch (e) {
          ProposalChapter() => e.id,
          ProposalPart() => '${e.id}[${e.chapters.map((c) => c.id).join(',')}]',
        },
    ];

DocumentSummary doc(String id) =>
    DocumentSummary(id: id, kind: DocumentKind.chapter, filename: '$id.md', version: 1, wordCount: 10, updatedAt: '');

bool never(String _) => false;

void main() {
  test('a chapter is written, kept or still to write, and the chips count each', () {
    final chapters = [chapter('a', matched: true), chapter('b', origin: 'existing', matched: true), chapter('c')];
    expect(chapters.map(chapterStatus), [ChapterStatus.written, ChapterStatus.kept, ChapterStatus.fresh]);
    final filters = statusFilters([...chapters, chapter('d')]);
    expect(filters.first, (status: null, count: 4));
    expect(filters.map((f) => f.status), [null, ChapterStatus.written, ChapterStatus.kept, ChapterStatus.fresh]);
  });

  test('the carry question is mixed, then all, then none', () {
    final entries = <ProposalEntry>[chapter('a', matched: true, copy: true), chapter('b', matched: true), chapter('c')];
    final mixed = proposalCarry(proposalChapters(entries));
    expect((mixed.carried, mixed.carryable, mixed.mixed), (1, 2, true));
    final on = withCarry(entries, true);
    expect(proposalCarry(proposalChapters(on)).checked, isTrue);
    // Carrying accepts the matches it carries.
    expect(proposalChapters(on).where((c) => c.match != null).every((c) => c.useAsReference), isTrue);
    expect(proposalCarry(proposalChapters(withCarry(entries, false))).hint, 'every chapter starts blank');
  });

  test('a dropped chapter goes back where it was, even inside a part', () {
    final entries = <ProposalEntry>[chapter('a'), part('P', [chapter('b'), chapter('c')])];
    final dropped = locateChapter(entries, 'c')!;
    final without = withoutChapter(entries, 'c');
    expect(shape(without), ['a', 'P[b]']);
    expect(shape(restoreChapters(without, [dropped])), ['a', 'P[b,c]']);
  });

  test('a part removed leaves its chapters standing in its place', () {
    final entries = <ProposalEntry>[chapter('a'), part('P', [chapter('b')]), chapter('c')];
    expect(shape(removePart(entries, 'P')), ['a', 'b', 'c']);
    expect(newPartName(entries), 'Part 2');
  });

  test('rows number the whole proposal, and a filter drops a part it empties', () {
    final entries = <ProposalEntry>[chapter('a', matched: true), part('P', [chapter('b'), chapter('c', matched: true)])];
    final all = proposalRows(entries, isCollapsed: never);
    expect(all.map((r) => r.id), ['a', 'P', 'b', 'c']);
    expect((all[3] as ProposalChapterRow).number, 3);
    final fresh = proposalRows(entries, isCollapsed: never, visible: (c) => chapterStatus(c) == ChapterStatus.fresh);
    expect(fresh.map((r) => r.id), ['P', 'b']);
    final folded = proposalRows(entries, isCollapsed: (id) => id == 'P');
    expect(folded.map((r) => r.id), ['a', 'P']);
  });

  test('a chapter dropped under a part joins it, and dropped at the top leaves it', () {
    final entries = <ProposalEntry>[chapter('a'), part('P', [chapter('b')]), chapter('c')];
    final rows = proposalRows(entries, isCollapsed: never);
    // Rows: a, P, b, c — `c` dropped straight under the part's heading.
    expect(shape(moveProposalRow(entries, rows, 3, 2, never)), ['a', 'P[c,b]']);
    // `b` dropped first, out of the part.
    expect(shape(moveProposalRow(entries, rows, 2, 0, never)), ['b', 'a', 'P[]', 'c']);
  });

  test('the manuscript chapters no card claims can be put back', () {
    final entries = <ProposalEntry>[chapter('a', matched: true)];
    final tree = <ChaptersListEntry>[doc('doc-a'), doc('x')];
    expect(unclaimedChapters(tree, entries, matchesStale: false).map((d) => d.id), ['x']);
    expect(unclaimedChapters(tree, entries, matchesStale: true), isEmpty);
    final back = chapterFromManuscript(doc('x'), id: 'n', carry: true);
    expect((back.origin, back.useAsReference, back.copyProse, back.match!.documentId), (ProposalOrigin.existing, true, true, 'x'));
  });

  group('a changeset over the book', () {
    ChangesetOp op(Map<String, dynamic> json) => ChangesetOp.fromJson(json)!;
    Map<String, dynamic> ref(String id) => {'document_id': id, 'filename': '$id.md'};
    final tree = <ChaptersListEntry>[doc('a'), ChapterGroup(id: 'g', name: 'Two', chapters: [doc('b'), doc('c')]), doc('d')];
    final ops = [
      op({'id': 'rm', 'op': 'remove', 'chapters': [ref('a')], 'reason': ''}),
      op({
        'id': 'rw',
        'op': 'rewrite',
        'chapters': [ref('b'), ref('c')],
        'with': [
          {'title': 'BC', 'notes': '', 'entities': <Object>[], 'from': null},
        ],
        'reason': '',
      }),
      op({
        'id': 'add',
        'op': 'add',
        'with': [
          {'title': 'N1', 'notes': '', 'entities': <Object>[], 'from': null},
          {'title': 'N2', 'notes': '', 'entities': <Object>[], 'from': null},
        ],
        'after': ref('d'),
        'reason': '',
      }),
    ];

    String kind(OverlayRow r) => switch (r) {
          OverlayPart(:final name) => 'part:$name',
          OverlayChapter(:final doc, :final removedBy) => '${doc.id}${removedBy == null ? '' : '-'}',
          OverlayRewrite(:final replaces) => 'rw@${replaces.id}',
          OverlayAdded(:final index) => 'new$index',
          OverlayOp(:final op, :final orphan) => 'op:${op.id}${orphan ? '?' : ''}',
        };

    test('lays each op where it acts', () {
      final rows = overlayChangeset(tree, ops, (_) => false);
      expect(rows.map(kind), ['a-', 'op:rm', 'part:Two', 'rw@b', 'd', 'new0', 'new1']);
    });

    test('a skipped op leaves its chapters as they are, and shows as its card', () {
      final rows = overlayChangeset(tree, ops, (id) => id != 'rm');
      expect(rows.map(kind), ['a-', 'op:rm', 'part:Two', 'b', 'c', 'op:rw', 'd', 'op:add']);
    });

    test('carries the kept chapters and the rewrite’s first card by default', () {
      final counts = changesetCarryCounts(tree, ops);
      expect(counts, (kept: 1, rewritten: 1));
      expect(changesetCarry(counts, null).carried, 1);
      expect(changesetCarry(counts, true).checked, isTrue);
    });
  });
}
